local skynet = require "skynet"
local harbor = require "skynet.harbor"
local snax = require "skynet.snax"
require "skynet.manager"	-- import skynet.launch, ...
local datacenter = require "skynet.datacenter"

skynet.start(function()
    	-- 启动logind 开始监听端口8001
        local login_obj = snax.newservice("logind")
        datacenter.set("logind_handle", login_obj.handle)

        local agentmgr_obj = snax.newservice("agentmgr")
        datacenter.set("agentmgr_handle", agentmgr_obj.handle)

        -- -- 启动游戏服网关
        local game_gate = skynet.newservice("gated", "game", agentmgr_obj.handle)
        skynet.call(game_gate, "lua", "open" , {
            port = 8888,
            maxclient = 64
        })
        datacenter.set("game_gate_handle", game_gate)
        
        -- -- skynet.newservice("dbmgr")
    
        skynet.newservice("debug_console", 8000)
end)