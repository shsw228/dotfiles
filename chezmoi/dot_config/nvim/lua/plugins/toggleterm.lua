return {
    "akinsho/toggleterm.nvim",
    version = "*",
    keys = {
        {
            "<leader>t",
            "<cmd>ToggleTerm<CR>",
            desc = "Toggle Terminal",
        },
        {
            "<leader>lg",
            function()
                local Terminal = require("toggleterm.terminal").Terminal
                local lazygit = Terminal:new({
                    cmd = "lazygit",
                    direction = "float",
                    hidden = true,
                    close_on_exit = true,
                })
                lazygit:toggle()
            end,
            desc = "Toggle Lazygit",
        },
    },
    config = function()
        local Terminal = require("toggleterm.terminal").Terminal

        require("toggleterm").setup({
            direction = "float",
            start_in_insert = true,
            insert_mappings = true,
            terminal_mappings = true,
            close_on_exit = true,
            float_opts = {
                border = "curved",
                winblend = 10,
            },
        })

        local lazygit = Terminal:new({
            cmd = "lazygit",
            direction = "float",
            hidden = true,
            close_on_exit = true,
        })

        vim.keymap.set("t", "<leader>t", function()
            vim.cmd("ToggleTerm")
        end, { desc = "Toggle Terminal" })

        vim.keymap.set({ "n", "t" }, "<leader>lg", function()
            lazygit:toggle()
        end, { desc = "Toggle Lazygit" })
    end,
}
