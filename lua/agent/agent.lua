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
	skynet.dispatch("lua", Dispatch(ProtoList))
end)
