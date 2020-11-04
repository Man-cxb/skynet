获取源代码 Get Source Code
=====
推荐使用 git 。

git is recommended here.

```
git clone https://github.com/cloudwu/skynet.git
```

或者下载最新的 release 包[1]，自行解开。但下载的源代码包中并不包含 jemalloc[2] ，请自行下载放在 3rd/jemalloc 目录下。

Or download the latest release package [1] and decompress it. However, source code doesn't include  jemalloc [2], you'll need to download it manually and put it in 3rd/jemalloc directory.

编译工具 Compiling Tool
======

skynet 的开发环境是 Ubuntu Linux 。但同时也应该能在其它 Linux 平台编译运行。它同时支持 MacOSX 及 FreeBSD ，没有经过严格测试、不保证没有问题。

Skynet is developed in Ubuntu Linux environment, it should also work in other Linux environments. It supports both MacOSX and FreeBSD, though it's not tested in these environments.

mac osx
```
brew install readline autoconf
```
centos
```
yum install -y readline-devel autoconf
```
ubuntu
```
apt-get install readline-dev autoconf
apt-get install libreadline-dev autoconf  (for ubuntu 16.04)
```

skynet 所有代码以及引用的第三方库都可以被支持 C99 的编译器编译。所以你需要先安装 gcc 4.4及以上版本。（Clang 应该也没有问题）。它还需要 GNU Make 以运行 Makefile 脚本。

All the source code of Skynet and third-party libs can be compiled in C99 mode. So you'll need to install GCC 4.4 or above (Clang should work as well) first. And GNU Make is also required in order to run Makefile script.

About jemalloc[2] 和 malloc hook
----

skynet 对 malloc api 做了 hook ，用来统计 skynet 内部服务分别占用了多少内存。这个 hook 是用实现 malloc 等同名 api 以重载 libc 对应 api 实现的。同时，为了内存管理的高效，默认链接了 jemalloc 。

Skynet has a hook for malloc API, it's used for metrics of memory usage for Internal Services. The hook implemented the API functions like malloc etc in order to overload the corresponding API of libc. Also, Skynet links jemalloc by default for efficient memory management.

而在 MacOSX 下，这种 hook 手段是不成立的。需要额外编写 memory zone ，这将引入更多复杂的问题，所以直接在编译时就关闭了 jemalloc 。如果你在 linux 下也不想使用 jemalloc 以及 skynet 自带的服务内存统计模块，那么可以参考 platform.mk 中针对 macosx 的写法关闭它们。

In MacOS, it's not allowed to use this kind of hook. It requires extra memory zone, which may cause over complexity, so we turned of jemalloc in compiling. If you don't want to use jemalloc and skynet memory metrics module in Linux, you can also turn it off as we did in platform.mk for MacOS.

注意：编译 jemalloc 需要先安装 autoconf 工具。

Notice: autoconf is required to compile jemalloc.

如果你是通过 git clone 得到的 skynet 的源代码，那么你应该已经安装了 git 。Makefile 里编写的规则会自动下载 jemalloc 的代码；如果你是直接下载的 skynet 源码包，就有可能无法自动工作。那么你可能需要手工把 jemalloc 下载到 3rd 目录下，或在 skynet 源码服务下运行 git init 将其初始化为一个 git 仓库，让 git submodule 可以正常工作。

If you use git clone to get Skynet source code, I assume you have installed git already. Makefile defines the rules to download jemalloc code; if you build it from Skynet source code it may not work. You'll need to manually download it and put it in 3rd directory, or run git init to make it a git repository from Skynet in source code so that git submodule can work.

编译 Compiling
====
```
cd skynet
make linux
```
通常可以成功。

It should work in most cases.

如果你不是 Linux 系统，那么可以在 make 后尝试 macosx 和 freebsd 两个选项。由于 freeBSD 默认的 make 不是 gnu make ，请用 gmake 。

If it's not in a Linux environment, try using make with parameters: macOS and FreeBSD. Because FreeBSD uses make instead of gnu make by default, so please use gmake.

通常，skynet 会作为一个框架在你的项目中使用，推荐你把 skynet 作为一个 submodule 引入。你可以在你的 Makefile 文件中调用 GNU Make 编译它。你可以把平台设置在 PLAT 这个环境变量中。

