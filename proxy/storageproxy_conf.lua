--[[
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
--local sp_hbaseop = require("storageproxy_hbase_op")

_M.config = {}

_M.config["aws2_timediff"] = 15
_M.config["aws4_timediff"] = 5

--AWS--->HMAC-->SHA128
_M.config["aws2_Algorithm"] = 15
--AWS--->HMAC-->SHA256
_M.config["aws4_Algorithm"] = 5

_M.config["default_hostdomain"] = "s3.dnion.com"


_M.config["s3_bucket_option"] = {}

_M.config["hbase_config"] = {}
_M.config["hbase_config"]["server"] ="120.199.77.90"
_M.config["hbase_config"]["port"] ="8080"
_M.config["hbase_config"]["request_timeout"] = 1000

_M.config["GET_Service"] = {}

_M.config["GET_Service"]["response"] = {
	ListAllMyBucketsResult = {
		Owner = {
			ID = "",
			DisplayName ="",
		},
		Buckets = {
			--real ===[
			-- {
			-- 	"Name" = "",
			-- 	"CreationDate" = "",
			-- }
			-- {
			-- 	"Name" = "",
			-- 	"CreationDate" = "",	
			-- }
			--]
		},
	},
}
--_M.config["GET_Service"]["hbase_op"] = hbase_get(uri, body, headers)

return _M