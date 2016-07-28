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
_M.config = {}

_M.config["aws2_timediff"] = 15
_M.config["aws4_timediff"] = 5

--aws2_Algorithm--->base64_HMAC_SHA128
--aws4_Algorithm--->base64_HMAC_SHA256

_M.config["default_hostdomain"] = "s3.dnion.com"

_M.config["aws_default_operation"] = {
	"acl", "lifecycle", "policy", --......
}

_M.config["Error"] = {
--xml
-- <?xml version="1.0" encoding="UTF-8"?>
-- <Error>
-- 	<Code>NoSuchKey</Code>
-- 	<Message>The resource you requested does not exist</Message>
-- 	<Resource>/mybucket/myfoto.jpg</Resource>
-- 	<RequestId>4442587FB7D0A2F9</RequestId>
-- </Error>
--json_error=
-- {
-- 		Code = "NoSuchKey",
-- 		Message = "The resource you requested does not exist",
-- 		Resource = "/mybucket/myfoto.jpg",
-- 		RequestId = "4442587FB7D0A2F9",
-- }
} 

_M.config["s3_bucket_option"] = {
	PUT_bucket = {
		hbase_op = "storageproxy_hbase_post",
		hbase_request_body = {
			bucketname = "",
			bucketinfo = {
			},
		},
		-- hbase_request_headers = {},
		s3_response_headers = {},
		-- s3_response_body = {},
	},
	PUT_bucket_acl = {
		hbase_op = "hbase_put(uri, body, headers)",
	},
}
_M.config["s3_bucket_option"]["PUT_bucket"]["hbase_request_body"]["uid:"] = ""
_M.config["s3_bucket_option"]["PUT_bucket"]["hbase_request_body"]["bucketinfo"]["createdate:"] = ""
_M.config["s3_bucket_option"]["PUT_bucket"]["hbase_request_body"]["bucketinfo"]["quota:max_files"]  = 100000000
_M.config["s3_bucket_option"]["PUT_bucket"]["hbase_request_body"]["bucketinfo"]["quota:max_size"]  = 100
_M.config["s3_bucket_option"]["PUT_bucket"]["hbase_request_body"]["bucketinfo"]["stat:cur_files"]  = 0
_M.config["s3_bucket_option"]["PUT_bucket"]["hbase_request_body"]["bucketinfo"]["stat:cur_size"]  = 0
_M.config["s3_bucket_option"]["PUT_bucket"]["s3_response_headers"]["x-amz-request-id"] = "tx00000000000000000027b-0057835f2e-107b-default"

_M.config["s3_GET_Service"] = {
	hbase_op = "storageproxy_hbase_get",
	s3_response_body = {
		ListAllMyBucketsResult = {
			Owner = {
				ID = "",
				DisplayName ="",
			},
			Buckets = {
				--real format[
				--{
				-- 	"Name" = "",
				-- 	"CreationDate" = "",
				-- }
				-- {
				-- 	"Name" = "",
				-- 	"CreationDate" = "",	
				-- }]
			},
		},
	},
	s3_response_headers = {},
}
_M.config["s3_GET_Service"]["s3_response_headers"]["x-amz-request-id"] = "tx00000000000000000027b-0057835f2e-107b-default"


_M.config["hbase_config"] = {
	server = "120.199.77.90",
	port = "8080",
	request_timeout = 1000,
}

return _M