-- Personal Neovim keymaps/options — tracked fragment loaded by the managed block
-- in ~/.config/nvim/lua/config/keymaps.lua. The nvim tree is omarchy-cp-reset, so
-- this lives in our own ~/.config/dotfiles/ namespace instead. [D-NVIM-KEYMAPS]

-- Yank to the system clipboard. The unnamed register is kept OUT of the system
-- clipboard (see clipboard="" below), so these are the explicit way to copy to it.
vim.keymap.set({ "n", "v" }, "<leader>y", '"+y', { desc = "Yank to system clipboard" })
vim.keymap.set("n", "<leader>Y", '"+Y', { desc = "Yank line to system clipboard" })

-- Options
vim.opt.hlsearch = false
-- Keep the unnamed register out of the system clipboard (primeagen-style).
-- Deferred because LazyVim re-sets clipboard=unnamedplus right after this
-- fragment loads — a plain set here would be silently overwritten.
vim.schedule(function()
  vim.opt.clipboard = ""
end)

-- Keymaps carried from the old config. Names that collide with LazyVim which-key
-- groups (<leader>f/s/d/x) are intentionally omitted.
vim.keymap.set("n", "<leader>pv", vim.cmd.Ex, { desc = "Netrw file explorer" })
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })
vim.keymap.set("n", "<C-d>", "<C-d>zz", { desc = "Half-page down (centered)" })
vim.keymap.set("n", "<C-u>", "<C-u>zz", { desc = "Half-page up (centered)" })
vim.keymap.set("x", "<leader>p", [["_dP]], { desc = "Paste over selection, keep register" })
vim.keymap.set("i", "<C-c>", "<Esc>")
vim.keymap.set("n", "Q", "<nop>")
-- Only when nvim runs inside tmux (the launcher needs a running server); outside
-- tmux, leave <C-f> as Vim's default page-down instead of a silent no-op.
if vim.env.TMUX then
  vim.keymap.set("n", "<C-f>", "<cmd>silent !tmux neww tmux-sessionizer<CR>", { desc = "tmux-sessionizer" })
end

-- Harpoon (editor.harpoon2 extra, see nvim/lazyvim.jq): personal renames of the
-- extra's <leader>H add / <leader>h menu; <leader>1-9 selects come from the
-- extra. require() in the callback loads the lazy plugin on demand, so these
-- need no plugin spec. <C-e> overrides Vim's default scroll-one-line, not a
-- LazyVim map.
vim.keymap.set("n", "<leader>a", function()
  require("harpoon"):list():add()
end, { desc = "Harpoon file" })
vim.keymap.set("n", "<C-e>", function()
  local harpoon = require("harpoon")
  harpoon.ui:toggle_quick_menu(harpoon:list())
end, { desc = "Harpoon quick menu" })

-- Same picker as LazyVim's <leader>fg, kept on <C-p> for muscle memory
-- (overrides Vim's default previous-line motion).
vim.keymap.set("n", "<C-p>", function()
  Snacks.picker.git_files()
end, { desc = "Find git files" })

-- Old <leader>d and <leader>x, renamed: those prefixes are LazyVim which-key
-- groups (debug, diagnostics/quickfix).
vim.keymap.set({ "n", "v" }, "<leader>D", [["_d]], { desc = "Delete to void register" })
vim.keymap.set("n", "<leader>cx", "<cmd>!chmod +x %<CR>", { silent = true, desc = "chmod +x current file" })
