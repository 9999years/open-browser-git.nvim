local M = {}

function M.command(executable, arguments, options)
  local result = {
    exit_code = -1,
    stdout = {},
    stderr = {},
  }
  local arguments = vim.list_extend({ executable }, arguments)
  local options = options or {}
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
  local exit_codes = vim.fn.jobwait { job_id }
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
    local message = executable
      .. " failed with exit code "
      .. result.exit_code
      .. "\nError executing: "
      .. executable
      .. " "
      .. vim.fn.join(arguments, " ")
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

-- NB: Remember to set `options.cwd`!
function M.git(args, options)
  return M.command("git", args, options)
end

return M
