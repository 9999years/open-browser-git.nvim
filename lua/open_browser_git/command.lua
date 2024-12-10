local M = {}

--- @class open_browser_git.command.Options
---
--- @field cwd string|nil

-- Run a command, collecting stdout and stderr. Throw an error if the exit code
-- is not 0.
--
--- @param executable string
--- @param arguments string[]
--- @param options? open_browser_git.command.Options
--- @return vim.SystemCompleted
function M.command(executable, arguments, options)
  arguments = vim.list_extend({ executable }, arguments)
  options = options or {}
  local process = vim.system(arguments, {
    cwd = options.cwd,
    text = true,
  })

  local output = process:wait()
  output.stdout = vim.trim(output.stdout)
  output.stderr = vim.trim(output.stderr)

  if output.code ~= 0 then
    local message = executable
      .. " failed with exit code "
      .. output.code
      .. "\nError executing: "
      .. vim.fn.join(arguments, " ")
    if #output.stdout > 0 then
      message = message .. "\nStdout: " .. output.stdout
    end
    if #output.stderr > 0 then
      message = message .. "\nStderr: " .. output.stdout
    end
    -- TODO: Is `vim.notify(message, vim.log.levels.ERROR)` better?
    error(message)
  end
  return output
end

-- Execute a Git command.
--
-- See `command()`.
--
--- @param arguments string[]
--- @param options? open_browser_git.command.Options
--- @return vim.SystemCompleted
function M.git(arguments, options)
  return M.command("git", arguments, options)
end

return M
