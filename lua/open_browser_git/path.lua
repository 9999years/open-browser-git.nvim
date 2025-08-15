--- @class open_browser_git.Path
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
--- @param path? string Defaults to the current file's directory.
--- @return open_browser_git.Path
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

--- Parse a Git remote URL. The returned `open_browser_git.repo`'s
--- `remote_name` field will always be `nil`.
---
--- @param url string A Git remote URL like `git@github.com:9999years/open-browser-git.nvim.git`.
--- @return open_browser_git.repo?
local function parse_git_remote_url(url)
  -- User, repo.
  -- NB: We trim a trailing `.git` from the repo.
  local user_repo_pattern = "([^/]+)/([^/]+)$"
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
      return require("open_browser_git.repo"):new {
        host = host:gsub("^([^@]+)@", ""),
        user = user,
        repo = repo:gsub("%.git$", ""),
        flavor_patterns = require("open_browser_git")._config.flavor_patterns,
      }
    end
  end
end

--- Transform a list of Git remote names into parsed `open_browser_git.repo`s.
---
--- @param remotes string[]
--- @return open_browser_git.repo[]
function Path:remote_names_to_repos(remotes)
  local repos = {}
  for _, remote in ipairs(remotes) do
    local repo =
      parse_git_remote_url(self:git({ "remote", "get-url", remote }).stdout)
    if repo ~= nil then
      repo.remote_name = remote
      table.insert(repos, repo)
    end
  end
  repos = tbl_uniq(repos, require("open_browser_git.repo").display)
  return repos
end

--- @class open_browser_git.CommitRemotes
--- @field commit string
--- @field remotes string[]

--- Find the nearest commit to `HEAD` (topologically) that is present on at
--- least one remote.
---
--- TODO: Check the blame to find the most accurate commit?
--- TODO: Traverse the reflog to find pushed commits prior to rebases.
--- TODO: Offer an option for the user to pick from several commits for e.g.
--- megamerge workflows.
---
--- @return open_browser_git.CommitRemotes?
function Path:find_remote_commit()
  -- First, traverse commit ancestors in topological order starting with
  -- `HEAD`.
  local commits = vim.gsplit(
    self:git({
      "rev-list",
      -- TODO: Paginate if we can't find a pushed commit. But certainly you're at
      -- least pushing every 25 commits or so...?
      "--max-count",
      "25",
      "--topo-order",
      "HEAD",
    }).stdout,
    "\n",
    {
      plain = true,
      trimempty = true,
    }
  )

  for commit in commits do
    local remotes = self:remotes_for_commit(commit)
    if #remotes > 0 then
      return {
        commit = commit,
        remotes = remotes,
      }
    end
  end

  return nil
end

--- Find the Git remotes (by name) that a given commit is present on.
---
--- A ref containing the commit must have been fetched from the remote already
--- for it to show up; this function does not hit the network, it just checks
--- refs under `refs/remotes/`.
---
--- @param commit string
--- @return string[]
function Path:remotes_for_commit(commit)
  local refs = vim.gsplit(
    self:git({
      "for-each-ref",
      "--format",
      "%(refname:lstrip=2)",
      "--contains",
      commit,
      "refs/remotes/**",
    }).stdout,
    "\n",
    {
      plain = true,
      trimempty = true,
    }
  )

  local remotes = {}

  for ref in refs do
    local components = vim.split(ref, "/", { plain = true })
    if #components > 0 then
      local remote = components[1]
      remotes[remote] = true
    end
  end

  return vim.tbl_keys(remotes)
end

return Path
