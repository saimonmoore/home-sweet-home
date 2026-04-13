local wezterm = require "wezterm"

local act = wezterm.action
local config = wezterm.config_builder()
local home_dir = os.getenv("HOME") or ""
local project_picker_base_dir = home_dir ~= "" and (home_dir .. "/NewWork/Code") or nil

config.color_scheme = "Catppuccin Mocha"
config.colors = {
  background = "#000000",
}
config.font = wezterm.font_with_fallback({
  { family = "Maple Mono NF",           weight = "Medium" },
  { family = "FiraCode Nerd Font Mono", weight = "Medium" },
  { family = "FiraCode Nerd Font",      weight = "Medium" },
})
config.font_size = 13.7
config.freetype_load_target = "Normal"
config.freetype_render_target = "HorizontalLcd"
config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = false
config.window_close_confirmation = "NeverPrompt"
config.leader = { key = ".", mods = "ALT", timeout_milliseconds = 1000 }
config.window_padding = {
  left = 6,
  right = 6,
  top = 4,
  bottom = 4,
}

config.default_cursor_style = 'SteadyBar'

config.unix_domains = {
  {
    name = 'unix',
  },
}

config.default_gui_startup_args = { 'connect', 'unix' }

local function trim_whitespace(value)
  return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function command_or_shell(command, fallback_command, label)
  local missing_label = label or command
  local command_check = string.format(
    "if command -v %s >/dev/null 2>&1; then exec %s",
    command,
    command
  )

  if fallback_command then
    command_check = string.format(
      "%s; elif command -v %s >/dev/null 2>&1; then exec %s",
      command_check,
      fallback_command,
      fallback_command
    )
  end

  local command_line = string.format(
    "%s; else echo '%s not found on PATH'; exec zsh -l; fi",
    command_check,
    missing_label
  )

  return {
    "zsh",
    "-lic",
    command_line,
  }
end

local function split_into_vm(command_name)
  return act.SplitPane {
    direction = "Right",
    size = { Percent = 50 },
    command = {
      args = {
        "zsh",
        "-lic",
        string.format(
          "if command -v %s >/dev/null 2>&1; then exec %s; else echo '%s not found on PATH'; exec zsh -l; fi",
          command_name,
          command_name,
          command_name
        ),
      },
    },
  }
end

local function remote_session_picker(window, pane)
  window:perform_action(
    act.InputSelector {
      title = "Remote session",
      choices = {
        { id = ",dev", label = "dev" },
        { id = ",agent", label = "agent" },
      },
      fuzzy = false,
      action = wezterm.action_callback(function(prompt_window, prompt_pane, id, label)
        if not id and not label then
          return
        end

        local command_name = trim_whitespace(id or label or "")
        if command_name == "" then
          return
        end

        prompt_window:perform_action(split_into_vm(command_name), prompt_pane)
      end),
    },
    pane
  )
end

local function project_workspace_picker(window, pane)
  local query_command = "zoxide query -l"
  if project_picker_base_dir then
    query_command = string.format("%s --base-dir %q", query_command, project_picker_base_dir)
  end

  local success, stdout, stderr = wezterm.run_child_process {
    "zsh",
    "-lic",
    query_command,
  }

  if not success then
    wezterm.log_error("Project picker failed: " .. (stderr or ""))
    return
  end

  local choices = {}
  for line in (stdout or ""):gmatch("[^\r\n]+") do
    local project_dir = trim_whitespace(line)
    if project_dir ~= "" then
      table.insert(choices, {
        id = project_dir,
        label = project_dir,
      })
    end
  end

  if #choices == 0 then
    wezterm.log_info("Project picker: no entries from zoxide")
    return
  end

  window:perform_action(
    act.InputSelector {
      title = "Project",
      choices = choices,
      fuzzy = true,
      action = wezterm.action_callback(function(prompt_window, prompt_pane, id, label)
        if not id and not label then
          return
        end

        local project_dir = trim_whitespace(id or label or "")
        if project_dir == "" then
          return
        end

        local workspace_name = project_dir:match("([^/]+)$") or project_dir
        prompt_window:perform_action(
          act.SwitchToWorkspace {
            name = workspace_name,
            spawn = { cwd = project_dir },
          },
          prompt_pane
        )
      end),
    },
    pane
  )
end

local function prompt_new_workspace(window, pane)
  window:perform_action(
    act.PromptInputLine {
      description = "New workspace name",
      action = wezterm.action_callback(function(prompt_window, prompt_pane, line)
        if not line or line == "" then
          return
        end

        prompt_window:perform_action(
          act.SwitchToWorkspace { name = line },
          prompt_pane
        )
      end),
    },
    pane
  )
end

