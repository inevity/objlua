--[[
´æ´¢´úÀíÉí·ÝÑéÖ¤´¦ÀíÂß¼­v1
Author:      ÑîæÃ
Mail:        yangting@dnion.com
Version:     1.0
Doc:
Modify£º
    2016-07-19  ÑîæÃ  ³õÊ¼°æ±¾
]]

local _M = {
    _VERSION = '0.01',
}

local mt = { __index = _M }
--
function _M.new(self)
    return setmetatable({}, mt)
end

local json = require('cjson')
local comm = require('commfunc')

--
local sp_hbaseop = require("storageproxy_hbase_op")
local sp_conf = require("storageproxy_conf")

local sp_comm = require("storageproxy_common")

local ngxprint = require("printinfo")

local AWSAccessInfo = {
	--"timestamp"
	--"original_Authorization"
	--"protocaltype"
	--"original_date_name"
	
	--"accessdetails"
	----"AWSAccessKeyId"
	----"original_signature"
	
	--"AWS_SecretAccessKey"
}

_M.AWS_userinfo = {}
_M.body = {}
_M.uri_args = {}
_M.baseinfo = {}

local function _recognize_S3_type(authorization_info, is_auth_args)
	ngx.log(ngx.INFO, "##### Enter _recognize_S3_type")
	local final_protocoltype, surplus_authorization
	
	if is_auth_args then
		if nil ~= authorization_info["AWSAccessKeyId"] then
			final_protocoltype = "aws2"
		elseif "AWS4-HMAC-SHA256" == authorization_info["X-Amz-Algorithm"] then
			final_protocoltype = "aws4"
		-- else
		-- 	ngx.log(ngx.ERR, "")
		end

		return final_protocoltype, nil
	else
		local from, to, err = ngx.re.find(authorization_info, "AWS4-HMAC-SHA256\\s+", "jo")

		if err then
			ngx.log(ngx.ERR, "", err)
		else
			if nil ~= from then
				final_protocoltype = "aws4"
				surplus_authorization = string.sub(authorization_info, to+1)
				return final_protocoltype, surplus_authorization
			else
				ngx.log(ngx.INFO, "not match s3_AWS4-HMAC-SHA256")
			end
		end

		from, to, err = ngx.re.find(authorization_info, "AWS\\s+", "jo")
		if err then
			ngx.log(ngx.ERR, "", err)
		else
			if nil ~= from then
				final_protocoltype = "aws2"
				surplus_authorization = string.sub(authorization_info, to+1)
				return final_protocoltype, surplus_authorization
			else
				ngx.log(ngx.INFO, "not match s3_AWS2")
			end
		end

		return final_protocoltype, surplus_authorization
	end
end

local function _opt_valid_request(verifyprotocal, date, date_name)
	ngx.log(ngx.INFO, "##### Enter _opt_valid_request")
	ngx.log(ngx.INFO, "##### protocal is ", verifyprotocal, ", date_name is ", date_name, ", date is ", date)
	-- local ok, timestamp = sp_comm.s3_dateTOtimestamp(verifyprotocal, date, date_name)
	-- if not ok then 
	-- 	ngx.log(ngx.ERR, "Cannot get timestamp from s3_"..verifyprotocal..", original date is "..tostring(date))
	-- 	return false, nil
	-- end

	local timestamp = ngx.parse_http_time(date)
	ngx.log(ngx.INFO, "##### body timestamp is ", ngx.parse_http_time(date))

	local bodytime = tonumber(timestamp)
	local nowtime = os.time()
	ngx.log(ngx.INFO, "##### now timestamp is ", nowtime)
	local difftime = nowtime - bodytime
	ngx.log(ngx.INFO, "##### difftime is ", difftime)

	local allowtimediff = sp_conf.config[verifyprotocal .. "_timediff"] * 60
	ngx.log(ngx.INFO, "##### allowtimediff to ", verifyprotocal .. "_timediff is ", allowtimediff)

	if nil == allowtimediff then
		ngx.log(ngx.ERR, "Cannot get " .. verifyprotocal .. "_timediff from storageproxy_conf.config")
		return false, nil
	end

    if difftime > allowtimediff or difftime < -allowtimediff then
        ngx.log(ngx.ERR, "Current request invalid, s3_", verifyprotocal, "require request didn't later current time than ", allowtimediff, "s")
        return false, nil
    end
	ngx.log(ngx.INFO, "##### Current request is in valid time gap")
    return true, timestamp
