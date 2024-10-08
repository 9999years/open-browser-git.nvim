-- A Git repository.
--
-- For now, there's only one implementation, but if I find hosts that don't
-- match GitHub-like URL formats, I can add more and selectively construct them
-- in `parse_git_remote_url`. I've given this a little thought; here are some
-- of my ideas for extension points:
--
-- * Users provide an explicit mapping from hostnames to `Repo` classes.
--   This lets us keep our current regular expressions, but limits the sort of
--   implementations that can exist by requiring a pretty specific
--   hostname/username/reponame URL format. We could also potentially support
--   some common cases, like adding a fixed prefix to the path after the
--   hostname.
--
-- * The above, but users provide a set of parsing functions which are invoked
--   in order to both determine a URL match _and_ parse it out. Perhaps we
--   could keep parts of the regexes, like stripping out protocol names.
--
-- * Adding special cases to our regular expressions _and_ letting users
--   provide a set of parsing functions. As an additional option, letting the
--   user's parsing functions replace ours entirely instead of supplimenting
--   them.
--
-- This is all speculation; I don't actually need anything past GitHub and
-- GitLab support right now. Time and user feedback will tell :)
--
--- @class open_browser_git.repo: open_browser_git.repo.Options
---
--- @field flavor string
local Repo = {}

--- @class open_browser_git.repo.Options
---
--- @field host string
--- @field user string
--- @field repo string
--- @field remote_name? string
--- @field flavor_patterns? { [string]: string[] }

-- Construct a new repository from a hostname (like "github.com"), a username
-- (like "9999years"), and a repository name (like "open-browser-git.nvim").
--
--
-- `flavor_patterns` is a table mapping flavors to lists of patterns.
--
--- @param options open_browser_git.repo.Options
--- @return open_browser_git.repo
function Repo:new(options)
  --- @class open_browser_git.repo
  local result = options
  if result.host:find("gitlab") then
    result.flavor = "gitlab"
  elseif result.host:find("github") then
    result.flavor = "github"
  elseif result.host:find("forgejo") then
    result.flavor = "forgejo"
  elseif result.flavor_patterns ~= nil then
    for flavor, patterns in pairs(result.flavor_patterns) do
      for _, pattern in ipairs(patterns) do
        if result.host:find(pattern) then
          result.flavor = flavor
          break
        end
      end

      -- No labeled break in Lua 5.1.
      if result.flavor ~= nil then
        break
      end
    end
    result.flavor_patterns = nil
  end

  setmetatable(result, self)
  self.__index = self
  return result
end

--  Display the repo to the user.
--
--- @return string
function Repo:display()
  -- Example: github.com/NixOS/nixpkgs
  local displayed = self.host .. "/" .. self.user .. "/" .. self.repo
  if self.remote_name == nil then
    return displayed
  else
    return displayed .. " (" .. self.remote_name .. ")"
  end
end

-- Get the URL for this repo; a homepage or similar.
--
--- @return string
function Repo:url()
  -- TODO: Support non-HTTPS repository URLs?
  -- NB: This _could_ forward out to `self:display` but philisophically I
  -- want these to be separate.
  --
  -- Example: https://github.com/NixOS/nixpkgs
  return "https://" .. self.host .. "/" .. self.user .. "/" .. self.repo
end

-- Get the URL for a commit in this repo.
--
--- @param commit_hash string
--- @return string
function Repo:url_for_commit(commit_hash)
  if self.flavor == "forgejo" then
    -- Example: https://codeberg.org/forgejo/forgejo/src/commit/65f9319c8fabe3b6ffabd5c341da1b25fb39e0be
    return self:url() .. "/src/commit/" .. commit_hash
  else
    -- Example: https://github.com/NixOS/nixpkgs/tree/bda93c2221bc4185056723795c62e1b4cc661c4b
    return self:url() .. "/tree/" .. commit_hash
  end
end

-- Get the URL for a branch in this repo.
--
--- @param branch string
--- @return string
function Repo:url_for_branch(branch)
  if self.flavor == "forgejo" then
    -- Example: https://codeberg.org/forgejo/forgejo/src/branch/forgejo
    return self:url() .. "/src/branch/" .. branch
  else
    -- Example: https://github.com/NixOS/nixpkgs/tree/master
    return self:url() .. "/tree/" .. branch
  end
end

-- Get the URL for an issue in this repo, by number.
--- @param issue_number integer
--- @return string
function Repo:url_for_issue(issue_number)
  if self.flavor == "gitlab" then
    -- Example: https://gitlab.haskell.org/ghc/ghc/-/issues/23351
    return self:url() .. "/-/issues/" .. issue_number
  else
    -- GitHub or other flavors.
    -- Example: https://github.com/NixOS/nixpkgs/issues/226215
    return self:url() .. "/issues/" .. issue_number
  end
end

-- Get the URL for a pull request / merge request in this repo, by number.
--
-- TODO: Maybe add support for pull requests by branch?
--
--- @param pr_number integer
--- @return string
function Repo:url_for_pr(pr_number)
  if self.flavor == "gitlab" then
    -- Example: https://gitlab.haskell.org/ghc/ghc/-/merge_requests/10393
    return self:url() .. "/-/merge_requests/" .. pr_number
  elseif self.flavor == "forgejo" then
    -- Example: https://codeberg.org/forgejo/forgejo/pulls/2669
    return self:url() .. "/pulls/" .. pr_number
  else
    -- Example: https://github.com/NixOS/nixpkgs/pull/230398
    return self:url() .. "/pull/" .. pr_number
  end
end

--- @class open_browser_git.repo.Lines
--- @field line1 integer
--- @field line2 integer

--- @class open_browser_git.repo.UrlOptions
--- @field lines? open_browser_git.repo.Lines A range of lines to view.

-- Get the URL for a given path in this repo.
-- Paths are given relative to the repository root.
--
--- @param file_path string
--- @param commit string
--- @param options? { lines?: open_browser_git.repo.Lines }
--- @return string
function Repo:url_for_file(file_path, commit, options)
  local url = self:url()

  if self.flavor == "gitlab" then
    -- Example: https://gitlab.haskell.org/ghc/ghc/-/blob/master/.gitattributes
    url = url .. "/-/blob/" .. commit
  elseif self.flavor == "forgejo" then
    -- Example: https://codeberg.org/forgejo/forgejo/src/commit/65f9319c8fabe3b6ffabd5c341da1b25fb39e0be/poetry.toml
    url = url .. "/src/commit/" .. commit
  else
    -- Example: https://github.com/9999years/open-browser-git.nvim/blob/main/lua/open_browser_git.lua
    url = url .. "/blob/" .. commit
  end
  url = url .. "/" .. file_path

  if options ~= nil then
    -- Line range, if any.
    if options.lines ~= nil then
      -- Start line.
      url = url .. "#L" .. options.lines.line1
      if options.lines.line1 ~= options.lines.line2 then
        -- End line, if different than start.
        url = url .. "-L" .. options.lines.line2
      end
    end
  end

  return url
end

return Repo
