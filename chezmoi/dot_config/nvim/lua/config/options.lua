local opt = vim.opt

local transparent_groups = {
    "Normal",
    "NormalFloat",
    "SignColumn",
    "EndOfBuffer",
    "LineNr",
    "CursorLineNr",
    "FoldColumn",
    "StatusLine",
    "StatusLineNC",
    "VertSplit",
    "WinSeparator",
    "FloatBorder",
    "Pmenu",
    "PmenuSel",
    "NotifyBackground",
    "NvimTreeNormal",
    "NvimTreeNormalNC",
    "NvimTreeEndOfBuffer",
    "NoiceCmdlinePopup",
    "NoiceCmdlinePopupBorder",
    "NoicePopupmenu",
    "NoicePopupmenuBorder",
    "NoiceConfirm",
    "NoiceMini",
    "ToggleTerm",
    "ToggleTermNormal",
    "ToggleTermBorder",
}

for _, group in ipairs(transparent_groups) do
    vim.api.nvim_set_hl(0, group, { bg = "none" })
end

opt.number = true
opt.relativenumber = true
opt.tabstop = 4
opt.shiftwidth = 4
opt.ignorecase = true
opt.smartcase = true

vim.api.nvim_create_autocmd("TermOpen", {
    pattern = "*",
    callback = function()
        vim.opt_local.number = false
        vim.opt_local.relativenumber = false
        vim.cmd("startinsert")
    end,
})
