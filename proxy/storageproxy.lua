--[[
存储代理逻辑v1
Author:      杨婷
Mail:        yangting@dnion.com
Version:     1.0
Doc:
Modify：
    2016-07-15  杨婷  初始版本
]]
local access = require('storeproxy_access')
local accessobj = access.new()

local codelist = require("storeproxy_codelist")
local sp_s3op = require("storageproxy_s3_op")
local sp_conf = require("storageproxy_conf")

local comm = require('commfunc')

local function sendErrorRespToS3Client(code, desc, httpcode, respbody, respheader)
	ngx.log(ngx.log, "sendErrorRespToS3Client")

--	local uuid = require("uuid")
--	local json=require('cjson')
	ngx.say("exceptional response")
	return
end

local function process_storeproxy(request_method, sub_request_uri)
	if accessobj.baseinfo["GET_Service"] then
		return sp_s3op.process_service(accessobj.headers, accessobj.body, accessobj.userinfo)
	end

	if accessobj.baseinfo["objectname"] then
	-- this is a interface to S3 object op
		return sp_s3op.process_object(accessobj.baseinfo["method"], accessobj.baseinfo["operationtype"], accessobj.headers, accessobj.body, accessobj.baseinfo["bucketname"], accessobj.baseinfo["objectname"])
	else
	-- this is a interface to S3 bucket op
		return sp_s3op.process_bucket(accessobj.baseinfo["method"], accessobj.baseinfo["operationtype"], accessobj.headers, accessobj.baseinfo["accessobj.body"], accessobj.baseinfo["bucketname"])
	end
end

--存储代理主逻辑
local function handleStoreProxy(sub_request_uri)
	local request_headers = ngx.req.get_headers()
	local request_uri_args = ngx.req.get_uri_args()
	local request_method = ngx.var.request_method

	--代理身份验证流程处理
    local httpcode, code = accessobj:access_authentication(request_method, ngx.var.uri, request_uri_args, request_headers, ngx.var.request_body, sub_request_uri)

    if code ~= "00000000" then
        ngx.log(ngx.ERR, "httpcode:" .. httpcode .. " code:" .. code)
        sendErrorRespToS3Client(code, codelist.codedesc[code], httpcode, "", "", "")
        return
    end

    --代理接口分析处理
    --身份验证通过后，可获得分析处理后的"body\header\args"
    --直接通过accessobj.body/accessobj.header/accessobj.uri_args访问
    local httpcode, code = process_storeproxy(request_method, sub_request_uri)
    
    if code ~= "00000000" then
        ngx.log(ngx.ERR, "httpcode:" .. httpcode .. " code:" .. code)
        sendErrorRespToS3Client(code, codelist.codedesc[code], httpcode, "", "", "")
    end

	return
end

--存储代理入口
local from, to, err = ngx.re.find(ngx.var.uri, "/storeproxy/v1", "jo")
if nil ~= from then
	if 1 ~= from then
		ngx.log(ngx.ERR, "This request didn't match storeproxy's uri: ", ngx.var.uri)
		ngx.exit(ngx.HTTP_FORBIDDEN)		
	elseif string.len(ngx.var.uri) == to then
		handleStoreProxy("/")
	elseif string.len(ngx.var.uri) > to then
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