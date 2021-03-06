require "skynet.manager"
require "config"
local skynet = require "skynet"
local snax = require "snax"
local datacenter = require "skynet.datacenter"
local md5 = require "md5"

local string = string
local assert = assert
-- local math_random = math.random

Login_gate = Login_gate
Server_id = Server_id
Self_handle = Self_handle
Raw_acc_id = Raw_acc_id or 0

Name_list = Name_list or {}
Account_list = Account_list or {}
Phone_list = Phone_list or {}

local handle_list = {}
function Get_service_handle(name)
	if handle_list[name] then
		return handle_list[name]
	end
	local key = name .. "_handle"
	local handle = datacenter.get(key)
	assert(handle, "get_service_handle error, key " .. key)
	handle_list[name] = handle
	return handle
end

local not_show_proto = {
}
function show_proto(title, name, proto)
	if not_show_proto[name] then
        return
	end
	-- local Debug = GetCfg("system.debug")
    -- local DbgMod = Debug.DbgMod
    -- local open = DbgMod.proto
    -- if open == nil then
    --     open = DbgMod.all
    -- end
    -- if not open then
    --     return
	-- end
	skynet.error(title .. ":", name, Tbtostr(proto))
end

function send_client_proto(fd, name, body)
	show_proto("send", name, body)
	skynet.send(Login_gate, "lua", "send_proto", fd, name, body)
end

function send_err(fd, name, code, msg, session)
	local cfg = GetCfg("errno")
	-- local cfg = err_cfg[code] or {}
	skynet.send(Login_gate, "lua", "send_proto", fd, "sc_err", {proto_name = name, code = cfg.id or 0, content = msg, session = session})
end

local sms_list = {}
function Gen_sms_code(fd, typ)
	local code = string.format("%06d", math.random(100000, 999999))
	sms_list[fd] = { code = code, time = snax.time(), typ = typ}
	return code
end

local sms_timeout = 60
function Check_smscode(fd, typ, code)
	local data = sms_list[fd]
	if not data then
		return false, "LOGIN_SMS_INVALID", "请重新获取验证码"
	end
	if data.typ ~= typ then
		return false, "LOGIN_SMS_INVALID", "请重新获取验证码"
	end
	if snax.time() >= data.time + sms_timeout then
		sms_list[fd] = nil
		return false, "LOGIN_SMS_TIMEOUT", "验证码超时"
	end
	if data.code ~= code then
		return false, "LOGIN_SMS_NOT_MATCH", "验证码错误"
	end
	return true
end

function Change_passwd(new_pass, data)
	if not new_pass or #new_pass < 8 or #new_pass > 20 then
		return false, "LOGIN_PASSWD_ERR", "密码为8位以上字母或数字"
	end
	if string.match(new_pass, "%W") then
		return false, "LOGIN_PASSWD_ERR", "密码为8位以上字母或数字"
	end
	data.passwd = md5.sumhexa(new_pass)
	update_account(data)
	skynet.post(".dbmgr", "lua", "save_data", "t_account", data)
	return true
end

function Get_smscode(fd, typ)
	local data = sms_list[fd]
	if not data then
		return ""
	end
	if snax.time() >= data.time + sms_timeout then
		return ""
	end
	if data.typ ~= typ then
		return ""
	end
	return data.code
end

