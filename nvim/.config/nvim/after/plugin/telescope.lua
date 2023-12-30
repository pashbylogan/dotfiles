local builtin = require('telescope.builtin')
vim.keymap.set('n', '<leader>ff', function()
    builtin.find_files({
        hidden = true,
        file_ignore_patterns = { "^.git/", "^node_modules/", "^.cache/" }
    })
end)
vim.keymap.set('n', '<C-p>', builtin.git_files, {})
vim.keymap.set('n', '<leader>hh', builtin.help_tags, {})
vim.keymap.set('n', '<leader>fg', function()
	builtin.grep_string({ search = vim.fn.input("Grep > ") })
end)
