require "skynet.manager"
local skynet = require "skynet"
local snax = require "snax"

Gate = Gate
AgentFd = AgentFd or {}
AgentPlayerId = AgentPlayerId or {}


function accept.register_gate(fd)
	Gate = fd
end

function response.get_agent_handle(player_id)
	return AgentPlayerId[player_id]
end

function response.launcher_agent(player_id)
	local handle = AgentPlayerId[player_id]
	if handle then
		return handle
	end
	local obj = snax.newservice("agent", player_id)
	AgentFd[obj.handle] = player_id
	AgentPlayerId[player_id] = obj.handle
	return obj.handle
end

function init()

end

function exit(...)

end
