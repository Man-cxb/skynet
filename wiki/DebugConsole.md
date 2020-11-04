skynet 自带了一个调试控制台服务。你需要在你的启动脚本里启动它。
```lua
skynet.newservice("debug_console",8000)
```
这里的示例是监听 8000 端口，你可以修改成别的端口。

出于安全考虑，调试控制台只能监听本地地址 127.0.0.1 ，所以如果需要远程使用，需要先登录到本机，然后再连接。

可以用 telnet 或 nc 登录调试控制台。启动后会显示
```
Welcome to skynet console
```
表示连接成功。

注：由于 skynet 使用自己的 IO 库，所以很难把 libreadline 接入（不能在 readline 的 hook 中 yield）。如果你希望在控制台中使用 readline 的 history 等特性，可以自己使用 rlwrap 。

这时，你可以输入调试指令，输入 help 可以列出目前支持的所有指令。这份文档可能落后于实际版本，所以应以 help 列出的指令为准。

命令的一般格式是 命令 地址 ，有些命令不带地址，会针对所有的服务。当输入地址时，可以使用 :01000001 这样的格式指代一个服务地址：由冒号开头的 8 位 16 进制数字，也可以省略前面两个数字的 harbor id 以及接下来的连续 0 ，比如 :01000001 可以简写为 1 。所有活动的服务可以输入 list 列出。

常用的针对所有 lua 服务的指令有：

* list 列出所有服务，以及启动服务的命令参数。
* gc 强制让所有 lua 服务都执行一次垃圾回收，并报告回收后的内存。
* mem 让所有 lua 服务汇报自己占用的内存。（注：它只能获取 lua 服务的 lua vm 内存占用情况，如果需要 C 模块中内存使用报告，请参考 [[MemoryHook]] 。
* stat 列出所有 lua 服务的消息队列长度，以及被挂起的请求数量，处理的消息总数。如果在 [[Config]] 里设置 profile 为 true ，还会报告服务使用的 cpu 时间。
* service 列出所有的唯一 lua 服务。并显示出请求还不存在的服务被挂起的请求。
* netstat 列出网络连接的概况。

注意，由于这些指令是挨个向每个服务发送消息并等待回应，所以当某个 lua 服务过载时，可能需要等待很长时间才有返回。

针对单个 lua 服务的指令有：

* start service_name 用 skynet.newservice 启动一个新的 lua 服务。
* snax service_name 用 snax.newservice 启动一个新的 snax 服务。
* exit address 让一个 lua 服务退出。
* kill address 强制中止一个 lua 服务。
* info address 让一个 lua 服务汇报自己的内部信息，参见 [[Profile]] 。
* signal address sig 向服务发送一个信号，sig 默认为 0 。当一个服务陷入死循环时，默认信号会打断正在执行的 lua 字节码，并抛出 error 显示调用栈。这是针对 endless loop 的 log 的有效调试方法。注：这里的信号并非系统信号。
* task address 显示一个服务中所有被挂起的请求的调用栈。
* debug address 针对一个 lua 服务启动内置的单步调试器。http://blog.codingnow.com/2015/02/skynet_debugger.html
* logon/logoff address 记录一个服务所有的输入消息到文件。需要在 [[Config]] 里配置 logpath 。
* inject address script 将 script 名字对应的脚本插入到指定服务中运行（通常可用于热更新补丁）。
* call address 调用一个服务的lua类型接口，格式为: call address "foo", arg1, ... 注意接口名和string型参数必须加引号,且以逗号隔开, address目前支持服务名方式。