local function prompt_rename_workspace(window, pane)
  local current_workspace = wezterm.mux.get_active_workspace()
  if not current_workspace or current_workspace == "" then
    return
  end

  window:perform_action(
    act.PromptInputLine {
      description = "Rename workspace",
      action = wezterm.action_callback(function(prompt_window, prompt_pane, line)
        if not line or line == "" or line == current_workspace then
          return
        end

        wezterm.mux.rename_workspace(current_workspace, line)
        prompt_window:perform_action(
          act.SwitchToWorkspace { name = line },
          prompt_pane
        )
      end),
    },
    pane
  )
end

local function prompt_tab_title(window, pane)
  local tab = pane:tab()
  local current_title = tab and tab:get_title() or ""

  window:perform_action(
    act.PromptInputLine {
      description = "Tab title",
      initial_value = current_title,
      action = wezterm.action_callback(function(_, prompt_pane, line)
        if not line or not prompt_pane then
          return
        end

        local prompt_tab = prompt_pane:tab()
        if prompt_tab then
          prompt_tab:set_title(trim_whitespace(line))
        end
      end),
    },
    pane
  )
end

local function workspace_switcher(window, pane)
  local current_workspace = wezterm.mux.get_active_workspace()
  local workspaces = wezterm.mux.get_workspace_names()
  local choices = {}

  for _, workspace_name in ipairs(workspaces or {}) do
    local label = workspace_name
    if workspace_name == current_workspace then
      label = "* " .. workspace_name
    end

    table.insert(choices, {
      id = workspace_name,
      label = label,
    })
  end

  if #choices == 0 then
    return
  end

  window:perform_action(
    act.InputSelector {
      title = "Workspace",
      choices = choices,
      fuzzy = true,
      action = wezterm.action_callback(function(prompt_window, prompt_pane, id, label)
        if not id and not label then
          return
        end

        local target_workspace = trim_whitespace(id or label or "")
        if target_workspace == "" then
          return
        end

        prompt_window:perform_action(
          act.SwitchToWorkspace { name = target_workspace },
          prompt_pane
        )
      end),
    },
    pane
  )
end

local function pmd_context_picker(window, pane)
  local choices = {
    { id = "projects",      label = "projects" },
    { id = "teams",         label = "teams" },
    { id = "people",        label = "people" },
    { id = "servicegroups", label = "servicegroups" },
  }

  window:perform_action(
    act.InputSelector {
      title = "PMD",
      choices = choices,
      fuzzy = false,
      action = wezterm.action_callback(function(prompt_window, prompt_pane, id, label)
        if not id and not label then
          return
        end

        local selection = trim_whitespace(id or label or "")
        if selection == "" then
          return
        end

        local command = string.format(
          "if command -v pmd >/dev/null 2>&1; then exec pmd %q; else echo 'pmd not found on PATH'; exec zsh -l; fi",
          selection
        )

        prompt_window:perform_action(
          act.SplitPane {
            direction = "Right",
            size = { Percent = 40 },
            command = {
              args = { "zsh", "-lic", command },
            },
          },
          prompt_pane
        )
      end),
    },
    pane
  )
end

wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
  local title = tostring(tab.tab_index + 1)
  local pane = tab.active_pane

  -- Get the pane title which often contains git branch info
  local pane_title = pane.title

  -- Try to extract branch from pane title if it's in the format "user@host:path (branch)"
  -- or just use the current working directory name
  local cwd_uri = pane.current_working_dir
  if cwd_uri then
    local cwd = cwd_uri.file_path or tostring(cwd_uri)
    cwd = cwd:gsub("file://[^/]*/", "/")

    -- Get the directory name (which in worktree setup is the branch name)
    local dir_name = cwd:match("([^/]+)/?$")
    if dir_name and dir_name ~= "" then
      title = title .. ": " .. dir_name
    end
  end

  return {
    { Text = " " .. title .. " " },
  }
end)

wezterm.on("gui-startup", function(cmd)
  local cwd = cmd and cmd.cwd or nil
  local workspace_name = "organization"
  local window, pane = wezterm.mux.spawn_window {
    cwd = cwd,
    workspace = workspace_name,
    args = command_or_shell("hours"),
  }

  pane:split {
    direction = "Right",
    size = 0.5,
    cwd = cwd,
    args = command_or_shell("tasksh"),
  }
end)

