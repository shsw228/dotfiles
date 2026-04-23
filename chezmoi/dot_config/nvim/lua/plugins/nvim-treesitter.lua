local M = {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    ft = {
        "markdown",
        "markdown_inline",
        "query",
        "vimdoc",
    },
    build = ":TSUpdate",
    config = function()
        require("nvim-treesitter").setup({
            install_dir = vim.fn.stdpath("data") .. "/site",
        })
    end,
}

return { M }
