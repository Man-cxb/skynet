 * 编译 lua 时，因为找不到 readline/readline.h 等出错怎么办？

 > 仔细阅读 http://www.lua.org/manual/5.3/readme.html ，然后确保你安装了 readline 的开发库。

 * 编译 jemalloc 时出错怎么办？

 > jemalloc 是用 git submodule 模式引用，安装 git 确保 make 可以自动更新到 jemalloc 仓库。或自行下载 jemalloc 复制到对应目录 3rd/jemalloc 下。且编译 jemalloc 需要安装 autoconf 。如果还嫌麻烦，参考 platform.mk 里 macosx 的写法，定义宏来取消 jemalloc 。

 * 下载的 zip file 或 tar ball 解开后编译不了？

 > github 无法自动打包 submoudle ，所以你需要自行下载缺失的部分。见上一条：编译 jemalloc 时出错怎么办？

 * skynet 有 Windows 版么？

 > 不会有官方的 Windows 版，如果你希望在 Windows 下开发，请安装 Linux 虚拟机环境。非官方 Windows 版可以寻求社区支持，或自己做一个。例如:[skynet-mingw](https://github.com/dpull/skynet-mingw) ,它的主要特点是没有修改skynet的源代码,仅通过修改编译选项支持了windows。 Win10的子系统linux的bash可以编译成功。开启子系统方法自行百度= =。

 * 运行 lua examples/client.lua 出错？

 > 确保你使用的是 Lua 5.3 以上版本。

 > 或者使用 ./3rd/lua/lua examples/client.lua 运行客户端。

 * 在 skynet.lua 中，require "skynet.core" 引用的库为什么找不到对应的代码？

 > 请阅读 Lua 的文档，然后在 C 代码中 grep `luaopen_skynet_core" 。

 * 如何运行 test/ 下的 lua 脚本？

 > test/ 下的 lua 脚本不能使用 lua 解释器直接运行。需要先启动 skynet ，用 skynet 加载它们。如果打开了 console ，这时应该可以在控制台输入一些字符。输入脚本的名字（不带 .lua）即可加载。如果打开了 `debug_console` 可以用  telnet 连接上 127.0.0.1:8000 。然后试着输入 help ，学会怎样加载脚本。

 * freebsd10下make报错Need an operator？

 > 安装gmake，使用gmake编译。

 * skynet 支持 https 吗？
 
 > 默认只支持 http，但是你可以在 Makefile 中打开 `TLS_MODULE=ltls` 就可以加入 https 支持。但需要额外依赖 openssl 库，请自行安装，并正确设置 `TLS_LIB` 和 `TLS_INC`。
