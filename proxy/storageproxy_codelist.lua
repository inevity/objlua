--[[
存储代理状态码配置v1
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

-- 200, "00000000", 鉴权成功，"Success"

-- 200,"20000000",无法获取S3身份验证信息(header/uri_args), 
-- 200,"20000001",请求不匹配代理要求的协议类型(s3_aws2/s3_aws4), "Current request didn't match the protocol--s3_aws2/s3_aws4"
-- 200,"20000002",根据AWSAccessKeyId获取AWS_SecretAccessKey失败,
-- 200,"20000003",获取s3身份验证相关参数失败

-- 200,"20000004",当前请求消息没有时间头, "Current request didn't Date or x-amz-date header"
-- 200,"20000005",当前请求时间不匹配S3协议要求时间(s3_aws2-15minute/s3_aws4-5minute),
-- 200,"20000006",分析请求消息参数失败(body\uri_args),
-- 200,"20000007",分析S3接口类型(service/bucket/object)失败

-- 404, "20000010", 身份验证失败

_M.codedesc = {
	[20000001]= "",
	[20000002]= "",
	[20000003]= "",
	[20000004]= "",
	[20000005]= "",
	[20000006]= "",
	[20000007]= "",
	[20000010]= "Failed Authorization",
	[20000021]= "S3_GET_Service, Failed get information from hbase",
	[20000022]= "S3_GET_Service, Failed construct response to S3_Client",
	[20000031]= "S3_bucket operation, Failed get information from hbase",
	[20000032]= "S3_bucket operation, Failed construct response to S3_Client",
	[20000033] = "",
	[20000041]= "S3_object operation, Failed get information from hbase",
	[20000042]= "S3_object operation, Failed construct response to S3_Client",
	[20000043]= ","
}

_M.S3Error = {
	-- s3code1 = {
	-- 	--message
	-- 	--httpcode
	-- }
}

return _M