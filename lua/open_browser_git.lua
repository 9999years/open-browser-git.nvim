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
  _config = {},
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

--- @class open_browser_git.Info
--- @field url string
--- @field path open_browser_git.Path
--- @field relative_to_root string
--- @field repo open_browser_git.repo
--- @field commit string

--- Get commit information and a URL for the given path and options and invoke
--- a callback.
---
--- The user may be consulted interactively to resolve the correct remote name.
---
--- @param path? string
--- @param options? open_browser_git.repo.UrlOptions
--- @param callback fun(info: open_browser_git.Info)
function M.get_info(path, options, callback)
  local path_ = require("open_browser_git.path"):new(path)
  local commit_remotes = path_:find_remote_commit()
  if commit_remotes == nil then
    return
  end
  local repos = path_:remote_names_to_repos(commit_remotes.remotes)
  M.pick_remote(commit_remotes.commit, repos, function(commit, repo)
    local relative_to_root = path_:relative_to_root()
    local url = repo:url_for_file(relative_to_root, commit, options)
    callback {
      url = url,
      path = path_,
      relative_to_root = relative_to_root,
      repo = repo,
      commit = commit,
    }
  end)
end

--- Open a Git permalink for the given path and options.
---
--- @param path? string
--- @param options? open_browser_git.repo.UrlOptions
function M.open_git(path, options)
  M.get_info(path, options, function(info)
    require("open_browser_git.open_browser").open_url(info.url)
  end)
end

--- Copy a Git permalink for the given path and options to the clipboard.
---
--- @param path? string
--- @param options? open_browser_git.repo.UrlOptions
function M.copy_git(path, options)
  M.get_info(path, options, function(info)
    vim.fn.setreg("+", info.url)
  end)
end

--- @class open_browser_git.CommandsConfig
--- @field open string?
--- @field copy string?

--- @class open_browser_git.Config
--- @field browser? open_browser_git.open_browser.Browser
--- @field commands? open_browser_git.CommandsConfig|boolean
--- @field flavor_patterns? { [string]: string[] }

-- Set up open_browser_git.nvim.
--
--- @param config open_browser_git.Config
function M.setup(config)
  M._config = vim.tbl_extend("force", M._config, config)
  if M._config.browser ~= nil then
    require("open_browser_git.open_browser").setup(config)
  end

  if M._config.command_prefix ~= nil then
    vim.notify(
      '`command_prefix` is ignored as of 2025-08-14, use `commands = { open = "OpenGit" }` instead',
      vim.log.levels.WARN
    )
  end

  if M._config.create_commands ~= nil then
    vim.notify(
      "`create_commands` is ignored as of 2025-08-14, use `commands = true` instead",
      vim.log.levels.WARN
    )
  end

  if (M._config.commands == nil) or M._config.commands ~= false then
    local commands = M._config.commands
    if type(commands) == "boolean" then
      commands = {}
    elseif commands == nil then
      commands = {}
    end

    if commands.open ~= false then
      vim.api.nvim_create_user_command(
        commands.open or "OpenGit",
        function(args)
          local opts = {}
          if args.range > 0 then
            opts.lines = { line1 = args.line1, line2 = args.line2 }
          end
          M.open_git(args.args, opts)
        end,
        {
          complete = "file",
          desc = "Open a permalink to the current file/line in your browser",
          nargs = "?", -- 0 or 1.
          range = true, -- Default current line.
        }
      )
    end

    if commands.copy ~= false then
      vim.api.nvim_create_user_command(
        commands.copy or "CopyGit",
        function(args)
          local opts = {}
          if args.range > 0 then
            opts.lines = { line1 = args.line1, line2 = args.line2 }
          end
          M.copy_git(args.args, opts)
        end,
        {
          complete = "file",
          desc = "Copy a permalink to the current file/line to your clipboard",
          nargs = "?", -- 0 or 1.
          range = true, -- Default current line.
        }
      )
    end
  end
end

return M
