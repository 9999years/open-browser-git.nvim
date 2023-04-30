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

]]

local M = {
	debug = false,
}

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
		local error = executable .. " failed with exit code " .. result.exit_code
		if #result.stdout > 0 then
			error = error .. "\nStdout: " .. vim.fn.join(result.stdout, "\n")
		end
		if #result.stderr > 0 then
			error = error .. "\nStderr: " .. vim.fn.join(result.stderr, "\n")
		end
		vim.notify(error, vim.log.levels.ERROR)
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
	local patterns = {
		-- NB: This first pattern also matches ssh://git@... URLs.
		"git@([^:/]+)[:/]" .. user_repo_pattern, -- ssh
		"%s([^:/]+)[:/]" .. user_repo_pattern, -- ssh
		"ssh://([^/]+)/" .. user_repo_pattern, -- ssh
		"git://([^/]+)/" .. user_repo_pattern, -- git
		"https?://([^/]+)/" .. user_repo_pattern, -- http(s)
	}
	local matches = {}
	for _, pattern in ipairs(patterns) do
		local match = string.match(url, pattern)
		if match ~= nil then
			table.insert(matches, {
				host = match[1],
				user = match[2],
				repo = string.gsub(match[3], "%.git$", ""),
			})
		end
	end
	return matches
end

print(vim.inspect(git({ "remote", "-v" })))