end

local function _retrieve_S3_info(authorization_info, s3_protocal_type, is_auth_args)
	ngx.log(ngx.INFO, "##### Enter _retrieve_S3_info")
	
	local accessinfo = {}
	if "aws2" == s3_protocal_type then
		if not is_auth_args then
			ngx.log(ngx.INFO, "##### aws2_and authorization in header is string")
			--authorization_info is a string
			--AKIAIOSFODNN7EXAMPLE:frJIUN8DYpKDtOLCwo//yllqDzg=
			-- local from, to, err = string.find(authorization_info, "\\s*:\\s*")
			-- if nil ~= from then
			-- 	accessinfo["AWSAccessKeyId"] = string.sub(authorization_info, 1, from-1)
			-- 	accessinfo["original_signature"] = string.sub(authorization_info, spe+1, string.len(authorization_info))
			-- 	ngx.log(ngx.INFO, "##### find---accessinfo[\"AWSAccessKeyId\"] is ", accessinfo["AWSAccessKeyId"])
			-- 	ngx.log(ngx.INFO, "##### find---accessinfo[\"original_signature\"] is ", accessinfo["original_signature"])
			-- else
			-- 	if err then
			-- 		ngx.log(ngx.ERR, "Faile ngx.re.find info from header[\"Authorization\"], err is ", err)
			-- 	else
			-- 		ngx.log(ngx.ERR, "Faile find info from header[\"Authorization\"]")
			-- 	end
			-- end

			local cp, err = ngx.re.match(authorization_info, "(\\S+)\\s*:\\s*(\\S+)", "jo")
			if nil ~= next(cp) then
				ngx.log(ngx.INFO, "##### match---accessinfo[\"AWSAccessKeyId\"] is ", cp[1])
				ngx.log(ngx.INFO, "##### match---accessinfo[\"original_signature\"] is ", cp[2])
				accessinfo["AWSAccessKeyId"] = cp[1]
				accessinfo["original_signature"] = cp[2]
			else
				if err then
					ngx.log(ngx.ERR, "Faile ngx.re.match info from header[\"Authorization\"], err is ", err)
				else
					ngx.log(ngx.ERR, "Faile find info from header[\"Authorization\"]")
				end
			end
		else
			ngx.log(ngx.INFO, "##### aws2_and authorization in args is table")
			----authorization_info is a table
			--AWSAccessKeyId=AKIAIOSFODNN7EXAMPLE&Expires=1141889120&Signature=vjbyPxybdZaNmGa%2ByT272YEAiv4%3D
			accessinfo["AWSAccessKeyId"] = authorization_info["AWSAccessKeyId"]
			accessinfo["original_signature"] = authorization_info["Signature"]
			accessinfo["Expires"] = authorization_info["Expires"]
		end
	elseif "aws4" == s3_protocal_type then
		if not is_auth_args then
			ngx.log(ngx.INFO, "##### aws4_and authorization in header is string")
			--authorization_info is a string
			--Credential=AKIDEXAMPLE/20150830/us-east-1/iam/aws4_request, SignedHeaders=content-type;host;x-amz-date, Signature=5d672d79c15b13162d9279b0855cfba6789a8edb4c82c400e06b5924a6f2b5d7
			local cp, err = ngx.re.match(authorization_info, "^Credential=(\\w+)(\\S+),\\s*SignedHeaders=(\\S+),\\s*Signature=(\\S+)", "jo")
			if nil ~= next(cp) then
				ngx.log(ngx.INFO, "##### match---accessinfo[\"AWSAccessKeyId\"] is ", cp[1])
				ngx.log(ngx.INFO, "##### match---accessinfo[\"surplus_Credential\"] is ", cp[2])
				ngx.log(ngx.INFO, "##### match---accessinfo[\"SignedHeaders\"] is ", cp[3])
				ngx.log(ngx.INFO, "##### match---accessinfo[\"original_signature\"] is ", cp[4])
				accessinfo["AWSAccessKeyId"] = cp[1]
				accessinfo["surplus_Credential"] = cp[2]
				accessinfo["SignedHeaders"] = cp[3]
				accessinfo["original_signature"] = cp[4]
			else
				if err then
					ngx.log(ngx.ERR, "Faile ngx.re.match info from header[\"Authorization\"], err is ", err)
				else
					ngx.log(ngx.ERR, "Faile find info from header[\"Authorization\"]")
				end
			end			
		else
			ngx.log(ngx.INFO, "##### aws4_and authorization in args is table")
			----authorization_info is a table
			--Action=ListUsers&Version=2010-05-08&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIDEXAMPLE%2F20150830%2Fus-east-1%2Fiam%2Faws4_request&X-Amz-Date=20150830T123600Z&X-Amz-Expires=60&X-Amz-SignedHeaders=content-type%3Bhost&X-Amz-Signature=37ac2f4fde00b0ac9bd9eadeb459b1bbee224158d66e7ae5fcadb70b2d181d02
			accessinfo["Action"] = authorization_info["Action"]
			accessinfo["Version"] = authorization_info["Version"]
			accessinfo["Date"] = authorization_info["X-Amz-Date"]
			accessinfo["Expires"] = authorization_info["X-Amz-Expires"]

			accessinfo["SignedHeaders"] = authorization_info["X-Amz-SignedHeaders"]
			accessinfo["original_signature"] = authorization_info["X-Amz-Signature"]

			local credential = authorization_info["X-Amz-Credential"]
			local from, to = string.find(credential, '/')
			accessinfo["AWSAccessKeyId"] = string.sub(credential, 1, from-1)
			accessinfo["surplus_Credential"] = string.sub(credential, to)
		end
	--else
	end

	return accessinfo
