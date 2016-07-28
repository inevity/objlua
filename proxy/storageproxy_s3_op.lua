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

local sp_conf = require("storageproxy_conf")
local json = require('cjson')
local ngxprint = require("printinfo")

--s3_["GET_Service"]["response"]
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
function _M.process_service(self, AWS_userinfo)
	ngx.log(ngx.INFO, "##### Enter process_service")
	--according to S3_bucket request and transfer demands to construct hbase_request_body
	--according to S3_bucket request and transfer demands to construct hbase_request_header

	--retrieve hbase_api and request_URI
	local hbase_api = require(sp_conf.config["s3_GET_Service"]["hbase_op"])
	local API_uri = "/bucket/" .. AWS_userinfo["uid:"] .. "*"
	ngx.log(ngx.INFO, "##### API_uri is ", API_uri, " and will invoke ", sp_conf.config["s3_GET_Service"]["hbase_op"])

	--向Hbase操作
	local httpstatus, ok, dbody = hbase_api:SendtoHbase(API_uri, "service")
	if 200 ~= httpstatus or not ok then
		return httpstatus, "20000021"
	end

	--S3_GET_Service care the body from hbase

	--according to the demands of S3_GET_Service and dbody to process s3_response_body
	local response_body = sp_conf.config["s3_GET_Service"]["s3_response_body"]
	response_body["ListAllMyBucketsResult"]["Owner"]["ID"] = AWS_userinfo["uid:"]
	response_body["ListAllMyBucketsResult"]["Owner"]["DisplayName"] = "dnion_s3"
	for k,v in pairs(dbody) do
		--k is bucketname, v is bucketinfo
		local a ={}
		a["Name"] = k
		a["CreationDate"] = v["createdate:"]
		table.insert(response_body["ListAllMyBucketsResult"]["Buckets"], a)
	end
	ngx.log(ngx.INFO, "##### #########response is #############")
	ngxprint.normalprint(response_body)
	ngx.log(ngx.INFO, "##### #########response is #############")
	local ok, res = pcall(json.encode, response_body)
	if not ok then
   		return 200, "20000022"
	end

	--according to the demands of S3_bucket to process s3_response_header
	local response_headers = sp_conf.config["s3_GET_Service"]["s3_response_headers"]
	for k,v in pairs(response_headers) do
		ngx.header[k] = v
		-- if "x-amz-request-id" = k then
		-- 	--generate value
		-- end
	end

	--发出响应
	ngx.say(res)
	return 200, "00000000"
end

function _M.process_bucket(self, request_method, operationtype, headers, body, bucketname, AWS_userinfo)
	ngx.log(ngx.INFO, "##### Enter process_bucket")

	--确认当前对bucket的详细操作
	if "" == operationtype then
		op_api = request_method .. "_bucket"
	else
		op_api = request_method .. "_bucket_" .. operationtype
	end
    
	--according to S3_bucket request and transfer demands to construct hbase_request_body
	local hbase_body = sp_conf.config["s3_bucket_option"][op_api]["hbase_request_body"]

	if "PUT_bucket" == op_api then
		hbase_body["uid:"] = AWS_userinfo["uid:"]
		hbase_body["bucketname"] = bucketname
		--Current retrieve time format is "2016-07-16 16:30:59", But require "2016-07-12T16:41:58.000z"
		--default choose 008z, TODO find get zone api
		local time = ngx.localtime() 
		hbase_body["bucketinfo"]["createdate:"] = string.gsub(time, " ", "T", 1) .. ".008Z"
	end

	--according to S3_bucket request and transfer demands to construct hbase_request_header
	local hbase_header --= sp_conf.config["s3_bucket_option"][op_api]["hbase_request_header"]

	--retrieve hbase_api and request_URI
	local hbase_api = require(sp_conf.config["s3_bucket_option"][op_api]["hbase_op"])
	local API_uri = "/bucket/" .. AWS_userinfo["uid:"] .."_".. bucketname
	ngx.log(ngx.INFO, "API_uri is ", API_uri, " and will invoke sp_hbaseop.", sp_conf.config["s3_bucket_option"][op_api]["hbase_op"])

	--return 200, "20000033", real error
	--向Hbase操作
	local httpstatus, ok, dbody = hbase_api:SendtoHbase(API_uri, "bucket", hbase_header, hbase_body)
	if 200 ~= httpstatus or not ok then
		return httpstatus, "20000031"
	end

	--PUT_bucket care the status from hbase
	-- if "PUT_bucket" == op_api then
	-- end

	--according to the demands of S3_bucket and dbody to process s3_response_body
	--local response_body = sp_conf.config["s3_bucket_option"][op_api]["s3_response_body"]

	--according to the demands of S3_bucket to process s3_response_header
	local response_headers = sp_conf.config["s3_bucket_option"][op_api]["s3_response_headers"]
	for k,v in pairs(response_headers) do
		ngx.header[k] = v
		-- if "x-amz-request-id" = k then
		-- 	--generate value
		-- end
	end
	
	--发出响应
	ngx.say(res)
	return 200, "00000000"
end

function _M.process_object(self, request_method, operationtype, headers, body, bucketname, objectname, AWS_userinfo)
	--根据content-length判断object大小决定存取object的方式
	return
end

return _M