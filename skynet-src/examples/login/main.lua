local skynet = require "skynet"

skynet.start(function()
	-- 启动后台控制服务
	skynet.newservice("debug_console",8000)
	
	local ok, loginserver = pcall(skynet.newservice, "logind")
	if not ok then
		skynet.abort()
	end

	local gate = skynet.newservice("gated", loginserver)
	skynet.call(gate, "lua", "open" , {
		port = 8888,
		maxclient = 64,
		servername = "sample",
	})
	skynet.exit()
end)
