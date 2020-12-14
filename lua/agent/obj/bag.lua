local M = class("bag")
local packet = require "packet"
local skynet = require "skynet"

local max_uid = 0
local attr_cfg = {}
local item_cfg = {}

function M:init(id, player_id, cfg, binding_flag)
	self.item_list = {}
	self.type_list = {}
	self.cfg = cfg
	self.id = id
	self.player_id = player_id
	self.change_list = {}
	self.index_list = {}
	self.binding_flag = binding_flag
	attr_cfg = GetCfg("attr_id")
	item_cfg = GetCfg("item")
	self.next_index = nil
	self:gen_next_index()
end

function M:gen_next_index()
	local next_index
	for i = 1, self.cfg.cap do 
		if not self.index_list[i] then
			next_index = i
			break
		end
	end
	self.next_index = next_index
end

function M:get_idle_cnt()
    local idle = 0
    for _ in pairs(self.item_list) do
        idle = idle + 1
    end
	return self.cfg.cap - idle
end

function M:save_data()
	for uid in pairs(self.change_list) do
		if self.item_list[uid] then
			skynet.post(".dbmgr", "lua", "save_data", "t_item", self.item_list[uid])
		else
			skynet.post(".dbmgr", "lua", "delete_data", "t_item", {account_id = self.account_id, uid = uid})
		end
	end
	self.change_list = {}
end

function M:check_item_list(item_list)
	local list = {}
	for _, v in pairs(item_list) do
		if v.cnt > 0 then
			list[v.type_id] = (list[v.type_id] or 0) + v.cnt
		end
	end

	for type_id, cnt in pairs(list) do
		local ok, code, msg = self:check_item_cnt(type_id, cnt)
		if not ok then
			return false, code, msg
		end
	end
	return true
end

function M:check_item_cnt(type_id, cnt)
	local type_list = self.type_list[type_id]
	local total_cnt = 0
	for k in pairs(type_list or {}) do
		total_cnt = total_cnt + self.item_list[k].cnt
	end
	if total_cnt >= cnt then
		return true
	end
	return false, "ITEM_LACK", "道具不足"
end

function M:del_item_list(item_list, reason)
	local type_list = {}
	for _, v in pairs(item_list) do
		local old_cnt = type_list[v.type_id] and type_list[v.type_id].cnt or 0
		type_list[v.type_id] = {type_id = v.type_id, cnt = v.cnt + old_cnt }
	end

	local ok, code, err = self:check_item_list(type_list)
	if not ok then
		return false, code, err
	end
	local del_list = {}
	local err, code
	for _, data in pairs(type_list) do
		local ok, list, msg = self:del_item(data.type_id, data.cnt, reason)
		if not ok then
			code = list
			err = msg
			break
		end
		for k, v in pairs(list) do
			del_list[k] = v
		end
	end
	if err then
		for _, item in pairs(del_list) do
			if item.cnt > 0 then
				item.cnt = item.cnt - item.last_change
			else
				item.cnt = 0 - item.last_change
				self:add_fullitem(item)
			end
			self.change_list[item.uid] = nil
		end
		return false, code, err
	end
	return true, del_list
end

function M:del_item(type_id, cnt, reason)
	if cnt == 0 then
		return true, {}
	elseif cnt < 0 then
		return false, "ITEM_PARAM_ERR", "数量需大于0：" .. cnt
	end

	local ok, code, msg = self:check_item_cnt(type_id, cnt)
	if not ok then
		return false, code, msg
	end

	local type_list = self.type_list[type_id]
	local left_cnt = cnt
	local del_list = {}
	for uid in pairs(type_list) do
		local item = self.item_list[uid]
		self.change_list[item.uid] = true
		if item.cnt <= left_cnt then
			item.last_change = -1 * item.cnt
			item.cnt = 0
			self.item_list[uid] = nil
			type_list[uid] = nil
			left_cnt = left_cnt - item.cnt
			self.index_list[item.index] = nil
			del_list[uid] = item 
		else
			item.last_change = -1 * left_cnt
			item.cnt = item.cnt - left_cnt
			left_cnt = 0
			del_list[uid] = item
			break
		end
	end
	if not next(type_list) then
		self.type_list[type_id] = nil
	end
	self:gen_next_index()
	return true, del_list
end

