return {
    "akinsho/toggleterm.nvim",
    version = "*",
    keys = {
        {
            "<leader>t",
            "<cmd>ToggleTerm<CR>",
            desc = "Toggle Terminal",
        },
    },
    opts = {
        direction = "float",
        start_in_insert = true,
        insert_mappings = true,
        terminal_mappings = true,
        close_on_exit = true,
        float_opts = {
            border = "curved",
            winblend = 10,
        },
    },
}
