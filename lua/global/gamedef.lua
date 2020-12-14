-- 性别枚举
EnumSex = {"NONE", "BOY", "GIRL"}

-- 账号注册类型
AccRegType = {
    Auto = 0, -- 游客
    User = 1, -- 账号名注册
    Phone = 2, -- 手机号注册
    SDK = 3, -- SDK
}

-- 登陆校验类型
LoginVerifyType = {
    Tourist = 0, -- 游客
    Account = 1, -- 账号
    Phone = 2, -- 手机号
    Code = 3, -- 校验吗
}