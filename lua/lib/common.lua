local skynet = require "skynet"
Accept = Accept or {}
Response = Response or {}
D = print
Snx = Snx or {}
function Snx.post(handle, cmd, ...)
    skynet.send(handle, "lua", "accept", cmd, ...)
end

function Snx.call(handle, cmd, ...)
    return skynet.call(handle, "lua", "response", cmd, ...)
end

function Snx.dispatch_proto(handle, proto_name, body, fd)
    skynet.send(handle, "lua", "proto", proto_name, body, fd)
end

function Dispatch(ProtoList)
    return function(session, source, _type, command, ...)
        skynet.error("agent dispatch:", _type, command, V2S({...}))
        if _type == "proto" then
            local func = ProtoList[command]
            if func then
                local ok, err, succ, code = pcall(func, ...)
                if not ok then
                    skynet.error(string.format("call proto %s fail, parm: ",command, V2S({...})), err)
                end
                
                if type(succ) == "false" then
                    Accept.send_err("sc_err", code)
                elseif type(succ) == "true" then
                    Accept.send_err("sc_err", 0)
                end
            else
                skynet.error(string.format("call proto %s fail, proto function not found", command))
            end
        elseif _type == "accept" then
            local func = assert(Accept[command])
            func(source, ...)
    
        elseif _type == "response" then
            local func = assert(Response[command])
            skynet.ret(skynet.pack(func(source, ...)))
    
        end
    end
end
