skynet 提供了一个通用的登陆服务器模版 snax.loginserver 。

## 架构

先做如下定义：

* 登陆服务器 L 。**这即是本篇介绍的 LoginServer**
* 登陆点若干 G1, G2, G3 ...
* 认证平台 A
* 用户 C

当 C 试图登陆 G1 时，它进行下列流程：

1. C 向 A 发起一次认证请求 (A 通常是第三方认证平台)，获得一个 token 。这个 token 里通常包含有用户名称以及用于校验用户合法性的其它信息。
2. C 将他希望登陆的登陆点 G1 (或其它登陆点，可由系统设计的负载均衡器来选择）以及 step 1 获得的 token 一起发送给 L 。
3. C 和 L 交换后续通讯用的密钥 secret ，并立刻验证。
4. L 校验登陆点是否存在，以及 token 的合法性（此处有可能需要 L 和 A 做一次确认）。
5. （可选步骤）L 检查 C 是否已经登陆，如果已经登陆，向它所在的登陆点（可以是一个，也可以是多个）发送信号，等待登陆点确认。通常这个步骤可以将已登陆的用户登出。
6. L 向 G1 发送用户 C 将登陆的请求，并同时发送 secret 。
7. G1 收到 step 6 的请求后，进行 C 登陆的准备工作（通常是加载数据等），记录 secret ，并由 G1 分配一个 subid 返回给 L。通常 subid 对于一个 userid 是唯一不重复的。
8. L 将subid 发送给 C 。subid 多用于多重登陆（允许同一个账号同时登陆多次），一个 userid 和一个 subid 一起才是一次登陆的 username 。而每个 username 都对应有唯一的 secret 。
8. C 得到 L 的确认后，断开和 L 的连接。然后连接 G1 ，并利用 username 和 secret 进行握手。

以上流程，任何一个步骤失败，都会中断登陆流程，用户 C 会收到错误码。

登陆点会按照业务的需要，在确认用户登出后，通知 L 。登出可能发生在连接断开（基于长连接的应用）、用户主动退出、一定时间内没有收到用户消息等。

对于同一个用户登陆时，该用户已经在系统中时，通常有三种应对策略：

1. 允许同时登陆。由于每次登陆的 subid/登陆点 不同，所以可以区分同一个账号下的不同实体。
2. 不允许同时登陆，当新的登陆请求到达并验证后，命令上一次登陆的实体登出。登出完成后，接受新的登陆。
3. 如果一个用户在系统中，禁止该用户再次进入。

LoginServer 并不干涉你用哪种策略，可以自由定制。但对于后两种策略，给于一定的支持，简化业务逻辑实现的复杂性。

## 使用

lualib/snax/loginserver.lua 是一个辅助库，帮助你实现登陆模块。

```lua
local login = require "snax.loginserver"
local server = {
	host = "127.0.0.1",
	port = 8001,
	multilogin = false,	-- disallow multilogin
	name = "login_master",
     -- config, etc
}

login(server)
```
取到 snax.loginserver 模块后，构造配置表，然后调用它就可以启动一个登陆服务器。

* host 是监听地址，通常是 "0.0.0.0" 。
* port 是监听端口。
* name 是一个内部使用的名字，不要和 skynet 其它服务重名。在上面的例子，登陆服务器会注册为 `.login_master` 这个名字。
* multilogin 是一个 boolean ，默认是 false 。关闭后，当一个用户正在走登陆流程时，禁止同一用户名进行登陆。如果你希望用户可以同时登陆，可以打开这个开关，但需要自己处理好潜在的并行的状态管理问题。

同时，你还需要注册一系列业务相关的方法。

```lua
function server.auth_handler(token)
```
你需要实现这个方法，对一个客户端发送过来的 token （step 2）做验证。如果验证不能通过，可以通过 error 抛出异常。如果验证通过，需要返回用户希望进入的登陆点（登陆点可以是包含在 token 内由用户自行决定,也可以在这里实现一个负载均衡器来选择）；以及用户名。

在这个方法内做远程调用（skynet.call）是安全的。

```lua
function server.login_handler(server, uid, secret)
```
你需要实现这个方法，处理当用户已经验证通过后，该如何通知具体的登陆点（server ）。框架会交给你用户名（uid）和已经安全交换到的通讯密钥。你需要把它们交给登陆点，并得到确认（等待登陆点准备好后）才可以返回。

如果关闭了 multilogin ，那么对于同一个 uid ，框架不会同时调用多次 `login_handler` 。在执行这个函数的过程中，如果用户发起了新的请求，他将直接收到拒绝的返回码。

如果打开 multilogin ，那么 `login_handler` 有可能并行执行。由于这个函数在实现时，通常需要调用 skynet.call 让出控制权。所以请小心维护状态。例如，你希望在这个函数中将上一个实例踢下线。那么你需要在踢人操作后再次确认用户是否真的不在线（很有可能另一个登陆的竞争者恰好在此时又登陆成功了）。

一般你还希望这个登陆服务器可以接受一些 skynet 内部控制指令，比如让登陆点可以通知玩家下线了，动态注册新的登陆点等等操作。所以你可以定义这个函数来接收 skynet 内部传递过来的 lua 协议的消息：

```lua
function server.command_handler(command, ...)
```
command 是第一个参数，通常约定为指令类型。这个函数的返回值会作为回应返回给请求方。

你可以把登陆服务器做为一个单独的 skynet 进程使用，并用 cluster 模块和其它 skynet 进程做集群间通讯；也可以启动在一个 skynet 节点中。在附带的例子 examples/login/logind.lua 中，使用的后一种形式。

你可以参考 examples/login/client.lua 来实现配套的客户端。

## wire protocol

登陆服务器和客户端的交互协议基于文本。每个请求和回应包，都以换行符 \n 分割。用户名、服务器名、token 等，为了保证可以正确在文本协议中传输，全部经过了 base64 编码。所以这些业务相关的串可以包含任何字符。

下列通讯流程的协议描述中，S2C 表示这是一个服务器向客户端发送的包；C2S 表示是一个客户端向服务器发送的包。

1. S2C : base64(8bytes random challenge) 这是一个 8 字节长的随机串，用于后序的握手验证。
2. C2S : base64(8bytes handshake client key) 这是一个 8 字节的由客户端发送过来，用于交换 secret 的 key 。
3. Server: Gen a 8bytes handshake server key 生成一个用户交换 secret 的 key 。
4. S2C : base64(DH-Exchange(server key)) 利用 DH 密钥交换算法，发送交换过的 server key 。
5. Server/Client secret := DH-Secret(client key/server key) 服务器和客户端都可以计算出同一个 8 字节的 secret 。
6. C2S : base64(HMAC(challenge, secret)) 回应服务器第一步握手的挑战码，确认握手正常。
7. C2S : DES(secret, base64(token)) 使用 DES 算法，以 secret 做 key 加密传输 token 串。
8. Server : call auth_handler(token) -> server, uid (A user defined method)
9. Server : call login_handler(server, uid, secret) -> subid (A user defined method)
10. S2C : 200 base64(subid) 发送确认信息 200 subid ，或发送错误码。

### 错误码
* 400 Bad Request . 握手失败
* 401 Unauthorized . 自定义的 `auth_handler` 不认可 token 
* 403 Forbidden . 自定义的 `login_handler` 执行失败
* 406 Not Acceptable . 该用户已经在登陆中。（只发生在 multilogin 关闭时）
