config.keys = {
  { key = "t", mods = "LEADER",       action = act.SendKey { key = "t", mods = "CTRL" } },
  { key = "s", mods = "LEADER",       action = wezterm.action_callback(project_workspace_picker) },
  { key = "S", mods = "LEADER|SHIFT", action = act.ShowLauncher },
  { key = "p", mods = "LEADER",       action = act.ActivateCommandPalette },
  { key = "w", mods = "LEADER",       action = wezterm.action_callback(workspace_switcher) },
  { key = "w", mods = "LEADER|SHIFT", action = wezterm.action_callback(prompt_new_workspace) },
  { key = "d", mods = "LEADER",       action = split_into_vm(",dev") },
  { key = "r", mods = "LEADER",       action = wezterm.action_callback(remote_session_picker) },
  { key = "r", mods = "LEADER|SHIFT", action = act.ReloadConfiguration },
  { key = "R", mods = "LEADER|SHIFT", action = wezterm.action_callback(prompt_rename_workspace) },
  { key = ",", mods = "LEADER",       action = wezterm.action_callback(pmd_context_picker) },
  { key = "c", mods = "LEADER",       action = act.SpawnCommandInNewTab { args = { "zsh", "-lic", "nvim ~/.config/wezterm/wezterm.lua" } } },
  { key = "f", mods = "LEADER",       action = act.ToggleFullScreen },
  { key = "+", mods = "SUPER",        action = act.IncreaseFontSize },
  { key = "-", mods = "SUPER",        action = act.DecreaseFontSize },
  { key = "c", mods = "ALT",          action = act.SpawnTab "CurrentPaneDomain" },
  { key = "[", mods = "ALT",          action = act.ActivateTabRelative(-1) },
  { key = "]", mods = "ALT",          action = act.ActivateTabRelative(1) },
  { key = "1", mods = "ALT",          action = act.ActivateTab(0) },
  { key = "2", mods = "ALT",          action = act.ActivateTab(1) },
  { key = "3", mods = "ALT",          action = act.ActivateTab(2) },
  { key = "4", mods = "ALT",          action = act.ActivateTab(3) },
  { key = "5", mods = "ALT",          action = act.ActivateTab(4) },
  { key = "6", mods = "ALT",          action = act.ActivateTab(5) },
  { key = "7", mods = "ALT",          action = act.ActivateTab(6) },
  { key = "8", mods = "ALT",          action = act.ActivateTab(7) },
  { key = "9", mods = "ALT",          action = act.ActivateTab(8) },
  { key = "x", mods = "ALT",          action = act.CloseCurrentPane { confirm = false } },
  { key = "z", mods = "ALT",          action = act.TogglePaneZoomState },
  { key = "r", mods = "ALT",          action = wezterm.action_callback(prompt_tab_title) },
  { key = "h", mods = "ALT",          action = act.ActivatePaneDirection "Left" },
  { key = "j", mods = "ALT",          action = act.ActivatePaneDirection "Down" },
  { key = "k", mods = "ALT",          action = act.ActivatePaneDirection "Up" },
  { key = "l", mods = "ALT",          action = act.ActivatePaneDirection "Right" },
  { key = "H", mods = "ALT|SHIFT",    action = act.AdjustPaneSize { "Left", 5 } },
  { key = "J", mods = "ALT|SHIFT",    action = act.AdjustPaneSize { "Down", 5 } },
  { key = "K", mods = "ALT|SHIFT",    action = act.AdjustPaneSize { "Up", 5 } },
  { key = "L", mods = "ALT|SHIFT",    action = act.AdjustPaneSize { "Right", 5 } },
  { key = "|", mods = "LEADER",       action = act.SplitPane { direction = "Right", size = { Percent = 50 } } },
  {
    key = "n",
    mods = "LEADER",
    action = act.SplitPane {
      direction = "Right",
      size = { Percent = 50 },
      command = {
        args = { "zsh", "-lic", "nvim ~/Documents/Notes" }
      },
    },
  },

  {
    key = "N",
    mods = "LEADER|SHIFT",
    action = act.SplitPane {
      direction = "Right",
      size = { Percent = 50 },
      command = {
        args = { "zsh", "-lic", "yazi ~/Documents/Notes" }
      },
    },
  },

  {
    key = "t",
    mods = "LEADER",
    action = act.SplitPane {
      direction = "Right",
      size = { Percent = 40 },
      command = {
        args = {
          "zsh",
          "-lic",
          "if command -v tasksh >/dev/null 2>&1; then exec taskwarrior-tui; else echo 'taskwarrior-tui not found on PATH'; exec zsh -l; fi",
        },
      },
    },
  },

  {
    key = "t",
    mods = "LEADER|SHIFT",
    action = act.SplitPane {
      direction = "Right",
      size = { Percent = 40 },
      command = {
        args = {
          "zsh",
          "-lic",
          "if command -v tasksh >/dev/null 2>&1; then exec tasksh; else echo 'tasksh not found on PATH'; exec zsh -l; fi",
        },
      },
    },
  },
}

return config
