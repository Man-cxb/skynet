thread = 8
logger = nil
harbor = 0
start = "main"
bootstrap = "snlua bootstrap"	-- 引导服务 以单节点或多节点启动框架
luaservice = "./service/?.lua;./examples/login/?.lua"
lualoader = "lualib/loader.lua"
cpath = "./cservice/?.so"
