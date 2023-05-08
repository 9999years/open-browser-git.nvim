# open-browser-git.nvim

## Getting started

```lua
require("open_browser_git").setup {
    command_prefix = "OpenGit",
}
```

Creates `:OpenGit [path]`, which opens `path` or the current file on GitHub or
GitLab in your default browser.

Let me know if there's other Git providers you want to bind to.
