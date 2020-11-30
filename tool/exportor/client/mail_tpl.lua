return {
	[1] = { id = 1, macro = "MAIL_TPL_TEST", type = 1, title = "测试", sender_id = 0, content = "玩家[%s]获得第%d名", valid_day = 30, },
	[2] = { id = 2, macro = "MAIL_TPL_AUTO_PICK", type = 2, title = "自动拾取物品", sender_id = 0, content = "系统为您自动拾取掉落的物品", valid_day = 30, },
	[3] = { id = 3, macro = "MAIL_TPL_MALL_ORDER_FAIL", type = 2, title = "商城订单处理失败", sender_id = 0, content = "商城订单处理失败，返还物品：[%s],数量：[%d]，其处理失败原因是：[%s]", valid_day = 30, },
	[4] = { id = 4, macro = "MAIL_TPL_MALL_ORDER_SUCCESS", type = 2, title = "商城订单处理成功", sender_id = 0, content = "您的购买物品：[%s], 数量：[%d]的订单处理成功，物流订单号：[%s]", valid_day = 30, },
	[5] = { id = 5, macro = "MAIL_TPL_MALL_BAG_FULL", type = 2, title = "背包已满", sender_id = nil, content = "由于背包已满，物品无法加入背包，请在此查收", valid_day = 30, },
	[6] = { id = 6, macro = "MAIL_TRADE_GOODS_TIMEOUT", type = 2, title = "交易所商品超时下架", sender_id = 0, content = "您寄售的商品已超时下架！", valid_day = 30, },
	[7] = { id = 7, macro = "MAIL_TRADE_SELL_SUCC", type = 2, title = "交易所商品出售成功", sender_id = 0, content = "你寄售的商品已出，共获得", valid_day = 30, },
	[8] = { id = 8, macro = "MAIL_TRADE_BAG_FULL", type = 2, title = "背包已满", sender_id = 0, content = "由于背包已满，物品无法加入背包，请在此查收", valid_day = 30, },
	[9] = { id = 9, macro = "MAIL_RECHARGE_ORDER_TIMEOUT", type = 2, title = "订单超时", sender_id = 0, content = "你的订单[%s]已超时", valid_day = 30, },
	[10] = { id = 10, macro = "MAIL_RECHARGE_ORDER_FINISH", type = 2, title = "订单完成", sender_id = 0, content = "你的订单[%s]已完成，获得以下物品，请查收!", valid_day = nil, },
}
