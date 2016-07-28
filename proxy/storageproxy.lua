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
local ngxprint = require("printinfo")

local json = require('cjson')

local function SendErrorRespToS3Client(code, innercode, s3code, Resource, RequestId)
	ngx.log(ngx.INFO, "##### SendErrorRespToS3Client")

	--recode exception log
	ngx.log(ngx.ERR, RequestId, " occur error: ",codelist.codedesc[innercode])

	--return error response to S3Client
	local error_body = {}
	local httpcode = code
	local ok, jbody

	if nil ~= s3code then
		local message = codelist.S3Error[s3code][1]
		
		if codelist.S3Error[s3code][2] then
			httpcode = codelist.S3Error[s3code][2]
		end

		error_body["code"] = s3code
		error_body["Message"] = message
		error_body["Resource"] = Resource
		error_body["RequestId"] = RequestId

		ok, jbody = pcall(json.encode, error_body)
		if not ok or type(jbody)~="string" then
	    	ngx.log(ngx.ERR, "Encode response body error. body is ", ngxprint.normalprint(error_body), "; when send Error_response to S3_Client")
			jbody = "storeproxy exceptional quit"
		end
	else
		jbody = "storeproxy exceptional quit"
	end

	ngx.status = httpcode
	ngx.say(jbody)
	ngx.exit(ngx.OK)
end

local function process_storeproxy()
	if accessobj.baseinfo["service"] then
		-- this is a interface to S3 service op
		return sp_s3op:process_service(accessobj.AWS_userinfo)
	end

	if accessobj.baseinfo["objectname"] then
		-- this is a interface to S3 object op
		return sp_s3op:process_object(accessobj.baseinfo["method"], accessobj.baseinfo["operationtype"], accessobj.baseinfo["headers"], accessobj.baseinfo["body"], accessobj.baseinfo["bucketname"], accessobj.baseinfo["objectname"], accessobj.AWS_userinfo)
	elseif accessobj.baseinfo["bucketname"] then
		-- this is a interface to S3 bucket op
		return sp_s3op:process_bucket(accessobj.baseinfo["method"], accessobj.baseinfo["operationtype"], accessobj.baseinfo["headers"], accessobj.baseinfo["body"], accessobj.baseinfo["bucketname"], accessobj.AWS_userinfo)
	else
		return 404, "10000000", nil
	end
end

--存储代理主逻辑
local function handleStoreProxy(sub_request_uri)
	ngx.log(ngx.INFO, "##### Enter handleStoreProxy, current sub_request_uri is ", sub_request_uri)
	local request_headers = ngx.req.get_headers()
	local request_uri_args = ngx.req.get_uri_args()
	local request_method = ngx.var.request_method

	local resource, request_id

	--代理身份验证流程处理
    local code, innercode, s3code = accessobj:access_authentication(request_method, ngx.var.uri, request_uri_args, request_headers, ngx.var.request_body, sub_request_uri)
    if innercode ~= "00000000" then
        ngx.log(ngx.ERR, "code:" .. code .. " code:" .. innercode, ", s3code is ", s3code)
        SendErrorRespToS3Client(code, innercode, s3code, "", request_id)
    end

	ngx.log(ngx.INFO, "##### ######baseinfo is ########")
	ngxprint.normalprint(accessobj.baseinfo)
	ngx.log(ngx.INFO, "##### ######AWS_userinfo is ########")
	ngxprint.normalprint(accessobj.AWS_userinfo)
	ngx.log(ngx.INFO, "##### ##############################")

    --代理接口分析处理
    --身份验证通过后，可获得分析处理后的"body\header\args"
    --直接通过accessobj.body/accessobj.header/accessobj.uri_args访问
    local code, innercode, s3code = process_storeproxy()
    
    if innercode ~= "00000000" then
        ngx.log(ngx.ERR, "code:" .. code .. " code:" .. innercode, ", s3code is ", s3code)

        if not accessobj.baseinfo["service"] then
        	if accessobj.baseinfo["objectname"] then
        		resource = "/" .. accessobj.baseinfo["bucketname"] .. "/" .. accessobj.baseinfo["objectname"]
        	else
        		resource = "/" .. accessobj.baseinfo["bucketname"]
        	end
        	SendErrorRespToS3Client(code, innercode, s3code, resource, request_id)
        end
    end
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