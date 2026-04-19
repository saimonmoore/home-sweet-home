-- home-sweet-home keymaps overlay.
--
-- This file is chezmoi-managed (source:
-- chezmoi/dot_config/nvim/lua/config/keymaps.lua). Every `chezmoi apply`
-- rewrites it, so DO NOT edit ~/.config/nvim/lua/config/keymaps.lua
-- directly — edit the source in the home-sweet-home repo instead.
--
-- LazyVim wipes this file clean otherwise; we use it to restore a few
-- things LazyVim opts out of.

-- Restore arrow keys in normal/insert/visual mode. LazyVim maps them to a
-- "Use h/j/k/l" nag by default; this undoes that so the arrows do the
-- ordinary cursor-movement thing. `pcall` keeps us safe if a future
-- LazyVim version stops pre-binding them.
for _, mode in ipairs({ "n", "i", "v" }) do
	for _, key in ipairs({ "<Up>", "<Down>", "<Left>", "<Right>" }) do
		pcall(vim.keymap.del, mode, key)
	end
end
