return {
  {
    'rose-pine/neovim',
    lazy = false,
    priority = 1000,
    name = 'rose-pine',
    config = function()
      require('rose-pine').setup({
        dark_variant = 'moon',
        dim_inactive_windows = false,
        extend_background_behind_borders = false,
        styles = {
          italic = false,
          transparency = vim.uv.os_uname().sysname == 'Darwin'
            or string.find(vim.uv.os_uname().sysname, 'Windows') ~= nil
            or vim.uv.os_uname().release:lower():find('microsoft', 1, true) ~= nil
            or vim.uv.os_uname().release:lower():find('wsl', 1, true) ~= nil,
        },
      })

      vim.cmd('colorscheme rose-pine')

      local palette = require('rose-pine.palette')
      vim.api.nvim_set_hl(0, 'SnacksPickerDir', { fg = palette.subtle })
    end,
  },
}
