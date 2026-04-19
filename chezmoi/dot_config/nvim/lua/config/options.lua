-- home-sweet-home nvim options overlay.
--
-- This file is chezmoi-managed (source:
-- chezmoi/dot_config/nvim/lua/config/options.lua). Every `chezmoi apply`
-- rewrites it, so DO NOT edit ~/.config/nvim/lua/config/options.lua
-- directly — edit the source in the home-sweet-home repo instead.

-- Use OSC 52 escape sequences for the + and * clipboard registers.
-- Inside the lima dev VM there's no xclip / wl-copy / pbcopy, so the
-- default clipboard provider detection gives up and `+` silently goes
-- nowhere. OSC 52 lets nvim speak to the enclosing terminal (WezTerm
-- on the host, via zellij) which writes the content to the macOS
-- system clipboard. Works identically on the macOS host too, so a
-- single config is right for both machines.
local ok, osc52 = pcall(require, "vim.ui.clipboard.osc52")
if ok then
	vim.g.clipboard = {
		name = "OSC 52",
		copy = {
			["+"] = osc52.copy("+"),
			["*"] = osc52.copy("*"),
		},
		paste = {
			["+"] = osc52.paste("+"),
			["*"] = osc52.paste("*"),
		},
	}
end
