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

local function get_integer_bit(integer)
    local bit = 1
    integer = integer >> 1
    while integer > 0 do
        integer = integer >> 1
        bit = bit + 1
    end
    return bit
end

function Generate_unique_id(server_id, id)
    local bit = get_integer_bit(server_id)
    -- serverid bit 占最后四位 住前为bit位serverid,最前为id id|serverid|serverid_bit
    return (id << (bit + 4)) | (server_id << 4) | (bit - 1)
end

function Generate_unique_pid(server_id, pid)
    local bit = get_integer_bit(server_id)
    -- serverid bit 占最后四位 住前为bit位serverid,最前为id id|serverid|serverid_bit
    return (pid << (bit + 4)) | (server_id << 4) | (bit - 1)
end

function Get_unique_id_server(unique_id)
    local bit = (unique_id & 0x0F) + 1
    return (unique_id >> 4) & ((1 << bit) - 1)
end
