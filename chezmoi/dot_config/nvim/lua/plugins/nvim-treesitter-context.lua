local M = {
    "nvim-treesitter/nvim-treesitter-context",
    event = "VeryLazy",
    opts = {
        mode = "cursor",
        max_lines = 5,
        multiline_threshold = 1,
    },
}

return { M }
