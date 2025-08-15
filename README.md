# open-browser-git.nvim

## Getting started

```lua
require("open_browser_git").setup {
    -- These are default values and can be omitted.
    commands = {
      open = "OpenGit",
      copy = "CopyGit",
    }
}
```

Creates `:OpenGit [path]`, which opens `path` or the current file on GitHub or
GitLab in your default browser. Similarly, `:CopyGit` copies the URL directly
to your clipboard.

If you've selected a line or range of lines, the permalink will go directly to
that line or range.

Let me know if there's other Git providers you want to bind to.