end

local function _check_msg(args, body, is_auth_args)
	ngx.log(ngx.INFO, "##### Enter _retrieve_S3_info")
	-- body
	if nil ~= body then
		ngx.log(ngx.INFO, "##### body is not nil, check body parameter")
		local ok, jbody = pcall(json.decode, body)
	    if not ok or type(jbody)~="table" then
	        ngx.log(ngx.ERR, "request body error. body is " ..  tostring(body))
	        return false
	    end

	    _M.body = jbody
	end
	--args
	if nil ~= next(args) then
		ngx.log(ngx.INFO, "##### args is not nil, process args parameter")
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

	return true
end

function _get_request_info(method, uri, headers, sub_request_uri)
	ngx.log(ngx.INFO, "##### Enter _get_request_info")
--ÇëÇóµÄ¼¸ÖÖÐÎÊ½
--bucket\objectÐÅÏ¢ÔÚuriÖÐ
-- "/" -- list bucket
-- "/bucket{?optype}" --bucket op
-- "/bucket/object{?optype}" --object op
--ÈôbucketnameÔÚhostÖÐ, ÏÂÊö²Ù×÷ÊÇ·ñÕýÈ·ÐèÒªºóÆÚÑéÖ¤
-- "/" -- list bucket
-- "{?optype}" --bucket op 
-- "/object{?optype}" or ???--object op
	local api_access_mode = "from uri" --Ä¬ÈÏÖµ
	local bucketname, objectname = ""
	local GET_Service = false

	--Ê×ÏÈÈ·ÈÏS3½Ó¿ÚÊ¹ÓÃµÄ½ÓÈëÄ£Ê½
	local host = headers["Host"]
	if nil == host then
		return false
	end

	local from, to, err = ngx.re.find(host, sp_conf.config["default_hostdomain"], "jo")
	if nil ~= from then
		if 1 ~= from then
			api_access_mode = "from host"
			bucketname = string.sub(host, 1, from-2)
		else
			ngx.log(ngx.INFO, "Current reqest's bucketname may in uri_args")
		end
	else
		if err then
			ngx.log(ngx.ERR, "Failed find bucketname from headers[\"Host\"], and err is ", err)
			return false
		else
			ngx.log(ngx.INFO, "##### Current reqest's host: ", headers["Host"], " isn't excepted host")
		end
	end

    --È·ÈÏµ±Ç°requestµÄÀàÐÍ
	local splittab = comm.strsplit(sub_request_uri, "/")
	for i,v in ipairs(splittab) do
		ngx.log(ngx.INFO, "sub_request_uri split to ", i .. ":" .. v)
	end
	local len_splittab= #splittab
	print("@@@@@@@@@@@@@@@@:", len_splittab)
	if 1 == len_splittab then
		objectname = splittab[1]
	elseif 2 == len_splittab then
		-- if "" == splittab[2] then
		-- 	print("it is a empty string")
		-- elseif nil == splittab[2] then
		-- 	print("it is a empty string")
		-- elseif " " == splittab[2] then
		-- 	print("it is a block")
		-- else
		-- 	print("splittab[2] is ", splittab[2])
		-- end
		if "" == splittab[2] and "GET" == method then
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

	if GET_Service then
		ngx.log(ngx.INFO, "##### this request is GET_Service")
	else
		if objectname then
			ngx.log(ngx.INFO, "##### this request is ", method, "_Object")
			s3_option = "s3_object_option"
		else
			if bucketname then
				ngx.log(ngx.INFO, "##### this request is ", method, "_Bucket")
				s3_option = "s3_bucket_option"
			else
				ngx.log(ngx.ERR, "Failed find bucketname from sub_request_uri：", sub_request_uri)
				return false
			end
		end

		if next(_M.uri_args) then
			for k,v in pairs(_M.uri_args) do
				for i2,v2 in ipairs(sp_conf.config[s3_option]) do
					if v2 == _M.uri_args[1] then
						operationtype = v
						break
					end
				end
			end
		end
	end

	ngx.log(ngx.INFO, "##### s3_option is ", s3_option)
	ngx.log(ngx.INFO, "##### operationtype is ", operationtype)

	_M.baseinfo["service"] = GET_Service
	_M.baseinfo["bucketname"] = bucketname
	_M.baseinfo["objectname"] = objectname
	_M.baseinfo["operationtype"] = operationtype
	_M.baseinfo["method"] = method
	_M.baseinfo["uri"] = uri
	_M.baseinfo["headers"] = headers
	_M.baseinfo["sub_request_uri"] = sub_request_uri
	_M.baseinfo["api_access_mode"] = api_access_mode

	return true
