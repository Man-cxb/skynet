require "obj.bag"
local snax = require "snax"
local M = class("bagmgr")

function M:init(player_id, binding_flag)
	self.player_id = player_id
	self.binding_flag = binding_flag
	self.bag_list = {}
	self.next_bag_id = 1000
	for _, cfg in pairs(GetCfg("bag")) do
		self.bag_list[cfg.id] = instance("bag", cfg.id, player_id, cfg, binding_flag)
	end
end

function M:load_data(db_data)
	for _, v in pairs(db_data or {}) do
		local item = {}
		for k1, v1 in pairs(v) do
			if k1 == "attr_list" then
				item.attr_list = {}
				local ok, data = xpcall(cjson.decode, debug.traceback, v1)
				if ok then
					item.attr_list = data
				else
					D("item attr parse fail! uid=" .. v.uid, debug.traceback(data, 2))
				end
			else
				item[k1] = v1
			end
		end
		if v.bag_id >= self.next_bag_id then
			self.next_bag_id = v.bag_id + 1
		end
		local bag = self.bag_list[v.bag_id]
		if not bag then
			local cfg = GetCfg("bag")[v.bag_type_id]
			if not cfg then
				throw("bag config miss! bag_type_id=" .. v.bag_type_id)
			end
			bag = instance("bag", v.bag_id, self.player_id, cfg, self.binding_flag)
			self.bag_list[v.bag_id] = bag
		end
		local ok, code, msg = bag:add_fullitem(item, nil, true)
		if not ok then
			throw("item init fail! uid=" .. v.uid .. " err =" .. msg)
		end
	end
end

function M:get_bag(id)
	return self.bag_list[id]
end

function M:get_bag_list()
	return self.bag_list
end

-- 增加背包，用于给同一类型的背包增加实例
function M:add_bag(type_id)
	local cfg = GetCfg("bag")[type_id]
	if not cfg then
		return false, "ITEM_BAG_CFG_ERR", "背包配置丢失"
	end
	local bag = instance("bag", self.next_bag_id, self.player_id, cfg, self.binding_flag)
	self.bag_list[self.next_bag_id] = bag
	self.next_bag_id = self.next_bag_id + 1
	return bag
end

function M:move(uid, src_bagid, dest_bagid, dest_index)
	local src_bag = self.bag_list[src_bagid]
	if not src_bag then
		return false, "ITEM_NOT_EXISTS", "道具不存在"
	end
	local dest_bag = self.bag_list[dest_bagid]
	if not dest_bag then
		return false, "ITEM_BAG_NOT_EXISTS", "目标背包不存在"
	end

	local item = src_bag:get_item_byuid(uid)
	if not item then
		return false, "ITEM_NOT_EXISTS", "道具不存在"
	end
	local old_item = deep_copy_table(item)

	local ok, del_item, msg = src_bag:del_item_byuid(uid, nil, "move", true)
	if not ok then
		return false, del_item, msg
	end

	local old_index = old_item.index
	old_item.index = dest_index

	local ok2, new_item, msg2 = dest_bag:add_fullitem(old_item, dest_index)
	if not ok2 then
		old_item.index = old_index
		src_bag:add_fullitem(old_item, nil, true)
		return false, new_item, msg2
	end

	return true, del_item, new_item
end

function M:get_total_cnt(type_id)
	local total = 0
	for _, bag in pairs(self.bag_list) do
		total = total + bag:get_cnt_by_typeid(type_id)
	end
	return total
end

function M:set_binding_flag(flag)
	for _, bag in pairs(self.bag_list) do
		bag:set_binding_flag(flag)
	end
end

function M:save_data()
	for _, bag in pairs(self.bag_list) do
		bag:save_data()
	end
end

function M:login(acc)
	-- 用户登陆平台财富记录
	-- 玩家ID + 结算类型 + 道具持有量 + 记录时间 + 登陆关联标识
	local tbl = {}
	for _, bag in pairs(self.bag_list) do
		for _, item in pairs(bag.item_list) do
			table.insert(tbl, {type_id = item.type_id, cnt = item.cnt})
		end
	end
	local tbl_str = cjson.encode(tbl)
	-- Snx.post(".productlog", "log", "RecordUserPlatformLoginTreasure", self.player_id, 0, tbl_str, snax.time(), acc.login_guid)
end

function M:logout(acc)
	--用户退出平台财富记录
	--玩家ID+结算类型+道具持有量+记录时间+登陆关联标识
	local tbl = {}
    for _, bag in pairs(self.bag_list) do
    	for _, item in pairs(bag.item_list) do
    		table.insert(tbl, {type_id = item.type_id, cnt = item.cnt})
    	end
    end
    local tbl_str = cjson.encode(tbl)
	-- Snx.post(".productlog", "log", "RecordUserPlatformLogoutTreasure", self.player_id, 0, tbl_str, snax.time(), acc.login_guid)
end

function M:notify_item_change(change_list)
	local bag_list = {}
	for k, v in pairs(change_list) do
		local bag = bag_list[v.bag_id]
		if not bag then
			bag = {}
			bag_list[v.bag_id] = bag
		end
		bag[v.uid] = v
	end

	for k, v in pairs(bag_list) do
		send_client_proto("sc_player_item_change", {bag_id = k, item_list = v})
	end
end

return M