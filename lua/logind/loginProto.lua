LoginProto = LoginProto or {}


function LoginProto:cs_login_create(fd)

end

function LoginProto:cs_login_verify(fd)
	local account = create_tourist()
	local obj = get_server_obj("agentmgr")
	local agent_handle = obj.req.launcher_agent(account.account_id)
	user_online[account.account_id] = agent_handle
	Socket_fd[account.account_id] = fd
	
	local cfg = Getcfg("system.harbor")[1]
	send_client_proto(fd, "sc_login_vistor_info", {name = account.name, passwd = account.passwd})
	send_client_proto(fd, "sc_login_server_info", {account_id = account.account_id, login_key = account.login_key, domain = cfg.game_ip, port = cfg.game_port})
end

function LoginProto:cs_login_server_list(fd)

end