end

local function _get_AWS2_CanonicalizedResource()
	local crinit, cruri, crop
    if "from host" == _M.baseinfo["api_access_mode"] then
    	crinit = "/" .. _M.baseinfo["bucketname"]
    	cruri = crinit .. _M.baseinfo["sub_request_uri"]
    else
    	crinit = ""
		cruri = _M.baseinfo["sub_request_uri"]
    end

    if _M.baseinfo["service"] then
    	cruri = "/"
    end

    if next(_M.uri_args) then
    	ngxprint.normalprint(_M.uri_args)

    	crop="?"
	    for i,v in ipairs(_M.uri_args) do
	    	if "?" == crop then
	    		crop = crop + v
	    	else
	    		crop = crop + "&" + v
	    	end
	    end
	end
    ngx.log(ngx.INFO, "##### crinit is ", crinit)
    ngx.log(ngx.INFO, "##### cruri is ", cruri)
    ngx.log(ngx.INFO, "##### crop is ", crop)

	if crop then
		return crinit .. cruri .. crop
	else
		return crinit .. cruri
	end
end

local function _header_format(headerinfo, header)
	ngx.log(ngx.INFO, "##### Enter _header_format----", header)
	local format_header
	if "table" == type(headerinfo) then
		local tmpstr = headerinfo[1]
		for i,v in pairs(headerinfo) do
			if 1 ~=i then
				tmpstr = tmpstr .. v
			end
			if i ~= #headerinfo then
				tmpstr = tmpstr .. ","
			end
		end
		format_header = header .. ":" .. tmpstr
	else
		format_header = header ..":"..headerinfo
	end

	ngx.log(ngx.INFO, "##### This format_header is ", format_header)
	return format_header
end

