-- package.path = "lua/main/?.lua;" .. package.path

local skynet = require "skynet"
local snax = require "snax"
require "skynet.manager"	-- import skynet.launch, ...
local datacenter = require "skynet.datacenter"
require "tool"
require "hotfix"
require "config"

all_snax = all_snax or {}

skynet.start(function()
    init_cfg()

    skynet.newservice("dbmgr")

    -- 启动logind 开始监听端口8001
    local login_obj = snax.newservice("logind")
    datacenter.set("logind_handle", login_obj.handle)

    local agentmgr_obj = snax.newservice("agentmgr")
    datacenter.set("agentmgr_handle", agentmgr_obj.handle)

    local harbar = tonumber(skynet.getenv("harbor"))
	local cfg = GetCfg("system.harbor")[harbar]
    -- -- 启动游戏服网关
    local game_gate = skynet.newservice("gated", "agent", agentmgr_obj.handle)
    skynet.call(game_gate, "lua", "open" , {
        port = cfg.game_port,
        maxclient = cfg.max_game_conn
    })
    datacenter.set("game_gate_handle", game_gate)

    snax.newservice("dbport", "127.0.0.1", cfg.debug_port)

    skynet.register(".main")

    skynet.newservice("httpd")

    all_snax = {login_obj, agentmgr_obj}
end)