return {
    {
        "mason-org/mason.nvim",
        opts = {},
    },
    {
        "mason-org/mason-lspconfig.nvim",
        dependencies = {
            "mason-org/mason.nvim",
            "neovim/nvim-lspconfig",
        },
        opts = {
            ensure_installed = {
                "bashls",
                "jsonls",
                "lua_ls",
                "marksman",
                "taplo",
                "yamlls",
            },
        },
    },
    {
        "neovim/nvim-lspconfig",
        dependencies = {
            "mason-org/mason-lspconfig.nvim",
        },
        config = function()
            local capabilities = vim.lsp.protocol.make_client_capabilities()
            local servers = {
                "bashls",
                "jsonls",
                "lua_ls",
                "marksman",
                "sourcekit",
                "taplo",
                "yamlls",
            }

            vim.api.nvim_create_autocmd("LspAttach", {
                callback = function(args)
                    local bufnr = args.buf

                    local map = function(mode, lhs, rhs, desc)
                        vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
                    end

                    map("n", "K", vim.lsp.buf.hover, "LSP Hover")
                    map("n", "gd", vim.lsp.buf.definition, "Goto Definition")
                    map("n", "gD", vim.lsp.buf.declaration, "Goto Declaration")
                    map("n", "gi", vim.lsp.buf.implementation, "Goto Implementation")
                    map("n", "gr", vim.lsp.buf.references, "Goto References")
                    map("n", "<leader>rn", vim.lsp.buf.rename, "Rename Symbol")
                    map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, "Code Action")
                    map("n", "<leader>f", function()
                        vim.lsp.buf.format({ async = true })
                    end, "Format Buffer")
                    map("n", "[d", vim.diagnostic.goto_prev, "Previous Diagnostic")
                    map("n", "]d", vim.diagnostic.goto_next, "Next Diagnostic")
                    map("n", "<leader>d", vim.diagnostic.open_float, "Line Diagnostics")
                end,
            })

            vim.diagnostic.config({
                float = { border = "rounded" },
                severity_sort = true,
                virtual_text = true,
            })

            for _, server in ipairs(servers) do
                vim.lsp.config(server, {
                    capabilities = capabilities,
                })
            end

            vim.lsp.config("lua_ls", {
                capabilities = capabilities,
                settings = {
                    Lua = {
                        diagnostics = {
                            globals = { "vim" },
                        },
                        workspace = {
                            checkThirdParty = false,
                        },
                    },
                },
            })

            vim.lsp.config("sourcekit", {
                capabilities = capabilities,
                cmd = { "/usr/bin/xcrun", "sourcekit-lsp" },
            })

            for _, server in ipairs(servers) do
                vim.lsp.enable(server)
            end
        end,
    },
}
