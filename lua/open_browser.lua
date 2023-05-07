-- Reference:
-- https://github.com/tyru/open-browser.vim/blob/master/autoload/vital/__openbrowser__/OpenBrowser/Config.vim
local M = {}

-- See `:h feature-list`
M.is_unix = vim.fn.has("unix")
M.is_mswin = vim.fn.has("win32")
M.is_cygwin = vim.fn.has("win32unix")
M.is_mac = vim.fn.has("mac")
M.is_wsl = vim.fn.has("wsl")

if M.is_cygwin then
	if vim.fn.executable("cygstart") == 1 then
		M.cmd = "cygstart"
	end
end

return M
