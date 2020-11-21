local skynet = require "skynet"
local harbor = require "skynet.harbor"
local snax = require "skynet.snax"
require "skynet.manager"	-- import skynet.launch, ...

skynet.start(function()
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
end)