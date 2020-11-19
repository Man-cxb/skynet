local skynet = require "skynet"
local harbor = require "skynet.harbor"
local snax = require "skynet.snax"
require "skynet.manager"	-- import skynet.launch, ...

function Init()
	local launcher = assert(skynet.launch("snlua","launcher"))
	skynet.name(".launcher", launcher)

    -- 单节点模式下，是不需要通过内置的 harbor 机制做节点间通讯的。
    -- 但为了兼容（因为你还是有可能注册全局名字），需要启动一个叫做 cdummy 的服务，它负责拦截对外广播的全局名字变更
    local ok, slave = pcall(skynet.newservice, "cdummy")
    if not ok then
        skynet.abort()
    end
    skynet.name(".cslave", slave)
    
	-- 启动logind 开始监听端口8001
    snax.newservice("logind", ".logind")
    
    -- -- 启动游戏服网关
	local game_gate = skynet.newservice("gated", ".game_gated")
	skynet.call(game_gate, "lua", "open" , {
        port = 8888,
		maxclient = 64
    })

    snax.newservice("agentmgr", ".agentmgr")

	-- -- skynet.newservice("dbmgr")

	skynet.newservice("debug_console", 8000)
end

skynet.start(function()
    Init()    
end)