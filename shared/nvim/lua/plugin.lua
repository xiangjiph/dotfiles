-- Keep the base editor usable on older or offline servers.
if vim.fn.has('nvim-0.10') == 0 then
  vim.notify('Dotfiles plugins require Neovim 0.10 or newer; using base settings.', vim.log.levels.WARN)
  return
end

local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(lazypath .. '/lua/lazy/init.lua') then
  if vim.fn.executable('git') == 0 then
    vim.notify('Git is required to install Neovim plugins; using base settings.', vim.log.levels.WARN)
    return
  end
  local output = vim.fn.system({ 'git', 'clone', '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git', '--branch=stable', lazypath })
  if vim.v.shell_error ~= 0 then
    vim.notify('Could not install lazy.nvim; using base settings.\n' .. output, vim.log.levels.WARN)
    return
  end
end
vim.opt.rtp:prepend(lazypath)
require('lazy').setup('plugins')
