local wezterm = require("wezterm")

local act = wezterm.action
local config = wezterm.config_builder()

local function trim_whitespace(value)
	return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

config.color_scheme = "Catppuccin Mocha"
config.colors = {
	background = "#000000",
}
config.font = wezterm.font_with_fallback({
	{ family = "Maple Mono NF", weight = "Medium" },
	{ family = "FiraCode Nerd Font Mono", weight = "Medium" },
	{ family = "FiraCode Nerd Font", weight = "Medium" },
})
config.font_size = 13.7
config.freetype_load_target = "Normal"
config.freetype_render_target = "HorizontalLcd"
config.disable_default_key_bindings = true
config.hide_tab_bar_if_only_one_tab = true
config.show_new_tab_button_in_tab_bar = false
config.tab_bar_at_bottom = true
config.use_fancy_tab_bar = false
config.window_close_confirmation = "NeverPrompt"
config.window_padding = {
	left = 6,
	right = 6,
	top = 4,
	bottom = 4,
}

config.default_cursor_style = "SteadyBar"

-- Send Option+<key> as Alt+<key> to the terminal. Zellij (running inside
-- WezTerm via `,dev`) is our pane/tab/split manager, and its chords are
-- plain `Alt+<letter>`. Without this, macOS Option composes special
-- characters (ƒ, ∂, …) instead of sending Alt modifiers.
config.send_composed_key_when_left_alt_is_pressed = false
config.send_composed_key_when_right_alt_is_pressed = false

local function activate_tab(index)
	return wezterm.action_callback(function(window, pane)
		window:perform_action(act.ActivateTab(index), pane)
	end)
end

local function prompt_tab_title(window, pane)
	local tab = pane and pane:tab()
	local current_title = tab and tab:get_title() or ""

	window:perform_action(
		act.PromptInputLine({
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
		}),
		pane
	)
end

wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
	local title = tab.tab_title
	if not title or title == "" then
		title = tostring(tab.tab_index + 1)
	end

	return {
		{ Text = " " .. title .. " " },
	}
end)

wezterm.on("gui-startup", function(cmd)
	local cwd = cmd and cmd.cwd or nil
	local tab, _, window = wezterm.mux.spawn_window({
		cwd = cwd,
	})

	tab:set_title("local")

	local dev_tab = window:spawn_tab({
		cwd = cwd,
	})
	dev_tab:set_title("dev")

	tab:activate()
end)

config.keys = {
	{ key = "mapped:c", mods = "CMD", action = act.CopyTo("Clipboard") },
	{ key = "mapped:v", mods = "CMD", action = act.PasteFrom("Clipboard") },
	{ key = "L", mods = "SUPER|SHIFT", action = activate_tab(0) },
	{ key = "D", mods = "SUPER|SHIFT", action = activate_tab(1) },
	{ key = "N", mods = "SUPER|SHIFT", action = act.ActivateTabRelative(1) },
	{ key = "P", mods = "SUPER|SHIFT", action = act.ActivateTabRelative(-1) },
	{ key = "C", mods = "SUPER|SHIFT", action = act.SpawnTab("CurrentPaneDomain") },
	{ key = "R", mods = "SUPER|SHIFT", action = wezterm.action_callback(prompt_tab_title) },
	{ key = "+", mods = "SUPER", action = act.IncreaseFontSize },
	{ key = "-", mods = "SUPER", action = act.DecreaseFontSize },
}

return config
