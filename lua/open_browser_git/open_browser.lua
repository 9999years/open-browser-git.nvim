-- Reference:
-- https://github.com/tyru/open-browser.vim/blob/master/autoload/vital/__openbrowser__/OpenBrowser/Config.vim
--
-- If someone wants to port @tyru's _extensively_ featureful `open-browser.vim`
-- to Lua, be my guest, but writing VimScript is bad for my mental health.
-- Porting this subset is bad enough.
--
-- Check out what they're doing to hack around VimScript's (lack of) a module
-- system: https://github.com/vim-jp/vital.vim
local M = {}

--- @class open_browser_git.open_browser.Browser
--- @field cmd string
--- @field args? string[]

-- TODO: Augh, this doesn't run lazily!?
-- See `:h feature-list`
M.is_unix = vim.fn.has("unix")
M.is_windows = vim.fn.has("win32")
M.is_cygwin = vim.fn.has("win32unix")
M.is_macos = vim.fn.has("mac")
M.is_wsl = vim.fn.has("wsl")
M._detected_wsl = false

function M.detect_wsl()
  if M._detected_wsl then
    return
  end
  M._detected_wsl = true
  -- TODO: Does this work? I copied the logic from `open-browser.vim` and I do
  -- not want to get out a Windows box to test this. Mostly because that would
  -- mean getting out of bed :)
  if (not M.is_wsl) and M.is_unix and vim.fn.filereadable("/proc/version") then
    local lines = vim.fn.readfile("/proc/version", "b", 1)
    if lines[1] ~= nil and lines[1]:lower():find("microsoft") ~= nil then
      M.is_wsl = true
    end
  end
end

-- Default browser discovery. Use `setup` for configuration.
--- @return open_browser_git.open_browser.Browser?
function M.detect_browser()
  -- I use macOS so it comes first :)
  if M.is_macos then
    if vim.fn.executable("open") == 1 then
      return { cmd = "open" }
    end
  end

  if M.is_cygwin then
    if vim.fn.executable("cygstart") == 1 then
      return { cmd = "cygstart" }
    end
  end

  if M.is_cygwin or M.is_windows or M.is_wsl then
    -- I'd rather use PowerShell at this rate...
    for _, path in ipairs {
      "/mnt/c/WINDOWS/System32/rundll32.exe",
      "/mnt/c/Windows/System32/rundll32.exe",
      "rundll32.exe",
      "rundll32",
    } do
      if vim.fn.filereadable(path) or vim.fn.executable(path) == 1 then
        return { cmd = path, args = { "url.dll,FileProtocolHandler" } }
      end
    end
  end

  if M.is_unix then
    for _, path in ipairs {
      "xdg-open",
      "x-www-browser",
      "w3m",
    } do
      if vim.fn.executable(path) == 1 then
        return { cmd = path }
      end
    end
  end

  -- Hey, it can't hurt.
  for _, path in ipairs {
    "firefox",
    "chrome",
    "chromium",
    "googlechrome",
  } do
    if vim.fn.executable(path) == 1 then
      return { cmd = path }
    end
  end
end

--- @param config open_browser_git.Config
function M.setup(config)
  M.detect_wsl()
  if config.browser ~= nil then
    if type(config.browser) == "string" then
      ---@diagnostic disable-next-line: assign-type-mismatch
      M.browser = { cmd = config.browser }
    else
      M.browser = config.browser
    end
  else
    M.browser = M.detect_browser()
  end
  if M.browser == nil then
    error(
      "No browser found for your platform. Please set a browser explicitly."
    )
  end
end

-- Open a URL in the default browser.
--
--- @param url string
function M.open_url(url)
  if M.browser == nil then
    M.setup {}
  end

  local args = {}
  if M.browser.args ~= nil then
    vim.list_extend(args, M.browser.args)
  end
  table.insert(args, url)

  require("open_browser_git.command").command(M.browser.cmd, args)
end

return M
