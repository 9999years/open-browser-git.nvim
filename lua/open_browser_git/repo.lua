-- type Repo
--
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
local Repo = {}

-- Construct a new repository from a hostname (like "github.com"), a username
-- (like "9999years"), and a repository name (like "open-browser-git.nvim").
--
-- Repo:new({host: string, user: string, repo: string, remote_name: string|nil}) -> self
function Repo:new(ret)
  if ret.host:find("gitlab") then
    ret.flavor = "gitlab"
  elseif ret.host:find("github") then
    ret.flavor = "github"
  end
  setmetatable(ret, self)
  self.__index = self
  return ret
end

--  Display the repo to the user.
--
--  self:display() -> string
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
--  self:url() -> string
function Repo:url()
  -- TODO: Support non-HTTPS repository URLs?
  -- NB: This _could_ forward out to `self:display` but philisophically I
  -- want these to be separate.
  --
  -- Example: https://github.com/NixOS/nixpkgs
  return "https://" .. self.host .. "/" .. self.user .. "/" .. self.repo
end

-- Get the URL for a commit or branch in this repo.
--
-- NB: May want to split this into two functions in the future.
--
-- self:url_for_commit(commit_hash) -> string
function Repo:url_for_commit(commit_hash)
  -- Example: https://github.com/NixOS/nixpkgs/tree/master
  return self:url() .. "/tree/" .. commit_hash
end

-- Get the URL for an issue in this repo, by number.
-- self:url_for_issue(issue_number) -> string
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
-- self:url_for_pr(pr_number) -> string
function Repo:url_for_pr(pr_number)
  if self.flavor == "gitlab" then
    -- Example: https://gitlab.haskell.org/ghc/ghc/-/merge_requests/10393
    return self:url() .. "/-/merge_requests/" .. pr_number
  else
    -- Example: https://github.com/NixOS/nixpkgs/pull/230398
    return self:url() .. "/pull/" .. pr_number
  end
end

-- Get the URL for a given path in this repo.
-- Paths are given relative to the repository root.
-- Options (any values may be nil):
--  - lines: {first: int, last: int}. A range of lines to view.
--    If start == end, implementations may simplify the URL.
--
-- self:url_for_file(file_path, commit, options: table) -> string
function Repo:url_for_file(file_path, commit, options)
  local url = self:url()

  if self.flavor == "gitlab" then
    -- Example: https://gitlab.haskell.org/ghc/ghc/-/blob/master/.gitattributes
    url = url .. "/-/blob/" .. commit
  else
    -- Example: https://github.com/9999years/open-browser-git.nvim/blob/main/lua/open_browser_git.lua
    url = url .. "/blob/" .. commit
  end
  url = url .. "/" .. file_path

  if options ~= nil then
    -- Line range, if any.
    if options.lines ~= nil then
      -- Start line.
      url = url .. "#L" .. options.lines.first
      if options.lines.first ~= options.lines.last then
        -- End line, if different than start.
        url = url .. "-L" .. options.lines.last
      end
    end
  end

  return url
end

return Repo
