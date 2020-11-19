require "common"
require "skynet.manager"
local skynet = require "skynet"
local snax = require "skynet.snax"

Gate = Gate
AgentFd = AgentFd or {}
AgentPlayerId = AgentPlayerId or {}


function accept.register_gate(fd)
	Gate = fd
end

function response.launcher_agent(player_id, socket_fd)
	local handle = AgentPlayerId[player_id]
	if handle then
		return handle
	end
	handle = snax.newservice("agent", socket_fd, Gate)
	AgentFd[handle] = player_id
	AgentPlayerId[player_id] = handle
	return handle
end

function init(server_name)
	skynet.register(server_name)

end

function exit(...)

end
