local M = {}
local math_random = math.random

-- 按物品配置的权重weight分别计算每个物品的掉落
local function open_packet_1(item_cfg)
	local list = {}
	for _, v in pairs(item_cfg) do
		if v.weight < 0 then
			list[v.item_type_id] = (list[v.item_type_id] or 0) + math_random(v.min_cnt, v.max_cnt)
		else
			local weight = math_random(1, 10000)
			if weight < v.weight then
				list[v.item_type_id] = (list[v.item_type_id] or 0) + math_random(v.min_cnt, v.max_cnt)
			end
		end
	end
	return list
end

-- 除weight小于0的物品为必出外，其它物品按配置的权重weight只出一个
local function open_packet_2(item_cfg)
	local list = {}
	local total_weight = 0
	for _, v in pairs(item_cfg) do
		if v.weight < 0 then
			list[v.item_type_id] = (list[v.item_type_id] or 0) + math_random(v.min_cnt, v.max_cnt)
		else
			total_weight = total_weight + v.weight
		end
	end
	if total_weight <= 0 then
		return list
	end
	local weight = math_random(1, total_weight)
	local cur_weight = 0
	for _, v in pairs(item_cfg) do
		if v.weight > 0 then
			cur_weight = cur_weight + v.weight
			if weight <= cur_weight then
				list[v.item_type_id] = (list[v.item_type_id] or 0) + math_random(v.min_cnt, v.max_cnt)
				return list
			end
		end
	end
	return list
end

-- 按物品配置的权重weight分别计算每个物品的掉落,权重大于10000时，与10000取商，商为必出数量，取模结果为按概率取
local function open_packet_3(item_cfg)
	local list = {}
	for _, v in pairs(item_cfg) do
		if v.weight < 0 then
			list[v.item_type_id] = (list[v.item_type_id] or 0) + math_random(v.min_cnt, v.max_cnt)
		else
			local fix_cnt = v.weight // 10000
			if fix_cnt > 0 then
				list[v.item_type_id] = (list[v.item_type_id] or 0) + math_random(v.min_cnt, v.max_cnt) * fix_cnt
			end
			local rand = v.weight % 10000
			local weight = math_random(1, 10000)
			if weight < rand then
				list[v.item_type_id] = (list[v.item_type_id] or 0) + math_random(v.min_cnt, v.max_cnt)
			end
		end
	end
	return list
end

local open_method =
{
	[1] = open_packet_1,
	[2] = open_packet_2,
	[3] = open_packet_3,
}

function M.open_packet(id)
	local packet_cfg = GetCfg("packet")[id]
	if not packet_cfg then
		return false, "COM_CFG_MISS", "道具包未配置"
	end
	local item_cfg = GetCfg("packet_item")[id]
	if not item_cfg then
		return false, "COM_CFG_MISS", "道具包未配置道具列表"
	end
	local func = open_method[packet_cfg.type]
	if not func then
		return false, "COM_CFG_MISS", "道具包类型配置错误"
	end
	local list = func(item_cfg)
	local ret = {}
	for k, v in pairs(list) do
		if v > 0 then
			ret[k] = {type_id = k, cnt = v}
		end
	end
	return true, ret
end

return M