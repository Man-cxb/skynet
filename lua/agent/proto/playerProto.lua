local PlayerProto = register_proto_cb("player")

function PlayerProto:cs_player_enter()
    D("玩家进入agent游戏")
    local ok, code, res = Load_player_data(self.account_id, self.device)
    if not ok then
        return false, code, res
    end
    g_player:login(self.device or {})

    local player = {
        account_id = g_player_id,
        nick_name = "xian",
        main_bag = {}
    }
    send_client_proto("sc_player_role_data", player)
    -- send_client_proto("sc_player_account_info", g_player:get_acc_data())
end