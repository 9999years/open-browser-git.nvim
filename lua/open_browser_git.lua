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
    if result.exit_code != 0 then
      vim.notify("command failed blah blah blah", vim.log.levels.ERROR)
    end
	return result
end

function git(args)
	return command("git", args, {
		cwd = vim.fn.expand("%:p:h"),
	})
end

print(vim.inspect(git({ "remote", "-v" })))
