return {
    "keaising/im-select.nvim",
    event = "VeryLazy",
    config = function()
        if vim.fn.executable("macism") ~= 1 then
            return
        end

        require("im_select").setup({
            default_im_select = "com.apple.keylayout.ABC",
            default_command = "macism",
            set_default_events = { "InsertLeave", "CmdlineLeave" },
            set_previous_events = { "InsertEnter" },
            keep_quiet_on_no_binary = true,
            async_switch_im = true,
        })
    end,
}
