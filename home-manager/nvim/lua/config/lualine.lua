local M = {}

local battery_cache = {
    text = "",
    updated_at = 0,
}

local spinner_frames = { "-", "\\", "|", "/" }
local battery_icons = {
    empty = "󰂎",
    low = "󰁺",
    mid = "󰁽",
    high = "󰂀",
    full = "󰁹",
    charging = "󰂄",
}

local function spinner()
    local now = vim.uv.hrtime()
    local frame = math.floor(now / 120000000) % #spinner_frames
    return spinner_frames[frame + 1]
end

local function battery()
    local now = vim.uv.now()
    if now - battery_cache.updated_at < 30000 then
        return battery_cache.text
    end

    local output = vim.fn.system("pmset -g batt")
    local percent = output:match("(%d?%d?%d)%%")
    local is_charging = output:match("AC Power") ~= nil or output:match("charging") ~= nil

    if percent == nil then
        battery_cache.text = ""
    elseif is_charging then
        battery_cache.text = string.format("%s %s%%%%", battery_icons.charging, percent)
    else
        local value = tonumber(percent) or 0
        local icon = battery_icons.empty

        if value >= 95 then
            icon = battery_icons.full
        elseif value >= 70 then
            icon = battery_icons.high
        elseif value >= 40 then
            icon = battery_icons.mid
        else
            icon = battery_icons.low
        end

        battery_cache.text = string.format("%s %s%%%%", icon, percent)
    end

    battery_cache.updated_at = now
    return battery_cache.text
end

local function lsp_status()
    local names = {}
    local seen = {}

    for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
        if not seen[client.name] then
            table.insert(names, client.name)
            seen[client.name] = true
        end
    end

    local progress = vim.lsp.status():gsub("%s+", " ")
    if progress ~= "" then
        if #progress > 28 then
            progress = progress:sub(1, 25) .. "..."
        end

        return string.format("LSP %s %s", spinner(), progress)
    end

    if #names == 0 then
        return ""
    end

    return "LSP " .. table.concat(names, ",")
end

function M.setup()
    require("lualine").setup({
        options = {
            theme = "auto",
            globalstatus = true,
            component_separators = { left = "|", right = "|" },
            section_separators = { left = "", right = "" },
            refresh = {
                statusline = 100,
                tabline = 1000,
                winbar = 1000,
            },
        },
        sections = {
            lualine_a = { { "mode", fmt = function(str) return str:sub(1, 1) end } },
            lualine_b = { "branch" },
            lualine_c = {
                {
                    "filename",
                    path = 1,
                    symbols = {
                        modified = " [+]",
                        readonly = " [RO]",
                        unnamed = "[No Name]",
                    },
                },
                "diagnostics",
            },
            lualine_x = {
                {
                    lsp_status,
                    color = { fg = "#89b4fa", gui = "bold" },
                },
                {
                    "filetype",
                    icon_only = false,
                    color = { fg = "#a6e3a1" },
                },
            },
            lualine_y = {
                {
                    battery,
                    color = { fg = "#f9e2af" },
                },
            },
            lualine_z = {
                {
                    function()
                        return os.date("%H:%M")
                    end,
                    color = { fg = "#f38ba8", gui = "bold" },
                },
            },
        },
    })
end

return M