function _get_AWS2_CanonicalizedAmzHeaders()
	-- since we use ngx.req.get_headers to get header, this api has convert every header to lowercase
	-- and combine same header's value to one table
	local tmptable = _M.baseinfo["headers"]
	local headertable = {}
	for k,v in pairs(tmptable) do
		if type(v) == "table" then
			ngx.log(ngx.INFO, "##### ", k, ": ", table.concat(v, ", "))
		else
			ngx.log(ngx.INFO, "##### ", k, ": ", v)
		end
		if ngx.re.find(k, "x-amz-\\S") then
			table.insert(headertable, k)
		end
	end

	print("###############before##################")
	ngxprint.normalprint(headertable)
	table.sort(headertable)
	print("###############after##################")
	ngxprint.normalprint(headertable)

	local CanonicalizedAmzHeaders = _header_format(tmptable[headertable[1]], headertable[1])
	for i,v in ipairs(headertable) do
		if 1 ~= i then
			CanonicalizedAmzHeaders = CanonicalizedAmzHeaders .. _header_format(tmptable[v], v)
		end
		CanonicalizedAmzHeaders = CanonicalizedAmzHeaders .. '\n'
	end

	return CanonicalizedAmzHeaders	
end

local function _get_AWS2_StringToSign()
	ngx.log(ngx.INFO, "##### _M.baseinfo[\"api_access_mode\"] is ", _M.baseinfo["api_access_mode"])
    ngx.log(ngx.INFO, "##### _M.baseinfo[\"bucketname\"] is ", _M.baseinfo["bucketname"])
    ngx.log(ngx.INFO, "##### _M.baseinfo[\"sub_request_uri\"] is ", _M.baseinfo["sub_request_uri"])
    ngx.log(ngx.INFO, "##### _M.baseinfo[\"GET_Service\"] is ", tostring(_M.baseinfo["service"]))

    local CanonicalizedResource = _get_AWS2_CanonicalizedResource()
	ngx.log(ngx.INFO, "##### CanonicalizedResource is ", CanonicalizedResource)

	local CanonicalizedAmzHeaders = _get_AWS2_CanonicalizedAmzHeaders()
	ngx.log(ngx.INFO, "##### CanonicalizedAmzHeaders is ", CanonicalizedAmzHeaders)

	local content_md5
	if nil ~= _M.baseinfo["headers"]["Content-MD5"] then
		ngx.log(ngx.INFO, "##### headers[\"Content-MD5\"] is ", _M.baseinfo["headers"]["Content-MD5"])
		content_md5 = _M.headers["Content-MD5"] + "\n"
	else
		content_md5 = "\n"
	end

	local content_type
	if nil ~= _M.baseinfo["headers"]["Content-Type"] then
		ngx.log(ngx.INFO, "##### headers[\"Content-Type\"] is ", _M.baseinfo["headers"]["Content-Type"])
		content_type = _M.headers["Content-Type"] + "\n"
	else
		content_type = "\n"
	end

	local sign = 1 StringToSign = _M.baseinfo["method"] .. "\n" ..  content_md5 .. content_type .. _M.baseinfo["headers"][AWSAccessInfo["original_date_name"]] .. "\n" .. CanonicalizedAmzHeaders .. CanonicalizedResource
	return sign
end

local function _AWS2_authorization()
	local StringToSign = _get_AWS2_StringToSign()
	ngx.log(ngx.INFO, "##### StringToSign is ", StringToSign)

	local digest = ngx.hmac_sha1(AWSAccessInfo["AWS_SecretAccessKey"], StringToSign)
	local new_signature = ngx.encode_base64(digest)
	ngx.log(ngx.INFO, "##### new_signature is ", new_signature)

	ngx.log(ngx.INFO, "##### original_signature is ", AWSAccessInfo["accessdetails"]["original_signature"])
	-- if AWSAccessInfo["accessdetails"]["original_signature"] == new_signature then
	-- 	return 200, "00000000"
	-- else
	-- 	return 404, "10000000" 
	-- end

	return 200, "00000000"
end

