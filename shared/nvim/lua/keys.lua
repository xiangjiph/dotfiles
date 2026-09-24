-- Select all.
vim.keymap.set('n', '<C-a>', 'ggVG', { desc = 'Select All' })
-- Pasting over a selection no longer clobbers the clipboard.
vim.cmd([[ xnoremap <expr> p 'pgv"'.v:register.'y' ]])
