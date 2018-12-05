local parser = require 'parser'
local matcher = require 'matcher'

return function (lsp, params)
    local uri = params.textDocument.uri
    local text = lsp:loadText(uri)
    if not text then
        return nil, 'Cannot find file: ' .. uri
    end
    local start_clock = os.clock()
    -- lua是从1开始的，因此都要+1
    local pos = parser.calcline.position_utf8(text, params.position.line + 1, params.position.character + 1)
    local suc, results, info = matcher.implementation(text, pos)
    if not suc then
        if info then
            log.debug(results, uri)
            info.lua = nil
            log.debug(table.dump(info))
        end
        return {}
    end

    local locations = {}
    for i, result in ipairs(results) do
        local start, finish = result[1], result[2]
        local start_row,  start_col  = parser.calcline.rowcol_utf8(text, start)
        local finish_row, finish_col = parser.calcline.rowcol_utf8(text, finish)
        locations[i] = {
            uri = uri,
            range = {
                start = {
                    line = start_row - 1,
                    character = start_col - 1,
                },
                ['end'] = {
                    line = finish_row - 1,
                    -- 这里不用-1，因为前端期待的是匹配完成后的位置
                    character = finish_col,
                },
            }
        }
    end

    local response = locations
    local passed_clock = os.clock() - start_clock
    if passed_clock >= 0.01 then
        log.warn(('[Goto Implementation] takes [%.3f] sec, size [%s] bits.'):format(passed_clock, #text))
    end

    return response
end
