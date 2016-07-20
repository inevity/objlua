s--[[
存储代理业务配置模块v1
Author:      杨婷
Mail:        yangting@dnion.com
Version:     1.0
Doc:
Modify：
    2016-07-19  杨婷  初始版本
]]

local _M = {
    _VERSION = '1.00',
}




_M.config = {}

_M.config["aws2_timediff"] = 15
_M.config["aws4_timediff"] = 5

--AWS--->HMAC-->SHA128
_M.config["aws2_Algorithm"] = 15
--AWS--->HMAC-->SHA256
_M.config["aws4_Algorithm"] = 5


_M.config["s3_bucket_option"] = {
	
}
return _M