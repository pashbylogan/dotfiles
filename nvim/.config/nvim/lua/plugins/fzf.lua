return {
  "ibhagwan/fzf-lua",
  keys = {
    { "<leader>fg", LazyVim.pick("live_grep"), desc = "Grep (Root Dir)" },
    { "<C-p>", "<cmd>FzfLua git_files<cr>", desc = "Find Files (git-files)" },
  },
}
