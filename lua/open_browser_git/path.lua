--- @class open_browser_git.path
---
--- @field path string
--- @field repo_root string
local Path = {}

local function git_repo_root(dir)
  return require("open_browser_git.command").git({
    "rev-parse",
    "--show-toplevel",
  }, { cwd = dir }).stdout
end

-- A path in a Git repository.
--
--- @param path? string
--- @return open_browser_git.path
function Path:new(path)
  if (path == nil) or (path == "") then
    path = vim.fn.expand("%:p")
  end
  local path_dir = vim.fs.dirname(path)
  local repo_root = git_repo_root(path_dir)
  local ret = { path = path, repo_root = repo_root }
  setmetatable(ret, self)
  self.__index = self
  return ret
end

-- Gets this path relative to the repository root.
--
-- If you have newlines in your filenames: Don't.
--
--- @return string
function Path:relative_to_root()
  return self:git({
    "ls-files",
    "--cached", -- Show tracked files.
    "--other", -- Show untracked files.
    "--full-name", -- Paths relative to repository root.
    self.path,
  }).stdout
end

-- Run a Git command.
--
--- @param args string[]
--- @param options? open_browser_git.command.Options
function Path:git(args, options)
  return require("open_browser_git.command").git(
    args,
    vim.tbl_extend("keep", options or {}, { cwd = self.repo_root })
  )
end

-- Remove duplicate items from a list-like table. Does not modify `t`, may
-- shuffle items, discards keys.
--
--- @generic T
--- @generic U
--- @param table T[]
--- @param fn fun(T): U
--- @return T[]
local function tbl_uniq(table, fn)
  local result = {}
  for _, value in ipairs(table) do
    result[fn(value)] = value
  end
  return vim.tbl_values(result)
end

--- @param url string
--- @return open_browser_git.repo?
local function parse_git_remote_url(url)
  -- User, repo, whitespace.
  -- NB: We trim a trailing `.git` from the repo.
  local user_repo_pattern = "([^/]+)/([^/]+)%s"
  -- NB: We trim a leading `git@` or other username from the hostname.
  local patterns = {
    -- NB: This first pattern also matches ssh://git@... URLs.
    "git@([^:/]+)[:/]" .. user_repo_pattern, -- ssh
    "%s([^:/]+)[:/]" .. user_repo_pattern, -- ssh
    "ssh://([^/]+)/" .. user_repo_pattern, -- ssh
    "git://([^/]+)/" .. user_repo_pattern, -- git
    "https?://([^/]+)/" .. user_repo_pattern, -- http(s)
  }
  for _, pattern in ipairs(patterns) do
    local host, user, repo = url:match(pattern)
    if host ~= nil then
      local remote_name = url:match("^([^\t]+)\t")
      return require("open_browser_git.repo"):new {
        host = host:gsub("^([^@]+)@", ""),
        user = user,
        repo = repo:gsub("%.git$", ""),
        remote_name = remote_name,
        flavor_patterns = require("open_browser_git")._config.flavor_patterns,
      }
    end
  end
end

--- @return open_browser_git.repo[]
function Path:list_remotes()
  local output = self:git { "remote", "-v" }
  local repos = {}
  for line in vim.gsplit(output.stdout, "\n", { plain = true }) do
    -- Can I simplify this to skip the nil check?
    local repo = parse_git_remote_url(line)
    if repo ~= nil then
      table.insert(repos, repo)
    end
  end
  repos = tbl_uniq(repos, require("open_browser_git.repo").display)
  return repos
end

return Path
