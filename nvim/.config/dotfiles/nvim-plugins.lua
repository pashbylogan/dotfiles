-- Personal lazy.nvim specs — tracked fragment returned by the generated loader
-- ~/.config/nvim/lua/plugins/dotfiles.lua. [D-NVIM-KEYMAPS]
--
-- Bare plugin names, not owner/repo: lazy merges specs by name, so a bare name
-- follows upstream repo moves (mini.pairs already moved echasnovski/ ->
-- nvim-mini/) instead of creating a phantom second plugin.
return {
  -- catppuccin stays enabled: omarchy's theme fleet needs it for
  -- `omarchy theme set catppuccin`.
  -- trouble stays enabled: it lazy-loads on its own keys (zero startup cost)
  -- and todo-comments' <leader>xt/<leader>xT call :Trouble.
  { "flash.nvim", enabled = false },
  { "mini.pairs", enabled = false },
  { "persistence.nvim", enabled = false },
  { "bufferline.nvim", enabled = false },
  { "lualine.nvim", enabled = false },
  -- netrw (<leader>pv) is the only file navigator. The seeded editor.neo-tree
  -- extra must STAY in lazyvim.json: at install_version 8 that entry is what
  -- suppresses snacks_explorer, so extra-kept + plugin-disabled is the only
  -- combination that yields netrw-only.
  { "neo-tree.nvim", enabled = false },
}
