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

--需要注意，从hbase获取的json格式的响应，每一项被base64编码过
local sp_hbaseop = require("storageproxy_hbase_op")
local sp_conf = require("storageproxy_conf")

local json = require('cjson')
local http = require "resty.http"

local ngxprint = require("printinfo")
--sp_conf.config["GET_Service"]["response"]
--[[--xml
<?xml version="1.0" encoding="UTF-8"?>
<ListAllMyBucketsResult xmlns="http://s3.amazonaws.com/doc/2006-03-01">
	<Owner>
		<ID>bcaf1ffd86f461ca5fb16fd081034f</ID>
		<DisplayName>webfile</DisplayName>
	</Owner>
	<Buckets>
		<Bucket>
			<Name>quotes</Name>
			<CreationDate>2006-02-03T16:45:09.000Z</CreationDate>
		</Bucket>
		<Bucket>
			<Name>samples</Name>
			<CreationDate>2006-02-03T16:41:58.000Z</CreationDate>
		</Bucket>
	</Buckets>
</ListAllMyBucketsResult>
--json
GET_Service_response = {
	"ListAllMyBucketsResult" = {
		"Owner" = {
			"ID" = "",
			"DisplayName" =""
		},
		"Buckets" = [
			-- {
			-- 	"Name" = "",
			-- 	"CreationDate" = "",
			-- }
			-- {
			-- 	"Name" = "",
			-- 	"CreationDate" = "",	
			-- }
		]
	}
}
]]
function _M.process_service(self, body, AWS_userinfo)
	ngx.log(ngx.INFO, "##### Enter process_service")

	local hbase_api = sp_conf.config["GET_Service"]["hbase_op"]
	local API_uri = "/bucket/" .. AWS_userinfo["uid:"] .. "*"
	--local API_uri = "/bucket/" .. "test" .. "*"

	ngx.log(ngx.INFO, "API_uri is ", API_uri, " and will invoke sp_hbaseop.", hbase_api)
	
	local ok, dbody = sp_hbaseop.hbase_get(API_uri, headers, body)
	if not ok then
		return 503, "10000000"
	end

	print("###############################")
	ngxprint.normalprint(dbody)
	print("###############################")

	--res是用户的bucketinfo信息
	--将res解析为GET_Service的 S3 响应
	local response = sp_conf.config["GET_Service"]["response"]
	--local response = {}
	response["ListAllMyBucketsResult"]["Owner"]["ID"] = AWS_userinfo["uid:"]
	response["ListAllMyBucketsResult"]["Owner"]["DisplayName"] = "dnion_s3"

	for k,v in pairs(dbody) do
		--k is bucketname, v is bucketinfo
		local a ={}
		a["Name"] = k
		a["CreationDate"] = v["createdate:"]
		table.insert(response["ListAllMyBucketsResult"]["Buckets"], a)
	end

	print("#########response is #############")
	ngxprint.normalprint(response)
	print("########response is ###########")

	local ok, res = pcall(json.encode, response)
	if not ok then
   		return 503, "20000010"
	end

	ngx.say(res)
	return 200, "00000000"
end

function _M.process_bucket(self, request_method, operationtype, headers, body, userinfo, bucketname)
	--获取调用接口
	if "" == operationtype then
		op_api = request_method .. "_bucket"
	else
		op_api = request_method .. "_bucket_" .. operationtype
	end

	--查找接口需要的数据（headers和body进行匹配）
	local hbase_api = sp_conf.config[opapi]["hbase_op"]
    
    --向Hbase操作
	local uri = "/bucket/" .. userinfo["uid"] .."_".. bucketname
	sp_hbaseop.hbase_api(uri, headers, body)	
end

function _M.process_object(self, request_method, operationtype, headers, body, userinfo, bucketname, objectname)
	--根据content-length判断object大小决定存取object的方式
	return
end

return _M