在这个 fork https://github.com/chfg007/skynet 里，实现了 mysql 的 driver （改自 OpenResty）。

主要文件为 [[lualib/mysql.lua | https://github.com/chfg007/skynet/blob/master/lualib/mysql.lua]]
和 [[3rd/lua-mysqlaux | https://github.com/chfg007/skynet/tree/master/3rd/lua-mysqlaux]]

local status, err = pcall(mysqldb.query,mysqldb,sqlstr) 记得捕获错误，有可能查询的时候链接已经断开。