function M:refresh_attr(uid)
	local item = self.item_list[uid]
	if not item then
		return false
	end
	if not next(item.attr_list) then
		return false
	end

	if item.level == 1 then
		local attr_list = {}
		local item_cfg = item_cfg[item.type_id]
		for k, v in pairs(item_cfg.attr_list or {}) do
			if v[1] == attr_cfg.DIG_TIME.id and self.binding_flag then
				attr_list[v[1]] = {id = v[1], val = v[2] * 2}
			else
				attr_list[v[1]] = {id = v[1], val = v[2]}
			end
		end
		item.attr_list = attr_list
		return true
	end

	if item.level > 1 then
		local attr_list = {}
		local up_cfg = GetCfg("miner_upgrade")[item.type_id]
		if up_cfg and up_cfg[item.level - 1] then
			for k, v in pairs(up_cfg[item.level - 1].next_attr_list or {}) do
				if v[1] == attr_cfg.DIG_TIME.id and self.binding_flag then
					attr_list[v[1]] = {id = v[1], val = v[2] * 2}
				else
					attr_list[v[1]] = {id = v[1], val = v[2]}
				end
			end
			item.attr_list = attr_list
			return true
		end
	end
	return false
end

function M:refresh_all_attr()
	local item_list = {}
	local up_cfg = GetCfg("miner_upgrade")
	for _, item in pairs(self.item_list) do
		if next(item.attr_list) then
			if item.level == 1 then
				local attr_list = {}
				local item_cfg = item_cfg[item.type_id]
				for k, v in pairs(item_cfg.attr_list or {}) do
					if v[1] == attr_cfg.DIG_TIME.id and self.binding_flag then
						attr_list[v[1]] = {id = v[1], val = v[2] * 2}
					else
						attr_list[v[1]] = {id = v[1], val = v[2]}
					end
				end
				item.attr_list = attr_list
				item_list[item.uid] = item
			elseif item.level > 1 then
				local attr_list = {}
				local up_cfg = up_cfg[item.type_id]
				if up_cfg and up_cfg[item.level - 1] then
					for k, v in pairs(up_cfg[item.level - 1].next_attr_list or {}) do
						if v[1] == attr_cfg.DIG_TIME.id and self.binding_flag then
							attr_list[v[1]] = {id = v[1], val = v[2] * 2}
						else
							attr_list[v[1]] = {id = v[1], val = v[2]}
						end
					end
				end
				item.attr_list = attr_list
				item_list[item.uid] = item
			end
		end
	end
	return item_list
end

function M:get_item_by_typeid(type_id)
	local list = self.type_list[type_id] or {}
	local ret = {}
	for uid in pairs(list) do
		ret[uid] = self.item_list[uid]
	end
	return ret
end

function M:get_cnt_by_typeid(type_id)
	local list = self.type_list[type_id] or {}
	local total = 0
	for uid in pairs(list) do
		local item = self.item_list[uid]
		if item then
			total = total + item.cnt
		end
	end
	return total
end

function M:set_binding_flag(flag)
	self.binding_flag = flag
end

function M:check_add_item_list(item_list)
	local total_take_cnt = 0
	local list = {}
	for _, v in pairs(item_list) do
		list[v.type_id] = (list[v.type_id] or 0) + v.cnt
	end
	for type_id, cnt in pairs(list) do
		local ok, take, msg = self:check_add_item(type_id, cnt)
		if not ok then
			return false, take, msg
		end
		total_take_cnt = total_take_cnt + take
	end
	if total_take_cnt > self:get_idle_cnt() then
		return false, "ITEM_BAG_FULL", "空间不足"
	end
	return true
end

function M:check_add_item(type_id, cnt)
	local cfg = item_cfg[type_id]
	if not cfg then
		return false, "ITEM_CFG_ERR", "未配置该物品"
	end

	if cnt == 0 then
		return true, 0
	elseif cnt < 0 then
		return false, "ITEM_PARAM_ERR", "数量需大于0：" .. cnt
	end

	local idle_cnt = 0
	local take_cnt = 0

	if not cfg.overlap or cfg.overlap <= 0  then
		if not next(self.type_list[type_id] or {}) then
			if not self.next_index then
				return false, "COM_BAG_FULL", "背包已满"
			end
			take_cnt = 1
		end
	elseif cfg.overlap > 0 then
		for k in pairs(self.type_list[type_id] or {}) do
			if self.item_list[k].cnt < cfg.overlap then
				idle_cnt = cfg.overlap - self.item_list[k].cnt
			end
		end
		if idle_cnt < cnt then
			take_cnt = math.ceil((cnt - idle_cnt) / cfg.overlap)
		end
		if take_cnt > self:get_idle_cnt() then
			return false, "ITEM_BAG_FULL", "背包已满"
		end
	end

	if cfg.max_cnt and cfg.max_cnt > 0 then
		local have_cnt = g_bagmgr:get_total_cnt(type_id)
		if have_cnt + cnt > cfg.max_cnt then
			return false, "ITEM_MAX_CNT_LIMIT", "道具数量超过上限"
		end
	end
	return true, take_cnt
