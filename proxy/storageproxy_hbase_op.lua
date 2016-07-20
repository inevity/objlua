--[[
hbase接口处理逻辑v1
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



local json = require('cjson')
local http = require "resty.http"


local sp_conf = require("storeproxy_conf")
local hbase_conf = sp_conf.hbase_config
local hbase_uri = 'http://' .. hbase_conf["server"] .. ":" hbase_conf["port"]


local function _hbase_get(API_uri, headers, body)
    local httpc = http.new()
    httpc:set_timeout(hbase_conf["request_timeout"])

    local requesturi = hbase_uri .. API_uri

    local res, err = httpc:request_uri(
        requesturi,
        {
            method="GET",
            headers={
                ["Accept"] = "application/json",
            },
        }
    )

    if nil == err then
        ngx.log(ngx.ERR, "Received a nil response from : ", url, "; when send HTTP_GET_Request to hbase")
        return false, nil
    elseif res == nil then
        ngx.log(ngx.ERR, "Received a nil response from : ", url, "; when send HTTP_GET_Request to hbase")
        return false, nil
    else
    	return true, res
    end
end
_M.hbase_get = _hbase_get

function retrieve_AWS_SecretAccessKey(self, AWSAccessKeyId)
	local API_uri = "/user/" .. AWSAccessKeyId .."/"

	local ok, res = _hbase_get(API_uri)
	if not ok then
		return ok, nil
	end

	local ok, jbody = pcall(json.decode, res.body)
	if not ok or type(jbody)~="table" then
    	ngx.log(ngx.ERR, "Response body error. body is ", tostring(body), "; when send HTTP_GET_Request to hbase")
   		return ok, nil
	end

	return true, jbody
end

return _M