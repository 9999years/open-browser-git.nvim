--[[

Interface:

- :OpenGit [PATH]
- :OpenGitIssue [[#]NUMBER]
- :OpenGitPR [[#]NUMBER|BRANCH]
- :OpenGitHomepage
- :OpenGitCommit COMMIT

Configuration:

- Always select current line
- Always use current branch
- Branch override (might be nice to scope this...?)
- URL format detection...?

TODO: optional user/repo argument for commands

]]
local M = {
  _config = {
    create_commands = true,
    command_prefix = "OpenGit",
  },
}

--- @param commit string
--- @param repos open_browser_git.repo[]
--- @param callback fun(commit: string, item: open_browser_git.repo)
function M.pick_remote(commit, repos, callback)
  if #repos == 0 then
    error("No Git repos detected from `git remote -v` output")
  elseif #repos == 1 then
    callback(commit, repos[1])
  else
    table.sort(repos, function(a, b)
      if a.remote_name == "origin" and b.remote_name ~= "origin" then
        -- Sort 'origin' remotes first.
        return true
      end
      return a:display() < b:display()
    end)
    vim.ui.select(repos, {
      prompt = "Git repo",
      format_item = require("open_browser_git.repo").display,
    }, function(repo)
      callback(commit, repo)
    end)
  end
end

-- If the `path` is given, open that file in a browser.
--
-- If the `path` is absent, open the repo's homepage.
--
-- open_git(path: string|nil, options: {lines: {line1: int, line2: int}|nil}|nil)
--- @param path? string
function M.open_git(path, options)
  local path_ = require("open_browser_git.path"):new(path)
  local commit_remotes = path_:find_remote_commit()
  if commit_remotes == nil then
    return
  end
  local repos = path_:remote_names_to_repos(commit_remotes.remotes)
  M.pick_remote(commit_remotes.commit, repos, function(commit, repo)
    local url = repo:url_for_file(path_:relative_to_root(), commit, options)
    require("open_browser_git.open_browser").open_url(url)
  end)
end

--- @class open_browser_git.Config
--- @field browser? open_browser_git.open_browser.Browser
--- @field create_commands? boolean = true
--- @field command_prefix? string = "OpenGit"
--- @field flavor_patterns? { [string]: string[] }

-- Set up open_browser_git.nvim.
--
--- @param config open_browser_git.Config
function M.setup(config)
  M._config = vim.tbl_extend("force", M._config, config)
  if M._config.browser ~= nil then
    require("open_browser_git.open_browser").setup(config)
  end
  if (M._config.create_commands == nil) or M._config.create_commands then
    local prefix = M._config.command_prefix or "OpenGit"
    vim.api.nvim_create_user_command(prefix, function(args)
      local opts = {}
      if args.range > 0 then
        opts.lines = { line1 = args.line1, line2 = args.line2 }
      end
      M.open_git(args.args, opts)
    end, {
      complete = "file",
      desc = "",
      nargs = "?", -- 0 or 1.
      range = true, -- Default current line.
    })
  end
end

return M
