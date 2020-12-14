local snax = require "snax"
local skynet = require "skynet"
local M = class("player")

function M:init()
	self.login_time = 0
	self.player = nil
	self.acc = nil
	self.update_player_flag = false
	self.device = {}
end

function M:save_data()
    if self.update_player_flag then
        skynet.post(".dbmgr", "lua", "save_data", "t_player", self.player)
	end
	self.update_player_flag = false
end

function M:load_data(acc_data, player_data)
	self.acc = acc_data
	self.player = player_data
	self.player.extend = self.player.extend or {}
	self.newer_stage = self.player.extend.newer_stage or 0
end

function M:get_player_data()
	return self.player
end

function M:get_acc_data()
	return self.acc
end

function M:login(device, ip)
	self.login_time = snax.time()
	self.device = device or {}
    self.ip = g_agent_fd
    snax.bind(".agentmgr", "agentmgr").player_login(skynet.self(), self.player.account_id, self.player.nick_name, self.ip, device.channel, device.terminal)
end

function M:logout()
    snax.bind(".agentmgr", "agentmgr").player_logout(self.player.account_id)
end

function M:update_player(data, is_init)
	for k, v in pairs(data) do
		if k == "nick_name" then
			if v ~= "" then
				self.player.name_modify_time = snax.time()
				self.player.nick_name = v
			end
		else
			self.player[k] = v
		end
	end
	self.update_player_flag = true
end

function M:update_account(data)
	for k, v in pairs(data) do
		self.acc[k] = v
	end
end

function M:add_newer_stage(inc)
	self.player.extend.newer_stage = (self.player.extend.newer_stage or 0) + inc
	self.player.newer_stage = self.player.extend.newer_stage
	self.update_player_flag = true
end

function M:get_newer_stage()
	return self.player.newer_stage or 0
end

function M:get_sys_mail_id()
	return self.player.extend.sys_mail_id or 0
end

function M:update_sys_mail_id(mail_id)
	self.player.extend.sys_mail_id = mail_id
	self.update_player_flag = true
end

function M:is_binding()
	return self.acc.binding_time > 0
end

function M:add_item(item_list, reason)
	local ok, change_list, msg = g_main_bag:add_item_list(item_list, reason, true)
	if not ok then
		return ok, change_list, msg
	end

	g_bagmgr:notify_item_change(change_list)
	return true
end

function M:del_item(item_list, reason)
	local ok, list, msg = g_main_bag:del_item_list(item_list, reason)
	if not ok then
		return ok, list, msg
	end
	g_bagmgr:notify_item_change(list)
	return true
end

function M:add_exp(exp)
	self.player.exp = self.player.exp + exp
	self.update_player_flag = true
	-- todo 判断是否升级，并通知前端
	return true
end

-- 用于操作撤销
function M:del_exp(exp)
	return true
end

return M
