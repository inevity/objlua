--[[
存储代理身份验证处理逻辑v1
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
--新建access对象
function _M.new(self)
    return setmetatable({}, mt)
end

local json = require('cjson')
local comm = require('commfunc')

--需要注意，从hbase获取的json格式的响应，每一项被base64编码过
local sp_hbaseop = require("storageproxy_hbase_op")
local sp_conf = require("storageproxy_sp_conf")

local ngxprint = require("printinfo")

local _M.AWSAccessInfo = {
	--"timestamp"
	--"original_Authorization"
	--"protocaltype"
	--"original_date"
	--"accessdetails"
	----"AWSAccessKeyId"
	----"original_signature"
	--"AWS_SecretAccessKey"
}

_M.AWS_userinfo = {}
_M.headers = {}
_M.body = {}
_M.uri_args = {}
_M.baseinfo = {}

local function _recognize_S3_type(authorization_info, is_auth_args)
	local final_protocoltype, surplus_authorization
	
	if is_auth_args then
		if nil ~= authorization_info["AWSAccessKeyId"] then
			final_protocoltype = "aws2"
		elseif "AWS4-HMAC-SHA256" == authorization_info["X-Amz-Algorithm"] then
			final_protocoltype = "aws4"
		-- else
		-- 	ngx.log(ngx.ERR, "")
		end
	else
		local from, to, err

		if from, to, err == ngx.re.find(authorization_info, "AWS4-HMAC-SHA256\s+", "jo") then
			if nil ~= from then
				final_protocoltype = "aws4"
				surplus_authorization = string.sub(authorization_info, to+1)
			else
				if err then
					ngx.log(ngx.ERR, "", err)
				else
					ngx.log(ngx.INFO, "not match s3_AWS4-HMAC-SHA256", err)
				end
			end
		elseif from, to, err == ngx.re.find(authorization_info, "AWS\s+\w", "jo") then
			if nil ~= from then
				final_protocoltype = "aws2"
				surplus_authorization = string.sub(authorization_info, to, string.len(authorization_info))
			else
				if err then
					ngx.log(ngx.ERR, "", err)
				else
					ngx.log(ngx.INFO, "not match s3_AWS2", err)
				end
			end
		-- else
		-- 	ngx.log(ngx.ERR, "")
		end		
	end

	return final_protocoltype, surplus_authorization
end

local function _opt_valid_request(verifyprotocal, date, date_name)
	local ok, timestamp = sp_comm.s3_dateTOtimestamp(verifyprotocal, date, date_name)
	if not ok then 
		ngx.log(ngx.ERR, "Cannot get timestamp from s3_", verifyprotocal, ", original date is ", tostring(date))
		return false, nil
	end

	bodytime = tonumber(timestamp)
	nowtime = os.time()
	difftime = nowtime - bodytime
	allowtimediff = sp_conf.sp_config[verifyprotocal .. "_timediff"] * 60

    if difftime > allowtimediff or difftime < -allowtimediff then
        ngx.log(ngx.ERR, "Current request invalid, s3_", verifyprotocal, "require request didn't later current time than", allowtimediff, "s")
        return false, nil
    end

    return true, timestamp
end

local function _retrieve_S3_info(authorization_info, s3_protocal_type, is_auth_args)
	local accessinfo = {}
	if "aws2" == s3_protocal_type then
		if not is_auth_args then
			--authorization_info is a string
			--AKIAIOSFODNN7EXAMPLE:frJIUN8DYpKDtOLCwo//yllqDzg=
			local from, to = string.find(authorization_info, ":")
			print("find---accessinfo[\"AWSAccessKeyId\"] is ", string.sub(authorization_info, 1, sep-1))
			print("find---accessinfo[\"original_signature\"] is ", string.sub(authorization_info, spe+1, string.len(authorization_info)))	
			accessinfo["AWSAccessKeyId"] = string.sub(authorization_info, 1, sep-1)
			accessinfo["original_signature"] = string.sub(authorization_info, spe+1, string.len(authorization_info))
			local cp, err = ngx.re.match(authorization_info, "(\w+)\s?:\s?(\w+)", "jo")
			print("match---accessinfo[\"AWSAccessKeyId\"] is ", cp[1])
			print("match---accessinfo[\"original_signature\"] is ", cp[2])
			-- accessinfo["AWSAccessKeyId"] = cp[1]
			-- accessinfo["original_signature"] = cp[2]
		else
			----authorization_info is a table
			--AWSAccessKeyId=AKIAIOSFODNN7EXAMPLE&Expires=1141889120&Signature=vjbyPxybdZaNmGa%2ByT272YEAiv4%3D
			accessinfo["AWSAccessKeyId"] = authorization_info["AWSAccessKeyId"]
			accessinfo["original_signature"] = authorization_info["Signature"]
			accessinfo["Expires"] = authorization_info["Expires"]
		end
	elseif "aws4" == s3_protocal_type then
		if not is_auth_args then
			--authorization_info is a string
			--Credential=AKIDEXAMPLE/20150830/us-east-1/iam/aws4_request, SignedHeaders=content-type;host;x-amz-date, Signature=5d672d79c15b13162d9279b0855cfba6789a8edb4c82c400e06b5924a6f2b5d7
			local cp,err = ngx.re.match(authorization_info, "^Credential=(\w+)(.+)", "jo")
			accessinfo["AWSAccessKeyId"] = cp[1]
			accessinfo["Credential"] = cp[2]

			cp,err = ngx.re.match(authorization_info, "^Signature=(\w+)", "jo")
			accessinfo["original_signature"] = authorization_info["X-Amz-Signature"]
			accessinfo["Expires"] = authorization_info["X-Amz-Expires"]

			cp,err = ngx.re.find(authorization_info, "^Signature=(。+)", "jo")
			accessinfo["SignedHeaders"] = authorization_info["X-Amz-SignedHeaders"]
		else
			----authorization_info is a table
			--Action=ListUsers&Version=2010-05-08&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIDEXAMPLE%2F20150830%2Fus-east-1%2Fiam%2Faws4_request&X-Amz-Date=20150830T123600Z&X-Amz-Expires=60&X-Amz-SignedHeaders=content-type%3Bhost&X-Amz-Signature=37ac2f4fde00b0ac9bd9eadeb459b1bbee224158d66e7ae5fcadb70b2d181d02
			
			accessinfo["original_signature"] = authorization_info["X-Amz-Signature"]
			accessinfo["Expires"] = authorization_info["X-Amz-Expires"]

			local from, to = string.find(string.subauthorization_info["X-Amz-Credential"], '%')
			accessinfo["AWSAccessKeyId"] = string.sub(string.subauthorization_info["X-Amz-Credential"], 1, from-1)
			accessinfo["Credential"] = string.sub(string.subauthorization_info["X-Amz-Credential"], to, string.len(string.subauthorization_info["X-Amz-Credential"]))

			accessinfo["Action"] = authorization_info["Action"]
			accessinfo["Version"] = authorization_info["Version"]
			accessinfo["Date"] = authorization_info["X-Amz-Date"]
			accessinfo["SignedHeaders"] = authorization_info["X-Amz-SignedHeaders"]
		end
	--else
	end
	
	self.AWSAccessInfo["accessdetails"] = accessinfo
	return
end

local function _check_msg(args, headers, body, is_auth_args)
	-- body
	if nil ~= body then
		local ok, jbody = pcall(json.decode, body)
	    if not ok or type(jbody)~="table" then
	        ngx.log(ngx.ERR, "request body error. body is " ..  tostring(body))
	        return false
	    end

	    _M.body = jbody
	end
	--args
	if nil ~= args then
		if is_auth_args then
			i=1
			for k,v in pairs(args) do
				for k2,v2 in pairs(args) do
					if k ~= k2 and nil== string.find(k, k2) and nil == string.find(k2, k) then
						if tostring(v) ~= "true" then
							_M.uri_args[i]= k.."="..v
						else
							_M.uri_args[i]=k
						end
						i = i+1
					end
				end
				if tostring(v) == "true" then
					_M.uri_args= args
				end
			end
		else
			_M.uri_args= args
		end	
	end

	_M.headers = headers
	return true
end

local function _start_authorization(verifyprotocal)
	if "aws2" == verifyprotocal then
	    --AWS 签名版本 2
	    local crinit, cruri, crop
	    if "from host" == self.baseinfo["api_access_mode"] then
	    	crinit = "/"+ self.baseinfo["bucketname"]
	    	cruri = crinit + sub_request_uri
	    else
	    	crinit = ""
			cruri = sub_request_uri
	    end

	    if self.baseinfo["GET_Service"] then
	    	cruri = "/"
	    end

	    crop="?"
	    for i,v in ipairs(self.uri_args) do
	    	if "?" == crop then
	    		crop = crop + v
	    	else
	    		crop = crop + "&" + v
	    	end
	    end

		local CanonicalizedResource = crinit + cruri + crop

		local tmptable = {}
		local headertable = {}
		local i = 1
		local tmpstr = ""
		local header,value
		for k,v in pairs(self.headers) do
			header = string.lower(k)
			value = string.lower(v)
			local from, to = string.find(header, "x-amz") 
			if nil ~= from then
				if nil ~= string.find(tmpstr, header) then
					local v = tmptable[header] + ";" + value
					tmptable[header] = v
				else
					tmptable[header] = value
					tmpstr = tmpstr + header + ";"
					table.insert(headertable, header)
				end
			end
		end

		table.sort(headertable)

		local CanonicalizedAmzHeaders
		for i,v in ipairs(headertable) do
			if i == #headertable then
				CanonicalizedAmzHeaders = CanonicalizedAmzHeaders + tmptable[v]
				break
			end
			CanonicalizedAmzHeaders = CanonicalizedAmzHeaders + tmptable[v] +'\n'
		end

		local content_md5
		if nil ~= self.headers["Content-MD5"] then
			content_md5 = self.headers["Content-MD5"] + "\n"
		else
			content_md5 = "\n"
		end

		local content_type
		if nil ~= self.headers["Content-Type"] then
			content_type = self.headers["Content-Type"] + "\n"
		else
			content_type = "\n"
		end

		local StringToSign = self.baseinfo["method"] + "\n" +  content_md5 + content_type
			+ self.AWSAccessInfo["Date"] + "\n" + CanonicalizedAmzHeaders + CanonicalizedResource;

		
		local digest = ngx.hmac_sha1(self.AWSAccessInfo["AWSAccessKeyId"], StringToSign)
		local new_signature = ngx.encode_base64(digest)

		if self.AWSAccessInfo["original_signature"] == new_signature then
			return 200, "00000000"
		else
			return 404, "10000000" 
		end

	-- elseif "aws4" == verifyprotocal then
	--  --AWS 签名版本 4
	end
end

function _get_request_info(method, uri, sub_request_uri)
--请求的几种形式
--bucket\object信息在uri中
-- "/" -- list bucket
-- "/bucket{?optype}" --bucket op
-- "/bucket/object{?optype}" --object op
--若bucketname在host中, 下述操作是否正确需要后期验证
-- "/" -- list bucket
-- "{?optype}" --bucket op 
-- "/object{?optype}" or ???--object op
	local api_access_mode = "from uri" --默认值
	local bucketname, objectname = ""
	local GET_Service = false

	--首先确认S3接口使用的接入模式
	local host = self.headers["Host"]
	local from, to, err = ngx.re.find(host, sp_conf.config["default_hostdomain"], "jo")
	if nil ~= from then
		if 1 ~= from then
			api_access_mode = "from host"
			bucketname = string.sub(host, 1, from-2)
		end
	else
		if err then
			ngx.log(ngx.ERR, "", err)
			return 201, "10000000"
		else
			ngx.log(ngx.INFO, "", ngx.var.uri)
		end
	end

    --确认当前request的类型
	local splittab = comm.strsplit(sub_request_uri, "/")
	for i,v in ipairs(splittab) do
		ngx.log(ngx.INFO, "sub_request_uri split to ", i .. ":" .. v)
	end
	local len_splittab

	if 1 == #splittab then
		objectname = splittab[1]
	elseif 2 == len_splittab then
		if nil == splittab[2] and "GET" == request_method then
			GET_Service = true
		else
			if "from uri" == api_access_mode then
				bucketname = splittab[2]
			else
				objectname = splittab[2]
			end 
		end
	elseif 3 == len_splittab then
		bucketname = splittab[2]
		objectname = splittab[3]
	else
		ngx.log(ngx.ERR, "sub_request_uri is error, it is ", sub_request_uri)
	end

	local s3_option
	local operationtype = ""
	if nil ~= objectname then
		s3_option = "s3_object_option"
	else
		s3_option = "s3_bucket_option"
	end
	
	for i,v in ipairs(accessobj.uri_args) do
		for i2,v2 in ipairs(sp_conf.config[s3_option]) do
			if v2 == accessobj.uri_args[1] then
				operationtype = v
				break
			end
		end
	end

	self.baseinfo["service"] = service
	self.baseinfo["bucketname"] = bucketname
	self.baseinfo["objectname"] = objectname
	self.baseinfo["operationtype"] = operationtype
	self.baseinfo["method"] = method
	self.baseinfo["uri"] = uri
	self.baseinfo["sub_request_uri"] = sub_request_uri
	self.baseinfo["api_access_mode"] = api_access_mode
end

--入口主函数
function access_authentication(self, method, uri, args, headers, body)
	ngx.log(ngx.INFO, "enter access_authentication")
	ngx.log(ngx.INFO, "method is ", ngxprint.ngxprint(method))
	ngx.log(ngx.INFO, "uri is ", ngxprint.ngxprint(uri))
	ngx.log(ngx.INFO, "body is ", ngxprint.ngxprint(body))
	ngx.log(ngx.INFO, "args is", ngxprint.ngxprint(args))
	ngx.log(ngx.INFO, "headers is ", ngxprint.ngxprint(headers))

	print("########################")
	ngx.log(ngx.INFO, "method is ", method)
	ngx.log(ngx.INFO, "uri is ", uri)
	ngx.log(ngx.INFO, "body is ", body)
	ngx.log(ngx.INFO, "args is ")
	ngxprint.normalprint(args)
	ngx.log(ngx.INFO, "headers is ")
	ngxprint.normalprint(headers)

    --预处理
    ----a) 获取身份验证信息
    local verifyprotocal, authorization
    local is_auth_args = false

    if nil ~= self.headers["Authorization"] then
    	authorization = self.headers["Authorization"]
    elseif nil ~= self.args then
    	authorization = self.args
		is_auth_args = true
    else
		ngx.log(ngx.ERR, "Current request didn't match the protocol format of S3")
		return 201, "20000000"
    end

    self.AWSAccessInfo["original_Authorization"]  = authorization
    ngx.log(ngx.INFO, "authorization is ", ngxprint.ngxprint(authorization), " and get from uri args is ", ngxprint.ngxprint(is_auth_args))
    
    ----b) 获取身份验证计算使用的版本和算法
    local surplus_authorization
    verifyprotocal, surplus_authorization = _recognize_S3_type(authorization, is_auth_args)
    if nil == verifyprotocal then
    	ngx.log(ngx.ERR, "Current request didn't match the protocol format of S3")
    	return 201, "20000000"
    else
    	if not is_auth_args then
    		if nil == surplus_authorization  then
    			ngx.log(ngx.ERR, "Current request didn't match the protocol format of S3_", verifyprotocal, " and verifyinfo in Authorization header")
    			return 201, "20000000"
    		end
    		authorization = surplus_authorization
    		ngx.log(ngx.INFO, "surplus_authorization is ", ngxprint.ngxprint(authorization))
    	end
   	end

   	self.AWSAccessInfo["protocaltype"] = verifyprotocal

   	----c) get date and verify valid request 
    local date, date_name
    if not is_auth_args then
		if nil ~= self.headers["x-amz-date"] then
			date = self.headers["x-amz-date"]
			date_name = "x-amz-date"
		elseif nil ~= self.headers["Date"] then
			date = self.headers["Date"]
			date_name = "Date"
		else
	    	ngx.log(ngx.ERR, "Current request didn't Date or x-amz-date header")
	    	return 201, "20000004"
	    end

	    local ok, timestamp = _opt_valid_request(verifyprotocal, date, date_name)
	    if not ok then
	    	return 201, "20000006"
	    end
    --else
    ----身份验证在uri_args，无需对请求进行时间校验
    end

    self.AWSAccessInfo["original_date"] = datename .. "--" .. date
    self.AWSAccessInfo["timestamp"] = timestamp

  	----d) 解析并处理鉴权相关的参数
    _retrieve_S3_info(authorization, verifyprotocal, is_auth_args)
    
    --2. 获取AWS_SecretAccessKey
    local ok, secret, userinfo = 
    	sp_hbaseop.retrieve_AWS_SecretAccessKey(self.AWSAccessInfo["accessdetails"]["AWSAccessKeyId"])
    if not ok then
    	return 201, "20000003"
    end

    self.AWSAccessInfo["AWS_SecretAccessKey"] = secret
    self.AWS_userinfo = userinfo

    --3. 解析相关参数_retrieve_S3_info
    local ok = _check_msg(args, headers, body)
    if not ok then
    	return 201, "20000007"
    end

    --4. 获取请求类型
    _get_request_info(method, uri, sub_request_uri)

    --5. 开始鉴权
    local status, code = _start_authorization(verifyprotocal)
 
    return status, code
end

return _M
