# Smart Notes Plugin

Automatically places notes in the right directory based on content analysis.

## Setup

Add to your nvim config:

```lua
require("smart-notes").setup({
  notes_dir = "~/documents/notes",  -- default
  default_extension = ".md",        -- default
})
```

## Usage

### Commands
- `:Note [content]` - Create note with optional initial content
- `:QuickNote` - Prompt for content and create note

### Keymaps
- `<leader>nn` - New blank note
- `<leader>nq` - Quick note with input

## How it works

The plugin analyzes note content and places it in subdirectories based on:

1. **Project keywords**: hpg, storyboard → `hpg/`
2. **Technical domains**: nvim, tmux → `coding/terminal/`
3. **Content domains**: budget → `finance/`
4. **Special content**: TODO, FEAT, BUG → appends to `todo.md`

Notes are automatically named based on title or first line content.