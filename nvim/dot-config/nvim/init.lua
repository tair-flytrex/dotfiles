vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.o.number = true
vim.o.relativenumber = true

vim.opt.guicursor = { }

vim.o.cursorline = true

vim.o.scrolloff = 2

vim.o.showmatch = true
vim.o.matchtime = 2


vim.o.winborder = 'rounded'

vim.o.smartindent = true
vim.o.linebreak = true
vim.o.textwidth = 500
vim.o.cinwords = ""

vim.opt.wildignore = { "*/.git/*" }
vim.o.ignorecase = true
vim.o.smartcase = true

vim.api.nvim_create_autocmd('BufWinEnter', {
  callback = function(args)
    local ft = vim.bo[args.buf].filetype
    local last_known_line = vim.api.nvim_buf_get_mark(args.buf, '"')[1]

    if
      not (ft:match('gitcommit') or ft:match('rebase'))
      and last_known_line > 1
      and last_known_line <= vim.api.nvim_buf_line_count(args.buf)
    then
      vim.cmd('normal! g`"')
    end
  end,
})

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    {
      'lewis6991/gitsigns.nvim',
      init = function()
        vim.o.updatetime = 100
        vim.opt.signcolumn = "yes"
      end,
    },
    {
      'ellisonleao/gruvbox.nvim',
      priority = 1000,
      opts = {},
      init = function()
        vim.o.termguicolors = true
        vim.cmd [[colorscheme gruvbox]]
      end,
    },
    {
      'junegunn/vim-slash',
    },
    {
      'stevearc/oil.nvim',
      opts = {
        view_options = {
          show_hidden = true,
          is_always_hidden = function(name, _)
            if name == '.git' or name == '..' then
              return true
            end

            return false
          end
        },
      },
      init = function()
        vim.keymap.set('n', '-', '<CMD>Oil<CR>', { desc = 'Open parent directory' })
      end,
    },
    {
      'kylechui/nvim-surround',
    },
    {
      'nvim-lualine/lualine.nvim',
      opts = {
        options = {
          icons_enabled = false,
          section_separators = '', component_separators = '|'
        }
      },
      init = function()
        vim.o.showmode = false
      end,
    },
    {
      'junegunn/vim-peekaboo',
    },
    {
      'nvim-telescope/telescope.nvim', version = '*',
      dependencies = {
          'nvim-lua/plenary.nvim',
          { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
      },
      init = function()
        local builtin = require('telescope.builtin')
        vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Telescope find files' })
        vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Telescope live grep' })
        vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Telescope buffers' })
        vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Telescope help tags' })
        vim.keymap.set('n', '<leader>fr', builtin.lsp_references, { desc = 'Telescope LSP references' })
        vim.keymap.set('n', '<leader>fd', builtin.diagnostics, { desc = 'Telescope diagnostics' })
      end,
    },
    {
      "neovim/nvim-lspconfig",
      config = function()
        -- Lua
        vim.lsp.config("lua_ls", {
          settings = {
            Lua = {
              diagnostics = {
                globals = { "vim" },
              },
              workspace = {
                library = vim.api.nvim_get_runtime_file("", true),
              },
            },
          },
        })

        vim.lsp.enable("lua_ls")

        vim.lsp.enable("clang")

      end,
    },
    {
      "saghen/blink.cmp",
      dependencies = {
        "saghen/blink.lib",
        "rafamadriz/friendly-snippets",
      },

      build = function()
        require("blink.cmp").build():pwait()
      end,
      opts = {
        keymap = {
          preset = "default",
        },
        completion = {
          documentation = {
            auto_show = true,
          },
        },

        sources = {
          default = {
            "lsp",
            "path",
            "snippets",
            "buffer",
          },
        },

        fuzzy = {
          implementation = "prefer_rust_with_warning",
        },
      },
    },
    {
      "nvim-treesitter/nvim-treesitter",
      build = ":TSUpdate"
    },
  },
  install = { colorscheme = { 'gruvbox' } },
  checker = { enabled = true },
  ui = {
    border = 'rounded',
    backdrop = 100,
  },
})

vim.api.nvim_create_autocmd("FileType", {
	desc = "User: fix backdrop for lazy window",
	pattern = "lazy_backdrop",
	group = vim.api.nvim_create_augroup("lazynvim-fix", { clear = true }),
	callback = function(ctx)
		local win = vim.fn.win_findbuf(ctx.buf)[1]
		vim.api.nvim_win_set_config(win, { border = "none" })
	end,
})

vim.keymap.set('n', '<leader>h', function()
  local word = vim.fn.expand('<cword>')
  vim.cmd('help ' .. "'" .. word .. "'")
end, { desc = 'Get Neovim help for word under cursor' })

vim.keymap.set('n', '<leader>w', '<cmd>w<cr>', { desc = 'Write buffer' })

vim.keymap.set({ "n", "x" }, "gy", '"+y', { desc = "Copy to system clipboard" })
vim.keymap.set({ "n", "x" }, "gp", '"+p', { desc = "Paste from system clipboard" })
vim.keymap.set({ "n", "x" }, "gP", '"+P', { desc = "Paste from system clipboard" })

-- vim.api.nvim_create_autocmd("FileType", {
--   pattern = "gitcommit",
--   callback = function()
--     local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
--
--     for _, line in ipairs(lines) do
--       if line:match("%S") and not line:match("^%s*#") then
--         return
--       end
--     end
--
--     local result = vim.system({ "git", "rev-parse", "--abbrev-ref", "HEAD", }):wait()
--
--     if result.code ~= 0 then
--       return
--     end
--
--     local issue = result.stdout:match("^(%d+)")
--
--     if issue then
--       vim.api.nvim_buf_set_lines(0, 0, 0, false, {
--         "gh-" .. issue .. " ",
--       })
--       vim.api.nvim_win_set_cursor(0, { 1, 0 })
--     end
--   end,
--   desc = 'Insert gh-<issue_number> automatically to commit file when branch starts with number',
-- })

vim.g.netrw_list_hide = [[\v^\.(|\.)/$]]
vim.api.nvim_set_hl(0, "netrwMarkFile", { link = "Search" })

vim.api.nvim_create_autocmd('FileType', {
  pattern = 'netrw',
  callback = function()
    vim.keymap.set('n', '.', 'gh', { buffer = true })
    vim.keymap.set('n', 'l', '<CR>', { buffer = true, remap = true })
    vim.keymap.set('n', 'gl', 'l', { buffer = true })
    vim.keymap.set('n', 'h', '-', { buffer = true, remap = true })
    vim.keymap.set('n', 'gh', 'h', { buffer = true })
    vim.keymap.set('n', 'q', '<cmd>bd<CR>', { buffer = true, remap = true, silent = true })
  end
})
