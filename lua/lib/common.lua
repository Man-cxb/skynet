local skynet = require "skynet"

function interval_timeout(ti, func, ...)
    local nexttime = skynet.now() + ti
    local args = table.pack(...)
    local function call_back()
        if not nexttime then
            return
        end
        local f = assert(_ENV[func], func.."() not found")
        f(table.unpack(args, 1, args.n))
        if not nexttime then
            return
        end
        nexttime = nexttime + ti
        local dt = nexttime - skynet.now()
        if dt < 0 then dt = 0 end
        skynet.timeout(dt, call_back)
    end
    skynet.timeout(ti, call_back)
    return function() nexttime = nil end
end