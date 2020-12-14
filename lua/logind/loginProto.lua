local snax = require "snax"
LoginProto = LoginProto or {}

function LoginProto:cs_login_send_smscode(fd)
	-- local cfg = GetCfg("sms_tpl")[self.sms_type]
    -- if not cfg then
    --     return false, "LOGIN_SMS_TPL_ERR", "短信模板错误"
    -- end
    -- local code = Gen_sms_code(fd, self.sms_type)
    -- local content = string.format(cfg.content, code)
    -- local body = {Source = "GoldMine", Phone = self.phone_number, VerifyCode = code, Content = content}
    -- local ret, code, msg = call_web("send_sms", {}, body)
    -- if not ret then
    --     return false, code, msg
    -- end
    -- if ret.data and not ret.data.success then
    --     return false, "PLAYER_SMS_SEND_FAIL", ret.data.msg
    -- end
    return true
end

function LoginProto:cs_login_get_smscode(fd)
	send_client_proto(fd, "sc_login_get_smscode", {sms_type = self.sms_type, sms_code = Get_smscode(fd, self.sms_type)})
end

function LoginProto:cs_login_create(fd)
	local user, passwd = self.name, self.passwd
	if self.type == AccRegType.Phone then
		local ok, code, msg = Check_smscode(fd, self.sms_type, self.sms_code)
		if not ok then
			return false, code, msg
		end
		passwd = string.format("%06d", math.random(100000, 999999))
	end
	local ok, data, msg = Register_account(user, passwd, self.type)
	if not ok then
		return false, data, msg
	end

	-- data.login_guid = gen_guid("login", data.id) -- 为每一次登陆生成唯一id，方便数据跟踪

	send_client_proto(fd, "sc_login_auth_info", {user = user, auth_code = data.auth_code})

	local agentmgr = snax.bind(Get_service_handle("agentmgr"), "agentmgr")
	local server = agentmgr.req.get_login_server(data.id)
	local login_key = Gen_login_key()
	agentmgr.post.update_key(data.id, login_key, Self_handle)

	local login_info = { 
		account_id = data.id,
		login_key = login_key,
		domain = server.addr,
		port = server.port,
	}
	send_client_proto(fd, "sc_login_server_info", login_info)
	Update_connect(fd, false, true)
end

function LoginProto:cs_login_check_account(fd)
	local data = Name_list[self.name] or Phone_list[self.name]
	if not data then
		return false, "LOGIN_ACC_NOT_EXISTS", "帐号不存在"
	end
	return true
end

function LoginProto:cs_login_verify(fd)
	local user, passwd = self.user, self.passwd
	-- 游客登陆验证时，创建游客账号
	if self.type == LoginVerifyType.Tourist then
		local ok, data, msg = Create_tourist_account()
		if not ok then
			return false, data, msg
		end
		local ok1, acc, msg = Register_account(data.user, data.passwd, self.type)
		if not ok1 then
			return false, acc, msg
		end
		user = acc.user
		passwd = acc.passwd
		send_client_proto(fd, "sc_login_vistor_info", {user = user, passwd = data.passwd})
	end

	local data = Name_list[user] or Phone_list[user]
	if not data then
		return false, "LOGIN_ACC_NOT_EXISTS", "帐号不存在"
	end

	-- 登陆验证
	if self.type == LoginVerifyType.Phone then
		local ok, code, msg = Check_smscode(fd, self.sms_type, self.sms_code)
		if not ok then
			return false, code, msg
		end
	elseif self.type == LoginVerifyType.Code then
		if data.auth_code ~= self.auth_code then
			return false, "LOGIN_VERIFY_PASS_FAIL", "密码错误"
		end
	elseif data.passwd ~= passwd then
		return false, "LOGIN_VERIFY_PASS_FAIL", "密码错误"
	end

	-- 非游客登陆时，更新授权码
	if self.type ~= 0 then
		Refresh_auth_code(data)
	end
	-- data.login_guid = gen_guid("login", data.id) -- 为每一次登陆生成唯一id，方便数据跟踪

	send_client_proto(fd, "sc_login_auth_info", {user = user, auth_code = data.auth_code})

	local agentmgr = snax.bind(Get_service_handle("agentmgr"), "agentmgr")
	local server = agentmgr.req.get_login_server(data.id)
	local login_key = Gen_login_key()
	agentmgr.post.update_key(data.id, login_key, Self_handle)

	local login_info = { 
		account_id = data.id,
		login_key = login_key,
		domain = server.addr,
		port = server.port,
	}
	send_client_proto(fd, "sc_login_server_info", login_info)
	Update_connect(fd, false, true)
end

function LoginProto:cs_login_check_sms(fd)
	local ok, code, msg = Check_smscode(fd, self.sms_type, self.sms_code)
	if not ok then
		return false, code, msg
	end
	return true
end

function LoginProto:cs_login_reset_passwd(fd)
	local name = self.name
	if not name then
		return false, "LOGIN_ACC_NOT_EXISTS", "帐号不存在"
	end
	local data = name_list[name] or phone_list[name]
	if not data then
		return false, "LOGIN_ACC_NOT_EXISTS", "帐号不存在"
	end
	local ok, code, msg = check_smscode(fd, self.sms_type, self.sms_code)
	if not ok then
		return false, code, msg
	end

	local ok2, code2, msg2 = check_pass(self.new_passwd)
	if not ok2 then
		return false, code2, msg2
	end
	data.passwd = misc.md5(self.new_passwd):upper(),
	update_account(data)
	Snx.post(".dbmgr", "save_data", "t_account", data)
	return true
end

function LoginProto:cs_ping(fd)
    send_client_proto(fd, "sc_ping", {client_time = self.client_time or 0, server_time = snax.time()})
    if Conn_list[fd] and Conn_list[fd].login then
    	return
    end
    Update_connect(fd, false, false)
end