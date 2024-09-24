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

function M.pick_remote(path, callback)
  local repos = path:list_remotes()
  table.sort(repos, function(a, b)
    if a.remote_name == "origin" and b.remote_name ~= "origin" then
      -- Sort 'origin' remotes first.
      return true
    end
    return a:display() < b:display()
  end)
  if #repos == 0 then
    error("No Git repos detected from `git remote -v` output")
  elseif #repos == 1 then
    callback(repos[1])
  else
    vim.ui.select(repos, {
      prompt = "Git repo",
      format_item = require("open_browser_git.repo").display,
    }, callback)
  end
end

-- If the `path` is given, open that file in a browser.
--
-- If the `path` is absent, open the repo's homepage.
--
-- open_git(path: string|nil, options: {lines: {line1: int, line2: int}|nil}|nil)
function M.open_git(path, options)
  path = require("open_browser_git.path"):new(path)
  M.pick_remote(path, function(repo)
    -- TODO: Find the most recent _pushed_ commit.
    local commit = path:git({ "rev-parse", "HEAD" }).stdout[1]
    local url = repo:url_for_file(path:relative_to_root(), commit, options)
    require("open_browser_git.open_browser").open_url(url)
  end)
end

-- browser: string|{ cmd: string, args: list<string>|nil }
-- config: { browser: browser|nil,
--           create_commands: bool = true,
--           command_prefix: string = "OpenGit",
--           flavor_patterns: table<string, list<string>>|nil = nil,
--         }
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
