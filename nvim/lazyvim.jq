# [D-NVIM-KEYMAPS] LazyVim extras we require — see docs/decisions.html#D-NVIM-KEYMAPS
# Touch ONLY .extras: LazyVim rewrites this file, and its install_version is
# load-bearing (< 8 flips the default picker/explorer back to fzf-lua/neo-tree).
# jq's `unique` sorts, matching LazyVim's own writer, so the result is a fixed
# point across real nvim startups.
.extras = ((.extras // []) + [
  "lazyvim.plugins.extras.editor.harpoon2",
  "lazyvim.plugins.extras.lang.json",
  "lazyvim.plugins.extras.lang.markdown",
  "lazyvim.plugins.extras.lang.yaml"
] | unique)
