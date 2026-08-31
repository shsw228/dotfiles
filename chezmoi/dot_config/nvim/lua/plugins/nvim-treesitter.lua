-- main ブランチの nvim-treesitter は lazy-load 非対応で、パーサのインストールと
-- ハイライトの有効化をいずれも明示的に行う必要がある（上流 README の Setup 節）。
-- パーサのビルドは `tree-sitter build` に委譲されるため tree-sitter-cli が必須。
local ensure_installed = {
    "bash",
    "c",
    "css",
    "diff",
    "dockerfile",
    "git_config",
    "git_rebase",
    "gitcommit",
    "gitignore",
    "go",
    "html",
    "javascript",
    "json",
    "latex",
    "lua",
    "luadoc",
    "make",
    "markdown",
    "markdown_inline",
    "python",
    "query",
    "regex",
    "rust",
    "swift",
    "toml",
    "tsx",
    "typescript",
    "vim",
    "vimdoc",
    "yaml",
}

local M = {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
        local ts = require("nvim-treesitter")
        ts.setup({
            install_dir = vim.fn.stdpath("data") .. "/site",
        })

        -- インストール済みなら no-op。非同期なので起動をブロックしない。
        ts.install(ensure_installed)

        vim.api.nvim_create_autocmd("FileType", {
            callback = function(ev)
                local lang = vim.treesitter.language.get_lang(vim.bo[ev.buf].filetype)
                if not lang or not pcall(vim.treesitter.language.add, lang) then
                    return
                end
                pcall(vim.treesitter.start, ev.buf, lang)
            end,
        })
    end,
}

return { M }
