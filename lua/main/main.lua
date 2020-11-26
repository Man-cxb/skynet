package.path = "lua/main/?.lua;" .. package.path

local skynet = require "skynet"
local harbor = require "skynet.harbor"
local snax = require "skynet.snax"
require "skynet.manager"	-- import skynet.launch, ...
local datacenter = require "skynet.datacenter"
require "tool"
require "hotfix"
require "config"

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

        init_cfg()

        -- print("cfg sdk:",V2S(Getcfg("sdk")))
        -- print("cfg system.game:",V2S(sharetable.query("system.game")))
        -- print("cfg system.service:",V2S(sharetable.query("system.service")))
        -- for handle, _ in pairs(all_snx) do
        --     send_snx(handle, "hotfix_cfgs", cfg_def)
        -- end
        -- system.hotfix_cfgs(cfg_def)

end)