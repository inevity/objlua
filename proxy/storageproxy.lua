--[[
存储代理逻辑v1
Author:      杨婷
Mail:        yangting@dnion.com
Version:     1.0
Doc:
Modify：
    2016-07-15  杨婷  初始版本
]]
local access = require('storageproxy_access')
local accessobj = access.new()

local codelist = require("storageproxy_codelist")
local sp_s3op = require("storageproxy_s3_op")
local sp_conf = require("storageproxy_conf")

local comm = require('commfunc')
local ngxprint = require("printinfo")

local function sendErrorRespToS3Client(code, desc, httpcode, respbody, respheader)
	ngx.log(ngx.INFO, "sendErrorRespToS3Client")
	ngx.say("exceptional response")
	ngx.exit(NGX_OK)
end

local function process_storeproxy()
	if accessobj.baseinfo["service"] then
		return sp_s3op:process_service(accessobj.body, accessobj.AWS_userinfo)
	end

	if accessobj.baseinfo["objectname"] then
	-- this is a interface to S3 object op
		return sp_s3op:process_object(accessobj.baseinfo["method"], accessobj.baseinfo["operationtype"], accessobj.headers, accessobj.body, accessobj.baseinfo["bucketname"], accessobj.baseinfo["objectname"])
	elseif accessobj.baseinfo["bucketname"] then
	-- this is a interface to S3 bucket op
		return sp_s3op:process_bucket(accessobj.baseinfo["method"], accessobj.baseinfo["operationtype"], accessobj.headers, accessobj.baseinfo["accessobj.body"], accessobj.baseinfo["bucketname"])
	else
		return 404, "10000000"
	end
end

--存储代理主逻辑
local function handleStoreProxy(sub_request_uri)
	ngx.log(ngx.INFO, "##### Enter main_service------handleStoreProxy, current sub_request_uri is ", sub_request_uri)
	local request_headers = ngx.req.get_headers()
	local request_uri_args = ngx.req.get_uri_args()
	local request_method = ngx.var.request_method

	--代理身份验证流程处理
    local httpcode, code = accessobj:access_authentication(request_method, ngx.var.uri, request_uri_args, request_headers, ngx.var.request_body, sub_request_uri)
    if code ~= "00000000" then
        ngx.log(ngx.ERR, "httpcode:" .. httpcode .. " code:" .. code)
        sendErrorRespToS3Client(code, codelist.codedesc[code], httpcode, "", "", "")
    end

	print("######body is ########")
	ngxprint.normalprint(accessobj.body)
	print("######baseinfo is ########")
	ngxprint.normalprint(accessobj.baseinfo)
	print("######uri_args is ########")
	ngxprint.normalprint(accessobj.uri_args)
	print("######AWS_userinfo is ########")
	ngxprint.normalprint(accessobj.AWS_userinfo)
	print("##############################")

    --代理接口分析处理
    --身份验证通过后，可获得分析处理后的"body\header\args"
    --直接通过accessobj.body/accessobj.header/accessobj.uri_args访问
    local httpcode, code = process_storeproxy()
    
    if code ~= "00000000" then
        ngx.log(ngx.ERR, "httpcode:" .. httpcode .. " code:" .. code)
        sendErrorRespToS3Client(code, codelist.codedesc[code], httpcode, "", "", "")
    end
    return 
end

--存储代理入口
local from, to, err = ngx.re.find(ngx.var.uri, "^/storageproxy/v1", "jo")
if nil ~= from then
	ngx.log(ngx.INFO, "##### ngx.var.uri is ", ngx.var.uri)
	if string.len(ngx.var.uri) == to then
		ngx.log(ngx.INFO, "##### After match storeproxy's main_uri, the sub_uri is ", "/")
		handleStoreProxy("/")
	elseif string.len(ngx.var.uri) > to then
		ngx.log(ngx.INFO, "##### After match storeproxy's main_uri, the sub_uri is ", string.sub(ngx.var.uri, to+1))
		handleStoreProxy(string.sub(ngx.var.uri, to+1))
	end 
else
	if err then
		ngx.log(ngx.ERR, "Match storeproxy's uri occur err: ", err)
	else
		ngx.log(ngx.ERR, "This request didn't match storeproxy's uri: ", ngx.var.uri)
	end

	ngx.exit(ngx.HTTP_NOT_FOUND)
end