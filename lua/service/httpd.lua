local skynet = require "skynet"
local socket = require "skynet.socket"
local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"
local urllib = require "http.url"
local table = table
local string = string

local function response(id, ...)
	local ok, err = httpd.write_response(sockethelper.writefunc(id), ...)
	if not ok then
		-- if err == sockethelper.socket_error , that means socket closed.
		skynet.error(string.format("fd = %d, %s", id, err))
	end
end

skynet.start(function()
    -- 监听一个 web 端口
    local id = socket.listen("0.0.0.0", 8001)
    skynet.error("httpd listen", "0.0.0.0", 8001)
    socket.start(id , function(id, addr)
        socket.start(id)
        -- 一般的业务不需要处理大量上行数据，为了防止攻击，做了一个 8K 限制。这个限制可以去掉。
        local code, url, method, header, body = httpd.read_request(sockethelper.readfunc(id), 8192)
        if code then
            if code ~= 200 then  -- 如果协议解析有问题，就回应一个错误码 code 。
                response(id, code)
            else
                -- 这是一个示范的回应过程，你可以根据你的实际需要，解析 url, method 和 header 做出回应。
                local tmp = {}
                if header.host then
                    table.insert(tmp, string.format("host: %s", header.host))
                end
                local path, query = urllib.parse(url)
                table.insert(tmp, string.format("path: %s", path))
                if query then
                    local q = urllib.parse_query(query)
                    for k, v in pairs(q) do
                        table.insert(tmp, string.format("query: %s= %s", k,v))
                    end
                end
                response(id, code, table.concat(tmp,"\n"))
            end
        else
            -- 如果抛出的异常是 sockethelper.socket_error 表示是客户端网络断开了。
            if url == sockethelper.socket_error then
                skynet.error("socket closed")
            else
                skynet.error(url)
            end
        end
        socket.close(id)
    end)
end)