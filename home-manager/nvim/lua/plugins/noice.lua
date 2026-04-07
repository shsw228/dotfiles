return {
    {
        "rcarriga/nvim-notify",
        opts = {
            background_colour = "#000000",
            render = "wrapped-compact",
            timeout = 3000,
        },
    },
    {
        "folke/noice.nvim",
        event = "VeryLazy",
        dependencies = {
            "MunifTanjim/nui.nvim",
            "rcarriga/nvim-notify",
        },
        opts = {
            lsp = {
                override = {
                    ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
                    ["vim.lsp.util.stylize_markdown"] = true,
                },
            },
            presets = {
                bottom_search = true,
                command_palette = true,
                long_message_to_split = true,
            },
            routes = {
                {
                    filter = {
                        event = "notify",
                        find = "No information available",
                    },
                    opts = { skip = true },
                },
            },
        },
        config = function(_, opts)
            require("notify").setup(opts.notify or {})
            vim.notify = require("notify")
            require("noice").setup(opts)
        end,
    },
}