local function _start_authorization(verifyprotocal)
	ngx.log(ngx.INFO, "##### Enter _start_authorization(",verifyprotocal,")")
	if "aws2" == verifyprotocal then
		local StringToSign = _get_AWS2_StringToSign()
		ngx.log(ngx.INFO, "##### StringToSign is ", StringToSign)
	
		local digest = ngx.hmac_sha1(AWSAccessInfo["AWS_SecretAccessKey"], StringToSign)
		local new_signature = ngx.encode_base64(digest)
		ngx.log(ngx.INFO, "##### new_signature is ", new_signature)

		ngx.log(ngx.INFO, "##### original_signature is ", AWSAccessInfo["accessdetails"]["original_signature"])
		-- if AWSAccessInfo["accessdetails"]["original_signature"] == new_signature then
		-- 	return 200, "00000000"
		-- else
		-- 	return 404, "10000000" 
		-- end
	elseif "aws4" == verifyprotocal then
		-- if xxxxx then
		-- 	return 200, "00000000"
		-- else
		-- 	return 404, "10000000" 
		-- end
	end

	return 200, "00000000"
end

--
function _M.access_authentication(self, method, uri, args, headers, body, sub_request_uri)
	ngx.log(ngx.INFO, "##### Enter _M.access_authentication")
	ngx.log(ngx.INFO, "##### method is ", method)
	ngx.log(ngx.INFO, "##### uri is ", uri)
	ngx.log(ngx.INFO, "##### body is ", body)
	ngx.log(ngx.INFO, "##### args is   ")
	ngxprint.normalprint(args)
	ngx.log(ngx.INFO, "##### headers is ")
	ngxprint.normalprint(headers)
	ngx.log(ngx.INFO, "##### sub_request_uri is ", sub_request_uri)

    -- preprocess
    ----a) get authorization information
    local verifyprotocal, authorization
    local is_auth_args = false

    if nil ~= headers["Authorization"] then
    	authorization = headers["Authorization"]
    	ngx.log(ngx.INFO, "##### authorization info from headers[\"Authorization\"]")
    elseif nil ~= next(args) then
    	authorization = args
		is_auth_args = true
		ngx.log(ngx.INFO, "##### authorization info from uri args")
    else
		ngx.log(ngx.ERR, "Current request didn't match the protocol format of S3")
		return 201, "20000000"
    end

    AWSAccessInfo["original_Authorization"]  = authorization
    ngx.log(ngx.INFO, "##### authorization is ")
    ngxprint.normalprint(authorization)

    ----b) 
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
    		ngx.log(ngx.INFO, "##### surplus_authorization:", authorization)
    	end
   	end

   	AWSAccessInfo["protocaltype"] = verifyprotocal

   	----c) get date and verify valid request 
    local date, date_name
    if not is_auth_args then
		if nil ~= headers["x-amz-date"] then
			date = headers["x-amz-date"]
			date_name = "x-amz-date"
		elseif nil ~= headers["Date"] then
			date = headers["Date"]
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
    ----
    end
    AWSAccessInfo["original_date_name"] = date_name
    AWSAccessInfo["timestamp"] = timestamp

  	----d)
    local accessinfo = _retrieve_S3_info(authorization, verifyprotocal, is_auth_args)
    if nil == next(accessinfo) then
    	return 201, "20000003" 
	end
	AWSAccessInfo["accessdetails"] = accessinfo

    --2. 获取AWS_SecretAccessKey
    local accessid = AWSAccessInfo["accessdetails"]["AWSAccessKeyId"]
    local ok, dbody = sp_hbaseop:retrieve_AWS_SecretAccessKey(accessid)
    if not ok then
    	return 201, "20000003"
    end
    --AWSAccessInfo["AWS_SecretAccessKey"] = dbody[accessid]["secretkey"]
    AWSAccessInfo["AWS_SecretAccessKey"] = dbody[accessid]["secretkey:"]
    _M.AWS_userinfo = dbody[accessid]

    print("######AWSAccessInfo is #######")
    ngxprint.normalprint(AWSAccessInfo)

    --3. _retrieve_S3_info
    local ok = _check_msg(args, body, is_auth_args)
    if not ok then
    	return 201, "20000007"
    end

    --4. 
    local ok = _get_request_info(method, uri, headers, sub_request_uri)
	if not ok then
    	return 201, "20000007"
    end

    --5. 
    local status, code = _start_authorization(verifyprotocal) 
    return status, code
end

return _M
