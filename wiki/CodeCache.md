skynet 修改了 Lua 的官方实现（可选），加入了一个新特性，可以让多个 Lua VM 共享相同的函数原型[1]。当在同一个 skynet 进程中开启了大量 lua VM 时，这个特性可以节省不少内存，且提高了 VM 启动速度。

这个特性的使用，对一般用户来说是透明的。它改写了 lua 的辅助 API `luaL_loadfilex` ，所有直接或间接调用这个 api 都会受其影响。比如：loadfile 、require 等。它以文件名做 key ，一旦检索到之前有加载过相同文件名的 lua 文件，则从内存中找到之前的函数原型替代。注：Lua 函数是由函数原型以及 0 或多个 upvalue 绑定而成。

loadstring 不受其影响。所以，如果你需要多次加载一份 lua 文件，可以使用 io.open 打开文件，并使用 load 加载。

代码缓存采用只增加不删除的策略，也就是说，一旦你加载过一份脚本，那么到进程结束前，它占据的内存永远不会释放（也不会被加载多次）。在大多数情况下，这不会有问题。

skynet 留出了接口清理缓存，以做一些调试工作。接口模块叫做 skynet.codecache 。

```lua
local cache = require "skynet.codecache"
cache.clear()
```

这样就可以清理掉代码缓存。这个 api 是线程安全的，且老版本的数据依旧在内存中（可能被引用）。但需注意，单纯靠清理缓存的方式做热更新的方案是不完备的。这个完备性和是否引入这个特性无关。因为当你的系统在加载一批 lua 脚本时，单靠源文件的更新，无法保证这批脚本加载的原子性。（有部分是旧版本的，有部分是新版本的）

注意，codecache.clear() 仅仅只是创建一个新的 cache （ api 名字容易引起误会），而不释放内存。所以不要频繁调用。如果你需要你加载文件不受 cache 影响，正确的方式是自己读出代码文本，并用 loadstring 方式加载；而不是在加载前调用 codecache.clear 。

```lua
cache.mode(mode)
```

这个 API 可以修改 codecache 在当前服务中的工作模式。mode 可以是 "ON" "OFF" "EXIST" ，默认的 mode 为 "ON" 。

* 当 mode 为 "ON" 的时候，当前服务 cache 一切加载 lua 代码文件的行为。
* 当 mode 为 "OFF" 的时候，当前服务关闭任何重复利用 lua 代码文件的行为，即使在别的服务中曾经加载过同名文件。
* 当 mode 为 "EXIST" 的时候，当前服务在加载曾经在其它服务或自己的服务加载过同名文件时，复用之前的拷贝。但对新加载的文件则不进行 cache 。注：通常可以让 skynet 本身被 cache 。

当 api 参数为空时，返回当前的 mode 。

注意：由于默认模式是打开状态，所以你第一次调用 cache.mode 的所在文件一定是被 cache 的。

[1]: http://blog.codingnow.com/2014/03/lua_shared_proto.html