local function gen_auth_code()
	local list, tb = {
		'1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l',
		'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', 'A', 'B', 'C', 'D', 'E', 'F', 'G',
		'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'
	}, {}
	for i = 1, 32 do
		table.insert(tb, list[math.random(1, #list)])
	end
	return md5.sumhexa(table.concat(tb))
end

function Create_tourist_account()
	local user, passwd
	local cfg = snax.get_harbar_cfg()
	local prefix = tostring(cfg.server_id) .. tostring(snax.time()):sub(3)
	for i = 1, 999 do
		user = prefix .. string.format("%03d", i)
		if not Name_list[user] then
			passwd = string.format("%06d", math.random(100000, 999999))
			return true, {user = user, passwd = passwd}
		end
	end
	if not passwd then
		return false, "LOGIN_CREATE_VISTOR_FAIL", "访客帐号创建失败"
	end
end

local function get_raw_acc_id()
	Raw_acc_id = Raw_acc_id + 1
	skynet.send(".dbmgr", "lua", "save_data", "t_global", {key = "account_id_" .. Server_id, data = tostring(Raw_acc_id)})
	return Raw_acc_id
end

function update_account(data)
	Account_list[data.id] = data
	Name_list[data.user] = data
	if data.binding_time and data.binding_time > 0 and data.phone_number and data.binding_time ~= "" then
        Phone_list[data.phone_number] = data
    end
end

function Register_account(user, pass, typ)
	if Name_list[user] then
		return false, "LOGIN_NAME_USED", "名字已被使用"
	end

	-- todo 敏感词检查
	-- if is_contain_sensword(name) then
	-- 	return false, "LOGIN_NAME_INVALID", "名字不合法"
	-- end

	if not pass then
		return false, "LOGIN_CREATE_NO_PASS", "请输入密码"
	end

	local new_acc_id = Generate_unique_pid(Server_id, get_raw_acc_id())
	local now = snax.time()
	local data = {
		id = new_acc_id,
		user = user,
		passwd = md5.sumhexa(pass),
		create_time = now,
		op_time = now,
		reg_type = typ,
		phone_binding = 0,
		binding_time = 0,
		auth_code = gen_auth_code(),
	}

	if typ == AccRegType.Phone then
		data.phone_number = user
	end

	-- 数据同步入库
	if not skynet.call(".dbmgr", "lua", "sync_save_data", "t_account", data, true) then
		return false, "LOGIN_DB_ERR", "数据库异常"
	end

	update_account(data)
	
	return true, data
end

function Refresh_auth_code(data)
	data.auth_code = gen_auth_code()
	update_account(data)
	skynet.send(".dbmgr", "lua", "save_data", "t_account", data)
end

local key_rand_index
local last_gen_time
function Gen_login_key()
    local time = snax.time()
    if time == last_gen_time then
        key_rand_index = key_rand_index and key_rand_index + 1 or math.random(1, 0xffff)
    else
        key_rand_index = math.random(1, 0xffff)
    end
    last_gen_time = time
    local str = time .. Server_id .. key_rand_index
    return md5.sumhexa(str)
end

function close_socket(fd, reason)
	skynet.error("close socket ", fd, reason)
	skynet.timeout(100, function() skynet.send(Login_gate, "lua", "close_fd", fd, reason) end)
end

function hotfix(...)
	skynet.error("login hotfix ", ...)
end

function on_timer()

end

function init()
	require "loginProto"

	-- 注册协议
	register_proto()

	skynet.register(".logind")

	-- 启动网关服务
	local cfg = snax.get_harbar_cfg()
	assert(cfg, "miss harbar cfg")
	Login_gate = skynet.newservice("gated", "login", skynet.self())
	skynet.call(Login_gate, "lua", "open" , {
		port = cfg.login_port,
		maxclient = cfg.max_login_conn
	})

	Server_id = cfg.server_id
	math.randomseed(snax.time())
	
	local res = skynet.call(".dbmgr", "lua", "query_db_data", "t_global", {key = "account_id_" .. Server_id})
	assert(res, "table t_global not exists!")
	if #res > 0 then
		Raw_acc_id = tonumber(res[1].data)
	end
	
	local obj = snax.self()
	obj.post.load_all_account()
	Self_handle = obj.handle

	cancel_timeout = interval_timeout(500, "on_timer")
end

function exit(...)
	print ("login server exit:", ...)
	snax.exit(...)
end

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

-- 从数据库加载所有帐户信息
function accept.load_all_account()
	local limit_begin = 0
	local per_cnt = 2000
	while true do
		local res = skynet.call(".dbmgr", "lua", "query_db_data", "t_account", {}, limit_begin, per_cnt)
		limit_begin = limit_begin + per_cnt
		assert(res, "load_all_account fail!")
		if #res <= 0 then
			init_flag = true
			break
		end
		for _, data in pairs(res) do
			Account_list[data.id] = data
			Name_list[data.user] = data
			if data.binding_time and data.binding_time > 0 and data.phone_number and data.binding_time ~= "" then
				Phone_list[data.phone_number] = data
			end
		end
	end
end

function response.get_data(account_id)
    return Account_list[account_id]
end