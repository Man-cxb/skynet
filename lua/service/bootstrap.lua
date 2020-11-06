local skynet = require "skynet"
local harbor = require "skynet.harbor"
require "skynet.manager"	-- import skynet.launch, ...

skynet.start(function()
	local standalone = skynet.getenv "standalone" --判断启动的是一个 master 节点还是 slave 节点
	
	local launcher = assert(skynet.launch("snlua","launcher"))
	skynet.name(".launcher", launcher)

	local harbor_id = tonumber(skynet.getenv "harbor" or 0)
	if harbor_id == 0 then	-- 单节点
		assert(standalone ==  nil)
		standalone = true
		skynet.setenv("standalone", "true")

		-- 单节点模式下，是不需要通过内置的 harbor 机制做节点间通讯的。
		-- 但为了兼容（因为你还是有可能注册全局名字），需要启动一个叫做 cdummy 的服务，它负责拦截对外广播的全局名字变更
		local ok, slave = pcall(skynet.newservice, "cdummy")
		if not ok then
			skynet.abort()
		end
		skynet.name(".cslave", slave)
	else	-- 多节点
		if standalone then  -- 主节点
			if not pcall(skynet.newservice,"cmaster") then
				skynet.abort()
			end
		end
		
		local ok, slave = pcall(skynet.newservice, "cslave")
		if not ok then
			skynet.abort()
		end
		skynet.name(".cslave", slave)
	end

	if standalone then -- 主节点或单节点需要启动数据保存服
		-- local datacenter = skynet.newservice "datacenterd"
		-- skynet.name("DATACENTER", datacenter)
	end

	-- skynet.newservice "service_mgr"
	-- pcall(skynet.newservice,skynet.getenv "start" or "main")

	local login_gate = skynet.newservice "gated"
	skynet.name(".login_gated", login_gate)
	-- 启动logind 开始监听端口8001
	skynet.newservice "logind"
	
	local game_gate = skynet.newservice "gate"
	skynet.name(".game_gated", game_gate)
	skynet.newservice "agentmgr"

	-- skynet.newservice("dbmgr")

	skynet.newservice("debug_console", 8000)
end)
