local M = {
  _config = {},
}

--- @class open_browser_git.PickRemoteOptions
--- @field commit string
--- @field repos open_browser_git.Repo[]

--- @param options open_browser_git.PickRemoteOptions
--- @param callback fun(commit: string, repo: open_browser_git.Repo)
function M.pick_remote(options, callback)
  if #options.repos == 0 then
    error("No Git repos detected from `git remote -v` output")
  elseif #options.repos == 1 then
    callback(options.commit, options.repos[1])
  else
    table.sort(options.repos, function(a, b)
      if a.remote_name == "origin" and b.remote_name ~= "origin" then
        -- Sort 'origin' remotes first.
        return true
      end
      return a:display() < b:display()
    end)
    vim.ui.select(options.repos, {
      prompt = "Git repo",
      format_item = require("open_browser_git.repo").display,
    }, function(repo)
      callback(options.commit, repo)
    end)
  end
end

--- @class open_browser_git.Info
--- @field url string
--- @field path open_browser_git.Path
--- @field relative_to_root string
--- @field repo open_browser_git.Repo
--- @field commit string

--- Get commit information and a URL.
---
--- By default, the user is consulted interactively to resolve the correct
--- remote name (if there is more than one to choose from).
---
--- @param options? open_browser_git.Options
--- @param callback fun(info: open_browser_git.Info)
function M.get_info(options, callback)
  options = vim.tbl_extend("force", M.default_options(), options)

  local path = require("open_browser_git.path"):new(options.path)
  local commit_remotes = options.find_remote_commit(path)
  if commit_remotes == nil then
    return
  end
  local repos = path:remote_names_to_repos(commit_remotes.remotes)
  options.pick_remote({
    commit = commit_remotes.commit,
    repos = repos,
  }, function(commit, repo)
    local relative_to_root = path:relative_to_root()
    local url = repo:url_for_file(relative_to_root, commit, options)
    callback {
      url = url,
      path = path,
      relative_to_root = relative_to_root,
      repo = repo,
      commit = commit,
    }
  end)
end

--- @class open_browser_git.Options: open_browser_git.repo.UrlOptions
--- @field path? string
--- @field find_remote_commit? fun(path: open_browser_git.Path): open_browser_git.CommitRemotes?
--- @field pick_remote? fun(options: open_browser_git.PickRemoteOptions, callback: fun(commit: string, repo: open_browser_git.Repo))

--- @return open_browser_git.Options
function M.default_options()
  return {
    find_remote_commit = require("open_browser_git.path").find_remote_commit,
    pick_remote = M.pick_remote,
  }
end

--- Open a Git permalink in your browser.
---
--- @param options? open_browser_git.Options
function M.open_git(options)
  M.get_info(options, function(info)
    require("open_browser_git.open_browser").open_url(info.url)
  end)
end

--- Copy a Git permalink to the clipboard.
---
--- @param options? open_browser_git.Options
function M.copy_git(options)
  M.get_info(options, function(info)
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
          local opts = {
            path = args.args,
          }
          if args.range > 0 then
            opts.lines = { line1 = args.line1, line2 = args.line2 }
          end
          M.open_git(opts)
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
          local opts = {
            path = args.args,
          }
          if args.range > 0 then
            opts.lines = { line1 = args.line1, line2 = args.line2 }
          end
          M.copy_git(opts)
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
