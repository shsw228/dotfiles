return {
    "nvim-telescope/telescope.nvim",
    dependencies = {
        "nvim-lua/plenary.nvim",
        {
            "nvim-telescope/telescope-fzf-native.nvim",
            build = "make",
        },
    },
    keys = {
        {
            "<leader>ff",
            function()
                require("telescope.builtin").find_files()
            end,
            desc = "Find Files",
        },
        {
            "<leader>fg",
            function()
                require("telescope.builtin").live_grep()
            end,
            desc = "Live Grep",
        },
        {
            "<leader>fb",
            function()
                require("telescope.builtin").buffers()
            end,
            desc = "Buffers",
        },
        {
            "<leader>fh",
            function()
                require("telescope.builtin").help_tags()
            end,
            desc = "Help Tags",
        },
        {
            "<leader>p",
            function()
                require("telescope.builtin").commands()
            end,
            desc = "Command Palette",
        },
        {
            "<leader>gq",
            function()
                local actions = require("telescope.actions")
                local action_state = require("telescope.actions.state")
                local pickers = require("telescope.pickers")
                local finders = require("telescope.finders")
                local conf = require("telescope.config").values
                local root = vim.trim(vim.fn.system("ghq root"))
                local repos = vim.fn.systemlist("ghq list")
                local max_owner_width = 0

                for _, repo in ipairs(repos) do
                    local parts = vim.split(repo, "/", { plain = true })
                    local owner = #parts >= 2 and parts[#parts - 1] or repo
                    max_owner_width = math.max(max_owner_width, #owner)
                end

                pickers.new({}, {
                    prompt_title = "ghq repositories",
                    finder = finders.new_table({
                        results = repos,
                        entry_maker = function(entry)
                            local parts = vim.split(entry, "/", { plain = true })
                            local owner = #parts >= 2 and parts[#parts - 1] or entry
                            local repo = parts[#parts]
                            local display = string.format("%-" .. max_owner_width .. "s  %s", owner, repo)


                            return {
                                value = entry,
                                display = display,
                                ordinal = owner .. " " .. repo .. " " .. entry,
                            }
                        end,
                    }),
                    sorter = conf.generic_sorter({}),
                    attach_mappings = function(prompt_bufnr)
                        actions.select_default:replace(function()
                            local selection = action_state.get_selected_entry()
                            actions.close(prompt_bufnr)

                            if selection == nil then
                                return
                            end

                            local repo = selection.value
                            local path = root .. "/" .. repo

                            vim.schedule(function()
                                vim.fn.chdir(path)
                                pcall(function()
                                    local api = require("nvim-tree.api")
                                    api.tree.change_root(path)
                                    api.tree.open()
                                    api.tree.find_file({ open = false, focus = false })
                                end)
                                require("telescope.builtin").find_files({ cwd = path })
                            end)
                        end)

                        return true
                    end,
                }):find()
            end,
            desc = "ghq Repository Picker",
        },
    },
    opts = function()
        local actions = require("telescope.actions")

        return {
            defaults = {
                mappings = {
                    i = {
                        ["<C-h>"] = "which_key",
                        ["<esc>"] = actions.close,
                        ["<C-[>"] = actions.close,
                    },
                    n = {
                        ["<C-h>"] = "which_key",
                    },
                },
                winblend = 20,
            },
            extensions = {
                fzf = {
                    fuzzy = true,
                    override_generic_sorter = true,
                    override_file_sorter = true,
                    case_mode = "smart_case",
                },
            },
        }
    end,
    config = function(_, opts)
        require("telescope").setup(opts)
        require("telescope").load_extension("fzf")
    end,
}