end

-- 生成新的道具
local function gen_new_item(obj, type_id, cnt, item_cfg)
	local index = obj.next_index
	max_uid = max_uid + 1
	local item = {}
	item.uid = max_uid
	item.account_id = obj.player_id
	item.index = index
	item.type_id = type_id
	item.bag_id = obj.id
	item.bag_type_id = obj.cfg.id
	item.attr_list = {}
	item.level = item_cfg.init_level or 0
	item.cnt = cnt

	for _, v in pairs(item_cfg.attr_list or {}) do
		local attr = {id = v[1], val = v[2]}
		if obj.binding_flag and attr.id == attr_cfg.DIG_TIME.id then
			attr.val = attr.val * 2
		end
		item.attr_list[attr.id] = attr
	end

	obj.item_list[item.uid] = item
	obj.index_list[index] = item
	local type_list = obj.type_list[type_id]
	if not type_list then
		type_list = {}
		obj.type_list[type_id] = type_list
	end
	type_list[item.uid] = true
	obj.change_list[item.uid] = true
	obj:gen_next_index()
	return item
end

function M:add_item(type_id, cnt, reason)
	local ok, code, msg = self:check_add_item(type_id, cnt)
	if not ok then
		return ok, code, msg
	end

	local cfg = item_cfg[type_id]

	if cnt == 0 then
		return true, {}
	end

	local new_list = {}
	local old_list = {}

	if not cfg.overlap or cfg.overlap <= 0  then
		local uid = next(self.type_list[type_id] or {})
		if uid then
			old_list[uid] = self.item_list[uid]
		end
	elseif cfg.overlap > 0 then
		for k in pairs(self.type_list[type_id] or {}) do
			if self.item_list[k].cnt < cfg.overlap then
				old_list[k] = self.item_list[k]
			end
		end
	end

	for k, v in pairs(old_list) do
		self.change_list[k] = true
		if not cfg.overlap or cfg.overlap <= 0 or cfg.overlap >= v.cnt + cnt  then
			v.cnt = v.cnt + cnt
			v.last_change = cnt
			cnt = 0
			new_list[k] = v
			break
		else
			cnt = cnt + v.cnt - cfg.overlap
			v.last_change = cfg.overlap - v.cnt
			v.cnt = cfg.overlap
			new_list[k] = v
		end
		if cnt <= 0 then
			break
		end
	end

	if cnt <= 0 then
		return true, new_list
	end

	while true do
		local item_cnt = 0
		if not cfg.overlap or cfg.overlap <= 0 or cfg.overlap >= cnt then
			item_cnt = cnt
			cnt = 0
		else
			cnt = cnt - cfg.overlap
			item_cnt = cfg.overlap
		end

		local item = gen_new_item(self, type_id, item_cnt, cfg)
		item.last_change = item_cnt
		new_list[item.uid] = item
		if cnt <= 0 then
			break
		end
	end
	return true, new_list
end

function M:add_item_list_nouse(item_list, reason)
	local add_list = {}
	local err, code
	local ret = {}
	for _, data in pairs(item_list) do
		local ok, list, msg = self:add_item(data.type_id, data.cnt, reason)
		if not ok then
			code = list
			err = msg
			break
		end
		for _, item in pairs(list) do
			ret[item.uid] = item
		end
	end
	if code then
		for _, item in pairs(ret) do
			self:del_item_byuid(item.uid, item.last_change, "add_cancel", true)
			self.change_list[item.uid] = nil
		end
		return false, code, err
	end
	return true, ret
end

