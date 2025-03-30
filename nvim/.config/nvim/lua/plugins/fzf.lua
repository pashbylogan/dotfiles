return {
  "ibhagwan/fzf-lua",
  keys = {
    {
      "<leader>fg",
      function()
        require("fzf-lua").live_grep({ cwd = vim.loop.cwd() })
      end,
      desc = "Grep (Current Dir)",
    },
    {
      "<leader>ff",
      function()
        require("fzf-lua").files({ cwd = vim.loop.cwd() })
      end,
      desc = "Find Files (Current Dir)",
    },
    { "<C-p>", "<cmd>FzfLua git_files<cr>", desc = "Find Files (git-files)" },
  },
}
