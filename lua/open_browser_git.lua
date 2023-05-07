--[[

Interface:

- :OpenGitFile [PATH]
- :OpenGitIssue [[#]NUMBER] [USER/REPO]
- :OpenGitPR [[#]NUMBER|BRANCH] [USER/REPO]
- :OpenGitHomepage [USER/REPO]
- :OpenGitCommit COMMIT [USER/REPO]

Configuration:

- Always select current line
- Always use current branch
- Branch override (might be nice to scope this...?)
- URL format detection...?

]]

local M = {}

M.Repo = require("open_browser_git.repo")

-- Remove duplicate items from a list-like table. Does not modify `t`, may
-- shuffle items, discards keys.
function tbl_uniq(t, fn)
	local t2 = {}
	for _, value in ipairs(t) do
		t2[fn(value)] = value
	end
	return vim.tbl_values(t2)
end

function id(x)
	return x
end

function command(executable, arguments, options)
	local result = {
		exit_code = -1,
		stdout = {},
		stderr = {},
	}
	local arguments = vim.list_extend({ executable }, arguments)
	local job_id = vim.fn.jobstart(
		arguments,
		vim.tbl_extend("force", options, {
			on_exit = function(_channel, exit_code, _event)
				result.exit_code = exit_code
			end,
			on_stdout = function(_channel, stdout, _event)
				result.stdout = stdout
			end,
			on_stderr = function(_channel, stderr, _event)
				result.stderr = stderr
			end,
			stdout_buffered = true,
			stderr_buffered = true,
		})
	)
	local exit_codes = vim.fn.jobwait({ job_id })
	-- `stdout` and `stderr` are collected as a list of strings. The trailing
	-- newline then becomes a trailing empty string. This is not, generally,
	-- useful.
	if result.stdout[#result.stdout] == "" then
		result.stdout[#result.stdout] = nil
	end
	if result.stderr[#result.stderr] == "" then
		result.stderr[#result.stderr] = nil
	end
	if result.exit_code ~= 0 then
		local message = executable .. " failed with exit code " .. result.exit_code
		if #result.stdout > 0 then
			message = message .. "\nStdout: " .. vim.fn.join(result.stdout, "\n")
		end
		if #result.stderr > 0 then
			message = message .. "\nStderr: " .. vim.fn.join(result.stderr, "\n")
		end
		-- TODO: Is `vim.notify(message, vim.log.levels.ERROR)` better?
		error(message)
	end
	return result
end

function git(args)
	return command("git", args, {
		cwd = vim.fn.expand("%:p:h"),
	})
end

function parse_git_remote_url(url)
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
			return M.Repo:new({
				host = host:gsub("^([^@]+)@", ""),
				user = user,
				repo = repo:gsub("%.git$", ""),
				remote_name = remote_name,
			})
		end
	end
end

function M.parse_git_remote(lines, callback)
	local repos = {}
	for _, line in ipairs(lines) do
		-- Can I simplify this to skip the nil check?
		local repo = parse_git_remote_url(line)
		if repo ~= nil then
			table.insert(repos, repo)
		end
	end
	repos = tbl_uniq(repos, M.Repo.display)
	table.sort(repos, function(a, b)
		return a:display() < b:display()
	end)
	if #repos == 0 then
		error("No Git repos detected from `git remote -v` output")
	elseif #repos == 1 then
		callback(repos[1])
	else
		vim.ui.select(repos, {
			prompt = "Git repo",
			format_item = M.Repo.display,
		}, callback)
	end
end

function M.get_git_repo(callback)
	M.parse_git_remote(git({ "remote", "-v" }).stdout, callback)
end

return M
