--[[
s3接口处理逻辑v1
Author:      杨婷
Mail:        yangting@dnion.com
Version:     1.0
Doc:
Modify：
    2016-07-19  杨婷  初始版本
]]

local _M = {
    _VERSION = '0.01',
}

local mt = { __index = _M }

--需要注意，从hbase获取的json格式的响应，每一项被base64编码过
local sp_hbaseop = require("storageproxy_hbase_op")
local spconf = require("storageproxy_conf")

local json = require('cjson')
local http = require "resty.http"

function process_service(self, accessobj.headers, accessobj.body, accessobj.userinfo)
	local hbase_api = sp_conf.config["GET_bucket"]["hbase_op"]

	local API_uri = "/bucket/" .. accessobj.userinfo["userid"] .. "*"
	ngx.log(ngx.INFO, "uri is ", uri, " and will invoke sp_hbaseop.", hbase_api)
	
	local res, err = sp_hbaseop.hbase_api(uri, body, headers)
	if err then
		return 503, "10000000"
	end

	ngx.say(json.encode(res))
	return 200, "00000000"
end

function process_bucket(self, request_method, operationtype, accessobj.headers, accessobj.body, accessobj.userinfo, bucketname)
	--获取调用接口
	if "" == operationtype then
		op_api = request_method .. "_bucket"
	else
		op_api = request_method .. "_bucket_" .. operationtype
	end

	--查找接口需要的数据（headers和body进行匹配）
	local hbase_api = sp_conf.config[opapi]["hbase_op"]

	local uri = "/bucket/" .. accessobj.userinfo["userid"] .."_".. bucketname
	sp_hbaseop.hbase_api(uri, headers, body)

	--向Hbase or ceph 操作
end

function process_object(self, request_method, operationtype, accessobj.headers, accessobj.body, accessobj.userinfo, bucketname, objectname)
	return
end

return _M