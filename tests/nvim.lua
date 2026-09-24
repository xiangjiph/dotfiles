-- Run with nvim --headless -u NONE -i NONE -n -l tests/nvim.lua.
-- Exercise config without loading installed plugins or accessing the network.
local repo = vim.fn.getcwd()
vim.opt.rtp:prepend(repo .. '/shared/nvim')
for _, path in ipairs(vim.fn.glob(repo .. '/shared/nvim/**/*.lua', false, true)) do
  assert(loadfile(path))
end

local original_has = vim.fn.has
local original_executable = vim.fn.executable
local original_system = vim.fn.system
local original_stat = vim.uv.fs_stat
local original_notify = vim.notify
local original_uname = vim.uv.os_uname
local warnings, setups, clones = 0, 0, 0
vim.notify = function() warnings = warnings + 1 end
vim.fn.system = function()
  clones = clones + 1
  original_system({ 'sh', '-c', 'exit 1' })
  return 'offline test'
end
package.preload.lazy = function()
  return { setup = function(spec)
    assert(spec == 'plugins')
    setups = setups + 1
  end }
end

-- All profiles load the same keymaps and settings without an OS gate.
for _, sysname in ipairs({ 'Darwin', 'Linux' }) do
  vim.uv.os_uname = function() return { sysname = sysname, release = 'test' } end
  vim.fn.has = function(name) return name == 'nvim-0.10' and 1 or original_has(name) end
  vim.uv.fs_stat = function() return {} end
  package.loaded.plugin = nil
  dofile(repo .. '/shared/nvim/init.lua')
  assert(vim.o.expandtab and vim.o.relativenumber and vim.o.mouse == '')
  assert(vim.fn.maparg('<C-a>', 'n') == 'ggVG')
end
assert(setups == 2 and clones == 0)

vim.fn.has = function() return 0 end
dofile(repo .. '/shared/nvim/lua/plugin.lua')
vim.fn.has = function() return 1 end
vim.uv.fs_stat = function() return nil end
vim.fn.executable = function() return 0 end
dofile(repo .. '/shared/nvim/lua/plugin.lua')
vim.fn.executable = function() return 1 end
dofile(repo .. '/shared/nvim/lua/plugin.lua')
assert(warnings == 3 and clones == 1 and setups == 2)

-- Use the actual theme config against each supported kernel identity.
local transparency
package.preload['rose-pine'] = function()
  return { setup = function(opts) transparency = opts.styles.transparency end }
end
package.preload['rose-pine.palette'] = function() return { subtle = '#aaaaaa' } end
local original_cmd = vim.cmd
vim.cmd = function(command) assert(command == 'colorscheme rose-pine') end
for _, platform in ipairs({
  { 'Darwin', '25.0', true },
  { 'Linux', '6.6.87.2-microsoft-standard-WSL2', true },
  { 'Linux', '4.4.0-Microsoft', true },
  { 'Linux', '6.8.0-generic', false },
}) do
  vim.uv.os_uname = function() return { sysname = platform[1], release = platform[2] } end
  dofile(repo .. '/shared/nvim/lua/plugins/colorscheme.lua')[1].config()
  assert(transparency == platform[3])
end
vim.cmd = original_cmd
vim.fn.has, vim.fn.executable, vim.fn.system = original_has, original_executable, original_system
vim.uv.fs_stat, vim.uv.os_uname, vim.notify = original_stat, original_uname, original_notify
print('Shared editor loading, keymaps, fallback paths, and platform theme checks passed.')
