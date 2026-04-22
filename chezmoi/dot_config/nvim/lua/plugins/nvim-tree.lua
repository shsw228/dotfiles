-- open File Tree when open
local function open_nvim_tree()
    if vim.fn.argc(-1) > 0 or #vim.api.nvim_list_uis() == 0 then
        return
    end

    require("nvim-tree.api").tree.open()
end

vim.api.nvim_create_autocmd({ "VimEnter" }, { callback = open_nvim_tree })

return {
  "nvim-tree/nvim-tree.lua",
  version = "*",
  lazy = false,
  dependencies = {
    "nvim-tree/nvim-web-devicons",
  },
  keys = {
    {mode = "n", "<C-n>", "<cmd>NvimTreeToggle<CR>", desc = "NvimTreeをトグルする"},
    {mode = "n", "<C-m>", "<cmd>NvimTreeFocus<CR>", desc = "NvimTreeにフォーカス"},
    {mode = "n", "<leader>e", "<cmd>NvimTreeToggle<CR>", desc = "NvimTreeをトグルする"},
    {mode = "n", "<leader>E", "<cmd>NvimTreeFindFile<CR>", desc = "現在のファイルをNvimTreeで表示"},
  },
  config = function()
    require("nvim-tree").setup {
      git = {
        enable = true,
        ignore = true,
      },
      update_focused_file = {
        enable = true,
        update_root = false,
      },
    }
  end,
}
