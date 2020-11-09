require "common"
local skynet = require "skynet"
local socket_fd = ...
local err_cfg = {}
ProtoList = ProtoList or {}

function Accept.send_client_proto(proto, body)
	skynet.send(".game_gated", "lua", "send_proto", socket_fd, proto, body)
end

function Accept.send_err(name, code, msg, session)
	local cfg = err_cfg[code] or {}
	Accept.send_client_proto("sc_err", {proto_name = name, code = cfg.id or 0, content = msg, session = session})
end

skynet.start(function()
	skynet.dispatch("lua", function(session, source, _type, command, ...)
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
		else
			if Accept[command] then
				pcall(Accept[command], ...)
			elseif Response[command] then
				skynet.ret(skynet.pack(Response[command](command, ...)))
			end
		end
	end)
end)
