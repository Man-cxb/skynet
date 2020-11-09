require "common"
require "skynet.manager"
local skynet = require "skynet"

Gate = Gate
AgentFd = AgentFd or {}
AgentPlayerId = AgentPlayerId or {}


function Accept.register_gate(fd)
	Gate = fd
end

function Response.launcher_agent(player_id, socket_fd)
	local fd = AgentPlayerId[player_id]
	if fd then
		return fd
	end
	fd = skynet.newservice("agent", socket_fd)
	AgentFd[fd] = player_id
	AgentPlayerId[player_id] = fd
	return fd
end

function Response.get_player_agent(player_id)
	local fd = AgentPlayerId[player_id]
	if fd then
		return fd
	end
	fd = skynet.newservice "agent"
	AgentFd[fd] = player_id
	AgentPlayerId[player_id] = fd
	return fd
end

skynet.start(function()
	skynet.dispatch("lua", function(session, source, command, ...)
		if Accept[command] then
			Accept[command](source, ...)
		elseif Response[command] then
			skynet.ret(skynet.pack(Response[command](source, ...)))
		end
	end)

	skynet.register ".agentmgr"

	skynet.call(".game_gated", "lua", "open" , {
		port = 8888,
		maxclient = 64,
		gate_type = "game"
	})
end)
