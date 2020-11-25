local PlayerProto = register_proto_cb("player")

function PlayerProto:cs_player_enter()
    D("玩家进入agent游戏")

    local player = {
        account_id = g_player_id,
        nick_name = "xian",
        main_bag = {}
    }
    send_client_proto("sc_player_role_data", player)

    -- 通知登陆服断开连接
    local obj = get_server_obj("logind")
    obj.post.game_login(g_player_id)

    local obj = instance("player")
    obj:test("from login")
end