LoginProto = LoginProto or {}


function LoginProto:cs_login_create(fd)

end

function LoginProto:cs_login_verify(fd)
	local account = create_tourist()
	send_client_proto(fd, "sc_login_vistor_info", {name = account.name, passwd = account.passwd})
	send_client_proto(fd, "sc_login_server_info", {account_id = account.account_id, login_key = account.login_key, domain = "127.0.0.1", port = 8888})
end

function LoginProto:cs_login_server_list(fd)

end