--[[
hbase_post 接口模块 v1
Author:      杨婷
Mail:        yangting@dnion.com
Version:     1.0
Doc:
Modify:
    2016-07-19  杨婷  初始版本
]]

local _M = {
    _VERSION = '0.01',
}

local json = require('cjson')
local http = require "resty.http"
local ngxprint = require("printinfo")

local sp_conf = require("storageproxy_conf")
local hbase_uri = "http://" .. sp_conf.config["hbase_config"]["server"] .. ":" .. sp_conf.config["hbase_config"]["port"]
local hbasecoding = require("storageproxy_hbase_coding")

function _M.SendtoHbase(self, API_uri, op_ob, headers, body)
	ngx.log(ngx.INFO, "##### Enter hbase_get and API_uri is ", API_uri, " and op_ob is ", op_ob)
	-- ngx.log(ngx.INFO, "##### input headers is ")
	-- ngxprint.normalprint(headers)
	-- ngx.log(ngx.INFO, "##### input body is ", body)
	-- ngxprint.normalprint(body)
	
	--according to the demands of hbase_get_request to process request_URI
	local requesturi = hbase_uri .. API_uri
    ngx.log(ngx.INFO, "##### Final http_request's uri is ", requesturi, " and http timeout is ", sp_conf.config["hbase_config"]["request_timeout"])

    --according to the demands of hbase_get_request to process request_body
	local ok, ebody = hbasecoding:base64_encode(op_ob, body)
	if not ok then
		ngx.log(ngx.ERR, "Failed to invoke hbasecoding:_base64_encode to process body")
		return 503, false, nil
	end
	local ok, jbody = pcall(json.encode, ebody)
	if not ok or type(jbody)~="string" then
    	ngx.log(ngx.ERR, "Request body error when invoke json.encode; when send HTTP_GET_Request to hbase")
   		return 503, false, nil
	end	
	ngx.log(ngx.INFO, "##### http_hbase_post's request_body is ", jbody)

	--according to the demands of hbase_get_request to process request_header
    local request_header = {
        ["Accept"] = "application/json",
        ["Content-Type"] = "application/json",
    }

	--build http_connection
    local httpc = http.new()
    httpc:set_timeout(sp_conf.config["hbase_config"]["request_timeout"])

    local res, err = httpc:request_uri(
        requesturi,
        {
            method="POST",
            headers=request_header,
            body=jbody,
        }
    )

    if nil ~= err then
        ngx.log(ngx.ERR, "Received a nil response from : ", url, "; when send HTTP_PUT_Request to hbase")
        return 503, false, nil
 	end	
  	
  	if nil == res then
        ngx.log(ngx.ERR, "Received a nil response from : ", url, "; when send HTTP_PUT_Request to hbase")
        return 503, false, nil
    else
		ngx.log(ngx.INFO, "##### Received a response body is ", res.body)
		if nil == res.body or "" == res.body then
			return res.status, true, nil
		else
	    	local ok, jbody = pcall(json.decode, res.body)
			if not ok or type(jbody)~="table" then
		    	ngx.log(ngx.ERR, "Response body error when invoke json.decode. body is ", tostring(body), "; when send HTTP_PUT_Request to hbase")
		   		return res.status, false, nil
			end
		end

		local ok, dbody = hbasecoding:base64_decode(jbody)
		if not ok then
			ngx.log(ngx.ERR, "Failed to invoke hbasecoding:base64_decode to process jbody")
			return res.status, false, nil
		end

    	return res.status, true, dbody
    end
end

return _M