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
    "--cached",    -- Show tracked files.
    "--other",     -- Show untracked files.
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

return Path
