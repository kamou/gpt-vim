
function get_function_span()
    local bufnr = vim.api.nvim_get_current_buf()
    local lang = vim.api.nvim_buf_get_option(bufnr, 'filetype')

    local cursor = vim.api.nvim_win_get_cursor(0)
    local opts = {['lang'] = lang }
    local node = vim.treesitter.get_node_at_pos(bufnr, cursor[1] - 1, cursor[2], opts)

    while (node ~= nil and not node:type():find("^function_")) do
        node = node:parent()
    end

    if node ~= nil then
        local start_row, start_col, end_row, end_col = node:range()

        return {
            ["start"] = {start_row + 1, start_col + 1},
            ["end"]   = {end_row + 1, end_col + 1},
        }
    end
end