function M:use_item(uid)
	local item = self.item_list[uid]
	if not item or item.cnt <= 0 then
		return false, "ITEM_NOT_EXISTS", "道具不存在"
	end
	local cfg = item_cfg[item.type_id]
	if not cfg then
		return false, "ITEM_CFG_ERR", "未配置该物品"
	end
	local packet_id = tonumber(cfg.param)
	if cfg.type ~= 4 or not packet_id then
		return false, "ITEM_CFG_ERR", "配置参数有误: type=" .. cfg.type .. " param=" .. (cfg.param or "nil")
	end
	local ok, list, msg = packet.open_packet(packet_id)
	if not ok then
		return false, list, msg
	end

	local ok2, change_list, msg2 = self:add_item_list_nouse(list, "use_item")
	if not ok2 then
		return false, change_list, msg2
	end

	local ok3, new_item, msg3 = self:del_item_byuid(uid, 1, "use_item")
	if not ok3 then
		for k, v in pairs(change_list) do
			self:del_item_byuid(v.uid, v.last_change, "add_cancel", true)
			self.change_list[v.uid] = nil
		end
		return false, new_item, msg3
	end
	change_list[new_item.uid] = new_item
	return true, change_list
end

function M:add_item_list(item_list, reason, auto_use)
	local old_max_uid = max_uid

	local ok, change_list, msg = self:add_item_list_nouse(item_list, reason)
	if not auto_use or not ok then
		return ok, change_list, msg
	end

	local use_list = {}
	for k, v in pairs(change_list) do
		if item_cfg[v.type_id].auto_use then
			use_list[k] = v
		end
	end
	if not next(use_list) then
		return ok, change_list, msg
	end

	for _, item in pairs(use_list) do
		for i = 1, item.cnt do
			local ret, list, msg = self:use_item(item.uid)
			if ret then
				for k2, v2 in pairs(list) do
					change_list[k2] = v2
				end
			else
				D("use_item error!type_id=" .. item.type_id, msg)
			end
		end
	end
	-- 对于新增的道具，且数量为0的不发送
	for k, v in pairs(change_list) do
		if k > old_max_uid and v.cnt == 0 then
			change_list[k] = nil
			self.change_list[k] = nil
		end
	end
	return true, change_list
end


function M:get_item_byuid(uid)
	return self.item_list[uid]
end

-- 检查指定位置是否被占用
function M:check_index_idle(index)
	if not index then
		return false, "ITEM_INDEX_INVALID", "位置不合法"
	end
	if self.index_list[index] then
		return false, "ITEM_INDEX_HOLD", "位置已被占用"
	end
	if index > self.cfg.cap then
		return false, "ITEM_INDEX_INVALID", "位置不合法"
	end
	return true
end

-- 通过道具唯一ID删除道具
function M:del_item_byuid(uid, cnt, reason, not_save)
	local item = self.item_list[uid]
	if not item then
		return false, "ITEM_NOT_EXISTS", "道具不存在"
	end
	cnt = cnt or item.cnt
	if cnt > item.cnt then
		return false, "ITEM_LACK", "道具不足"
	end	
	
	item.cnt = item.cnt - cnt
	item.last_change = -1 * cnt
	if item.cnt <= 0 then
		self.item_list[uid] = nil
		self.index_list[item.index] = nil
		self.type_list[item.type_id][uid] = nil
		if not next(self.type_list[item.type_id]) then
			self.type_list[item.type_id] = nil
		end
		self:gen_next_index()
	end
	if not not_save then
		self.change_list[item.uid] = true
	end
	return true, item
end

-- 用于移动道具,uid不变
function M:add_fullitem(item, new_index, not_save)
	new_index = new_index or item.index or self.next_index
	if not new_index then
		return false, "ITEM_BAG_FULL", "背包已满"
	end
	if self.index_list[new_index] then
		return false, "ITEM_INDEX_HOLD", "该位置已被占用"
	end
	if new_index > self.cfg.cap then
		return false, "ITEM_INDEX_INVALID", "道具位置不合法"
	end
	if not item.uid then
		max_uid = max_uid + 1
		item.uid = max_uid
	elseif item.uid > max_uid then
		max_uid = item.uid
	end
	item.index = new_index
	item.bag_type_id = self.cfg.id
	item.bag_id = self.id
	item.last_change = item.cnt
	self.item_list[item.uid] = item
	self.index_list[new_index] = item
	local type_list = self.type_list[item.type_id]
	if not type_list then
		type_list = {}
		self.type_list[item.type_id] = type_list
	end
	type_list[item.uid] = true
	if not not_save then
		self.change_list[item.uid] = true
	end
	self:gen_next_index()

	return true, item
end

function M:get_item_list()
	return self.item_list
end

return M