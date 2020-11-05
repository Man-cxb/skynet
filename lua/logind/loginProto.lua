LoginProto = LoginProto or {}

function LoginProto:cs_login_create(fd)

end

function LoginProto:cs_login_verify(fd)
	D("开始登陆验证。。。", fd, V2S(self))
	send_client_proto(fd, "sc_login_vistor_info",{name = "cxd", passwd = "123456"})
end

function LoginProto:cs_login_server_list(fd)

end