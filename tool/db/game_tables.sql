DROP TABLE IF EXISTS `t_account`;
CREATE TABLE `t_account` (
    `id`  bigint(20) NOT NULL comment '帐户ID',
    `user` varchar(64) NOT NULL comment '帐户名称',
    `passwd` varchar(128) NOT NULL comment '密码',
    `auth_code` varchar(128) NOT NULL comment '登录授权码',
    `reg_type` int NOT NULL default 0 comment '注册类型 0-游客 1-密码注册 2-手机注册 ',
    `phone_number` varchar(64) comment '电话号码',
    `id_number` varchar(64) comment '身份证号码',
    `binding_time` bigint(20) NOT NULL comment '绑定时间',
    `create_time` bigint(20) NOT NULL comment '创建时间',
    `op_time` bigint(20) NOT NULL comment '修改时间',
    UNIQUE KEY `idx_name` (`user`), 
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `t_player`;
CREATE TABLE `t_player` (
    `account_id` bigint(20) NOT NULL comment '帐户ID',
    `nick_name`  varchar(64) NOT NULL comment '昵称',
    `avatar_id`  int NOT NULL default 0 comment '图像ID',
    `sex` int NOT NULL comment '性别 0-保密 1-男 2-女',
    `level` int NOT NULL default 0 comment '等级',
    `exp` bigint(20) NOT NULL default 0 comment '经验',
    `coin` bigint(20) NOT NULL default 0 comment '金币',
    `gold` bigint(20) NOT NULL default 0 comment '黄金',
    `diamond` bigint(20) NOT NULL default 0 comment '钻石',
    `name_modify_time` bigint(20) NOT NULL default 0 comment '昵称修改时间',
    `extend` blob  comment '扩展, json格式',
    PRIMARY KEY (`account_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `t_global`;
CREATE TABLE `t_global` (
    `key`  varchar(64) NOT NULL comment 'key',
    `data` blob NOT NULL comment 'json格式',
    PRIMARY KEY (`key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `t_item`;
CREATE TABLE `t_item` (
    `account_id` bigint(20) NOT NULL comment '帐户ID',
    `uid`  bigint(20) NOT NULL comment '道具ID,account_id+uid为系统唯一ID',
    `bag_id` int NOT NULL comment '背包ID',
    `bag_type_id` int NOT NULL default 0 comment '背包类型ID',
    `index` int NOT NULL comment '物品位置',
    `type_id` bigint(20) NOT NULL comment '道具类型ID',
    `level` int NOT NULL comment '等级',
    `cnt` bigint(20) NOT NULL comment '道具数量',
    `attr_list` blob comment '道具属性,json格式',
    PRIMARY KEY (`account_id`, `uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `t_mail`;
CREATE TABLE `t_mail` (
    `id` bigint(20) NOT NULL comment '邮件ID',
    `recv_id` bigint(20) NOT NULL comment '帐户ID',
    `sender_id` bigint(20) NOT NULL comment '发送者ID',
    `tpl_id` bigint(20) NOT NULL comment '模板ID',
    `type` int NOT NULL comment '邮件类型 1-个人邮件 2-系统邮件 3-广播邮件',
    `send_time` bigint(20) NOT NULL comment '发送时间',
    `title` varchar(1024) comment '标题',
    `content` varchar(4096) comment '邮件内容',
    `param_list` varchar(1024) comment '模板参数json格式',
    `recv_time` bigint(20) NOT NULL comment '接收时间',
    `attach_list` varchar(1024) comment '附件物品列表json格式',
    `state` int NOT NULL default 0 comment '0-未读 1-已读 2-已领取',
    `expire_time` bigint(20) NOT NULL comment '超时时间',
	`business_type` bigint(20) NOT NULL comment '业务类型',  
    `business_guid` varchar(64) NOT NULL comment '业务关联标识',   
    INDEX idx_mail_id(`id`),
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `t_bulletin`;
CREATE TABLE `t_bulletin` (
  `id` bigint(20) NOT NULL comment 'dbId',
  `bulletin_id` bigint(20) NOT NULL comment '公告Id',
  `js_param` blob NOT NULL comment '公告参数',
  `js_player_list` blob NOT NULL comment '广播玩家列表',
  `start_brocast_time` bigint(20) NOT NULL comment '开始广播公告时间',
  `brocastInterval` bigint(20) NOT NULL comment '广播公告间隔',
  `brocastTimes` bigint(20) NOT NULL comment '广播公告次数',
  `last_brocast_time` bigint(20) NOT NULL comment '最近广播公告时间',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `t_rank`;
CREATE TABLE `t_rank` (
	`account_id` bigint(20) NOT NULL DEFAULT 0 comment '玩家账号id',
	`rank_name` varchar(64) NOT NULL comment '排行榜名称',
	`record_day` bigint(20) NOT NULL default 0 comment '记录日期时间',
	`income` bigint(20) NOT NULL default 0 comment '收益',
	`num` bigint(20) NOT NULL default 0 comment '大奖数量',
	PRIMARY KEY (`account_id` , `rank_name` , `record_day`)
)ENGINE=InnoDB DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `t_chat`;
CREATE TABLE `t_chat` (
  `id` bigint(20) NOT NULL comment 'dbId',
  `speak_id` bigint(20) NOT NULL comment '发言人id',
  `channel_id` bigint(20) NOT NULL comment '频道id',
  `speak_name` varchar(64) NOT NULL comment '发言人名称',
  `speak_content` blob NOT NULL comment '发言内容',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `t_mall`;
CREATE TABLE `t_mall` (
  `good_id` bigint(20) NOT NULL comment '商品id',
  `sell_num` bigint(20) NOT NULL comment '已售数量',
  `last_refresh_num_time` bigint(20) NOT NULL comment '上一次刷新出售数量时间',
  PRIMARY KEY (`good_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `t_mallorder`;
CREATE TABLE `t_mallorder` (
  `order_id` bigint(20) NOT NULL comment '订单号',
  `create_order_time` bigint(20) NOT NULL comment '订单创建时间戳',
  `account_id` bigint(20) NOT NULL comment '玩家id',
  `account_name` varchar(64) NOT NULL comment '玩家昵称',
  `good_id` bigint(20) NOT NULL comment '购买商品id',
  `good_num` bigint(20) NOT NULL comment '购买商品数量', 
  `order_state` bigint(20) NOT NULL comment '订单状态', 
  `phone_number` varchar(64) NOT NULL comment '联系电话',
  `receiver_name` varchar(64) NOT NULL comment '联系人名称',  
  `area` varchar(64) NOT NULL comment '区域',    
  `address` varchar(64) NOT NULL comment '地址',    
  `business_guid` varchar(64) NOT NULL comment '业务关联标识',   
  PRIMARY KEY (`order_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
