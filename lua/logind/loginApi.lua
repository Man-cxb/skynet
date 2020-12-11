local skynet = require "skynet"
local snax = require "snax"

-- 分发协议方法，方法上面不要有accept方法，不然snaxd的id需要就对不上
function accept.dispatch_proto(proto_name, body, fd)
    show_proto("rec", proto_name, body)
	local func = LoginProto[proto_name]
	if func then
		local ok, err = pcall(func, body, fd)
		if not ok then
			skynet.error("call function fail:", proto_name, Tbtostr(body), err)
		end
	else
		skynet.error("proto function not found:", proto_name, Tbtostr(body))
	end
end

function accept.socket_connect(fd, sid, addr)
    D("socket_connect", fd, sid, addr)
    Update_connect(fd)
end

-- 从数据库加载所有帐户信息
function accept.load_all_account()
	-- local limit_begin = 0
	-- local per_cnt = 2000
	-- while true do
	-- 	local res = Snx.call(".dbmgr", "query_db_data", "t_account", {}, limit_begin, per_cnt)
	-- 	limit_begin = limit_begin + per_cnt
	-- 	assert(res, "load_all_account fail!")
	-- 	if #res <= 0 then
	-- 		init_flag = true
	-- 		break
	-- 	end
	-- 	for _, data in pairs(res) do
	-- 		account_list[data.id] = data
	-- 		name_list[data.name] = data
	-- 		if data.binding_time and data.binding_time > 0 and data.phone_number and data.binding_time ~= "" then
	-- 			phone_list[data.phone_number] = data
	-- 		end
	-- 	end
	-- end
end