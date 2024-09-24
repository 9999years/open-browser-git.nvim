local Path = {}

local function git_repo_root(dir)
  return require("open_browser_git.command").git({
    "rev-parse",
    "--show-toplevel",
  }, { cwd = dir }).stdout[1]
end

-- A path in a Git repository.
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
function Path:relative_to_root()
  return self:git({
    "ls-files",
    "--cached", -- Show tracked files.
    "--other", -- Show untracked files.
    "--full-name", -- Paths relative to repository root.
    self.path,
  }).stdout[1]
end

function Path:git(args, options)
  return require("open_browser_git.command").git(
    args,
    vim.tbl_extend("keep", options or {}, { cwd = self.repo_root })
  )
end

-- Remove duplicate items from a list-like table. Does not modify `t`, may
-- shuffle items, discards keys.
local function tbl_uniq(t, fn)
  local t2 = {}
  for _, value in ipairs(t) do
    t2[fn(value)] = value
  end
  return vim.tbl_values(t2)
end

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

function Path:list_remotes()
  local lines = self:git({ "remote", "-v" }).stdout
  local repos = {}
  for _, line in ipairs(lines) do
    -- Can I simplify this to skip the nil check?
    local repo = parse_git_remote_url(line)
    if repo ~= nil then
      table.insert(repos, repo)
    end
  end
  repos = tbl_uniq(repos, require("open_browser_git.repo").display)
end

return Path