In general, Skynet is used as a framework in your project, it's recommended to import Skynet as a submodule. You can compile it using GNU Make in your Makefile. You can set your platform in PLAT.

默认状态下，skynet 执行文件会被编译输出到 skynet 目录下。你很可能希望自定义输出位置，通过修改 `SKYNET_BUILD_PATH` 变量可以改变它。

The executive output path of Skynet is in Skynet directory by default, if you want to customize the output path of Skynet exe file, you can change `SKYNET_BUILD_PATH`  .

如果你编译 jemalloc 有困难，可以考虑这样设置宏来避免编译它：

If you are unable to compile jemalloc, try defining these macros options to avoid compiling it:

```
make linux MALLOC_STATICLIB= SKYNET_DEFINES=-DNOUSE_JEMALLOC
```

About lua
====

skynet 自带了一份 Lua 5.3 的源代码。并在官方版本的基础上做了一点小修改。

Skynet has a copy of Lua 5.3. It'a revised version of the official Lua.

这是因为，skynet 框架有可能启动大量的 lua 虚拟机。而大量的 Lua 虚拟机中运行的是相同的代码。skynet 带的修改版 Lua 实现会尽量共享相同的 Lua 函数原型以节约内存、提高初始化 Lua 虚拟机的速度。其副作用是，通过 loadfile `luaL_loadfile` 等加载过的 lua 文件，不会再次从文件系统加载（但你可以通过 code cache 接口重置）。

The reason is that Skynet may run tons of Lua VMs. And these Lua VMs are running the same source code. The revised Lua version Skynet makes use of Lua function prototype in order to save more memory and speed up the init of Lua VMs. The defect of this is, running loadfie luaL_loadfilemay not force a reload from the OS file system (though you can use code cache API to reset it).

另外，为了方便调试，skynet 给 lua vm 打了个补丁，可以在 lua 代码陷入死循环后，也可以从外部使其跳出[3]。

Besides, for debugging convenience, Skynet has patched Lua VM as well, which makes it possible to be terminated from outside when Lua has an infinite loop [3] .

如果你不喜欢这个设计，也可以链接自己的 Lua 库。方法是改写 Makefile 中的 `LUA_LIB` 以及 `LUA_INC` 变量。

If you don't like this design, you can link your own Lua lib. To do this, change `LUA_LIB`  and `LUA_INC` in Makefile.

注：skynet 需要 Lua 5.3 版，不支持 Lua 5.1 以及 LuaJIT 。

Note: Skynet requires Lua 5.3, and it doesn't support Lua 5.1 and LuaJIT.

如果你在编译 lua 的过程中遇到问题，请仔细阅读：http://www.lua.org/manual/5.3/readme.html

If you have problems with Lua compiling, please read http://www.lua.org/manual/5.3/readme.html 

Windows
=====
skynet 没有支持 Windows 平台的计划。但社区中有 Mr.j 同学成功移植到 Windows 下[4]。

Skynet doesn't have a plan to support Windows platforms. But developer from Skynet community has successfully migrated it to Windows [4].

[sanikoyes](https://github.com/sanikoyes) 加入了windows平台的skynet支持，使用vs2013编译，支持skynet最新版，仅供学习/日常开发使用，由于性能方面的问题（event-select），请勿在生产环境使用windows版，地址在： https://github.com/sanikoyes/skynet/tree/vs2013

@sanikoyes added support of Skynet Windows by using VS2013 and latest code from Skynet's main branch, it's just for practicing or learning purposes. Because of the performance problem in event-select, it's not recommended to use it in a production environment.

[dpull](https://github.com/dpull) 加入了使用 [mingw编译的windows版](https://github.com/dpull/skynet-mingw/)，主要供项目内策划修改配置表后自测用。

@dpull added tutorial of How to Use MinGW to Compile Skynet Windows Version, it's mainly for producers to test config file changes.

如有这方面的需要，请自行联系 [[Community]] 。

Please contact [[Community]] if needed.

[1]: https://github.com/cloudwu/skynet/releases
[2]: https://github.com/jemalloc/jemalloc
[3]: http://blog.codingnow.com/2015/03/skynet_signal.html
[4]: https://github.com/peimin/skynet-windows
