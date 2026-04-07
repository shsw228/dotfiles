vim.g.mapleader = ","
vim.g.maplocalleader = ","

vim.keymap.set("i", "jj", "<Esc>", { silent = true, desc = "Exit insert mode" })
vim.keymap.set("n", "<leader>w", "<cmd>write<CR>", { silent = true, desc = "Save buffer" })
vim.keymap.set("n", "<Esc><Esc>", "<cmd>nohlsearch<CR>", { silent = true, desc = "Clear search highlight" })
