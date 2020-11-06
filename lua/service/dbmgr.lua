local skynet = require "skynet"
local mysql = require "skynet.db.mysql"
require "tool"
local strfmt = string.format

DB = DB or {}
Db_title = Db_title or {}

local dbcfg = {
    host = "127.0.0.1",
    port = 33006,
    database = "skynetdb",
    user = "root",
    password = "123456",
    charset = "utf8mb4",
    max_packet_size = 1024 * 1024,
    on_connect = function (db)
        db:query("set charset utf8mb4")
    end
}

local function query_bd(sql)
    D("---query sql-->", sql)
    return DB:query(sql)
end

local function desc_table(name)
    local sql = "desc %s;"
    local res = query_bd(strfmt(sql, name))
    if not res or #res <= 0 then
        return
    end
    local tbl = {}
    for _, data in pairs(res) do
        if data.Type:find("int") or data.Type:find("float") or data.Type:find("double") then
            tbl[data.Field] = "number"
        else
            tbl[data.Field] = "string"
        end
    end
    Db_title[name] = tbl
    return tbl
end

local function get_db_title(name)
    if Db_title[name] then
        return Db_title[name]
    end
    return desc_table(name)
end

local function gen_insert_sql(name, data, is_insert)
    local title = get_db_title(name)
    if not title then
        D("gen_insert_sql fail! " .. name .. " not exists!")
        return
    end
    local field = ""
    local placehold = ""
    local value = {}
    for k, v in pairs(data) do
        if title[k] then
            if field == "" then
                field = field .. "`" .. k .. "`"
            else
                field = field .. ", `" .. k .. "`"
            end
            local str = "%d"
            if title[k] == "string" then
                str = "'%s'"
            end
            local val = v
            if title[k] == "string" and type(v) == "table" then
                val = Tbtostr(v)
            elseif type(v) ~= title[k]  then
                D("gen insert_sql failed! field type error!", name, k, type(v), title[k], Tbtostr(data))
                return
            end

            if placehold == "" then
                placehold = placehold .. str
            else
                placehold = placehold .. "," .. str
            end

            table.insert(value, val)
        end
    end

    local cp = is_insert and "insert" or "replace"
    local sql = cp .. " into `" .. name .. "` (" .. field .. ") values (" .. placehold .. ");"

    if field == "" then
        D("insert sql need fields!", sql)
        return
    end
    return sql, value
end

local cmd = {}
function cmd.query_db_data(name, where, limit_begin, cnt)
    local str = ""
    local args = {}
    local title = get_db_title(name)
    if not title then
        D("query_db_data title is nil!", name)
        return
    end
    for k, v in pairs(where) do
        if title[k] then
            if str == "" then
                str = str .. "`" .. k .. "`" .. " = "
            else
                str = str .. " and `" .. k .. "` = "
            end
            if title[k] == "number" then
                str = str .. "%d"
            else
                str = str .. "'%s'"
            end
            if type(v) ~= title[k]  then
                D("gen query_sql failed! field type error!", name, k, type(v), title[k], V2S(where))
                return
            end
            args[#args + 1] = v
        else 
            D("query_db_data title[k] is nil!", k, name)
        end
    end
    local sql = "select * from `" .. name .. "`"
    if str ~= "" then
        sql = sql .. " where " .. str
    end

    limit_begin = limit_begin or 0
    cnt = cnt or 2000
    sql = sql .. " limit " .. limit_begin .. ", " .. cnt
    return query_bd(strfmt(sql, table.unpack(args)))
end

function cmd.save_data(name, data, is_insert)
    local sql, value = gen_insert_sql(name, data, is_insert)
    if not sql then
        return
    end
    query_bd(strfmt(sql, table.unpack(value)))
end

function cmd.sync_save_data(name, data, is_insert)

end


skynet.start(function()
    skynet.dispatch("lua", function(_, source, command, ...)
		skynet.error("----------db dispatch lua",V2S(command), ...)
		local f = assert(cmd[command])
		local msg, sz = skynet.pack(f(...))
		skynet.ret(msg, sz)
    end)
    
	DB = mysql.connect(dbcfg)
	if not DB then
		print("failed to connect")
    end

    -- cmd.save_data("t_global", {key = "test", data = "my data"})
    -- local res = cmd.query_db_data("t_global", {key = "test"})
    -- D(V2S(res))
end)

