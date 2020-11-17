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

skynet.start(function()
	skynet.dispatch("lua", Dispatch())

	skynet.register ".agentmgr"
end)
