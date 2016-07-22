--[[

Author:      
Mail:        yangting@dnion.com
Version:     1.0
Doc:
Modify
    2016-07-19
]]
local _M = {
    _VERSION = '0.01',
}

local json = require('cjson')
local http = require "resty.http"
local ngxprint = require("printinfo")
local sp_conf = require("storageproxy_conf")
local hbase_uri = "http://" .. sp_conf.config["hbase_config"]["server"] .. ":" .. sp_conf.config["hbase_config"]["port"]

local function _base64_decode(jbody)
	ngx.log(ngx.INFO, "##### Enter _base64_decode")
	-- print("###############before##################")
	-- ngxprint.normalprint(jbody)
	-- print("###############before##################")

	local decode_table = {}
	local counter = 0
	local res = false
	--jbody is a tables
	for k,v in pairs(jbody) do
		if "Row" == k then
			--v is a array
			for i2,v2 in ipairs(v) do
				--v2 is a table
				if type(v2)~= "table" then
					return res
				else
					if nil == v2["key"] then
						return res
					end

					if nil == v2["Cell"] and "table" ~= type(v2["Cell"]) then
						return res
					end
				end
				-- ngx.log(ngx.INFO, "v2[\"key\"] is a ", v2["key"], " and after decode is ", ngx.decode_base64(v2["key"]))
				----analyse v2["Cell"] and it is a array
				local table3 = {}
				for i3,v3 in pairs(v2["Cell"]) do
					if nil == v3["column"] or nil == v3["column"] or nil == v3["timestamp"] then
						return res, nil
					end
					-- for k4, v4 in pairs(v3) do
					-- 	ngx.log(ngx.INFO, "###### k4 is ", k4, " and v4 is ", v4)
					-- 	if "timestamp" ~= k4 then
					-- 		ngx.log(ngx.INFO, "###### v4 decode is ", ngx.decode_base64(v4))
					-- 	end
					-- end
					--v3 is a table,have elments for("column"\"$"\timestamp)
					local rowkey_columnname = ngx.decode_base64(v3["column"])
					local rowkey_columnname_timestamp = rowkey_columnname .. "_timestamp"
					table3[rowkey_columnname] = ngx.decode_base64(v3["$"])
					table3[rowkey_columnname_timestamp] = v3["timestamp"]
				end
				----analyse v2["key"]
				decode_table[ngx.decode_base64(v2["key"])] = table3
				counter = counter + 1
			end
		else
			ngx.log(ngx.ERR, "would-be decodebody has exceptional key is ", k)
			return false, nil
		end
	end
	return true, decode_table
end

--local
function hbase_put(API_uri, headers, body)
    local httpc = http.new()
    httpc:set_timeout(sp_conf.config["hbase_config"]["request_timeout"])

    local requesturi = hbase_uri .. API_uri

    local res, err = httpc:request_uri(
        requesturi,
        {
            method="PUT",
            headers={
                ["Accept"] = "application/json",
            },
        }
    )

  --   if nil == err then
  --       ngx.log(ngx.ERR, "Received a nil response from : ", url, "; when send HTTP_GET_Request to hbase")
  --       return false, nil
  --   elseif res == nil then
  --       ngx.log(ngx.ERR, "Received a nil response from : ", url, "; when send HTTP_GET_Request to hbase")
  --       return false, nil
  --   else
  --   	local ok, jbody = pcall(json.decode, res.body)
		-- if not ok or type(jbody)~="table" then
	 --    	ngx.log(ngx.ERR, "Response body error. body is ", tostring(body), "; when send HTTP_GET_Request to hbase")
	 --   		return false, nil
		-- end

		-- _hbaseop.base64_decode(jbody)
  --   	return true, dbody
  --   end
end
--_M.hbase_put = _hbase_put

--local
function _hbase_get(API_uri, headers, body)
	ngx.log(ngx.INFO, "##### Enter hbase_get and API_uri is ", API_uri)
	-- ngx.log(ngx.INFO, "##### input headers is ")
	-- ngxprint.normalprint(headers)
	-- ngx.log(ngx.INFO, "##### input body is ", body)

    local httpc = http.new()
    httpc:set_timeout(sp_conf.config["hbase_config"]["request_timeout"])

    local requesturi = hbase_uri .. API_uri
    ngx.log(ngx.INFO, "##### Final http_request's uri is ", requesturi, " and http timeout is ", sp_conf.config["hbase_config"]["request_timeout"])

    local res, err = httpc:request_uri(
        requesturi,
        {
            method="GET",
            headers={
                ["Accept"] = "application/json",
            },
        }
    )

    if nil ~= err then
        ngx.log(ngx.ERR, "Received a err response from : ", requesturi, " when send HTTP_GET_Request to hbase, and err is ")
        return false, nil
    end
    
    if nil == res then
        ngx.log(ngx.ERR, "Received a nil response from : ", requesturi, "; when send HTTP_GET_Request to hbase")
        return false, nil
    else
    	ngx.log(ngx.INFO, "##### Received a response body is ", res.body)
    	local ok, jbody = pcall(json.decode, res.body)
		if not ok or type(jbody)~="table" then
	    	ngx.log(ngx.ERR, "Response body error. body is ", tostring(body), "; when send HTTP_GET_Request to hbase")
	   		return false, nil
		end
		
		local ok, dbody = _base64_decode(jbody)
		if not ok then
			ngx.log(ngx.ERR, "invoke _base64_decode to process failed")
			return false, nil
		end

		-- if API_uri == "/bucket/test*" then
		-- 	local a = [[
		-- 		{"Row":[{"key":"dGVzdF9idWNrZXQy","Cell":[{"column":"Y3JlYXRlZGF0ZTo=","timestamp":1468308380626,"$":"MjAxNi0wNy0xMlQxNjo0MTo1OC4wMDBa"},{"column":"cXVvdGE6bWF4X2ZpbGVz","timestamp":1468308380626,"$":"LTE="},{"column":"cXVvdGE6bWF4X3NpemU=","timestamp":1468308380626,"$":"LTE="},{"column":"c3RhdDpjdXJfZmlsZXM=","timestamp":1468308380626,"$":"MA=="},{"column":"c3RhdDpjdXJfc2l6ZQ==","timestamp":1468308380626,"$":"MA=="}]},{"key":"dGVzdF90ZXN0YnVja2V0","Cell":[{"column":"cXVvdGE6bWF4X2ZpbGVz","timestamp":1468291966015,"$":"LTE="},{"column":"cXVvdGE6bWF4X3NpemU=","timestamp":1468291966015,"$":"LTE="},{"column":"c3RhdDpjdXJfZmlsZXM=","timestamp":1468291966015,"$":"MA=="},{"column":"c3RhdDpjdXJfc2l6ZQ==","timestamp":1468291966015,"$":"MA=="}]}]}
		--     ]]

  --   		local ok, b = pcall(json.decode, a)
		-- 	local ok, c = _base64_decode(b)
		-- 	return true, c
		-- end

    	return true, dbody
    end
end
_M.hbase_get = _hbase_get

--decode_table type
--[[
userinfo = [
	accessid = {
		uid = uid, 
		secretkey = .. £¬
		quota[max_files,max_size] = ..£¬
		stat[cur_files,cur_size] = .. ,
		uid_timestamp = uid_timestamp
		...
		...
		...
	}
]

bucketinfo = [
	uid_bucketname1 = {
		"createdate" = "2016-07-12T16:41:58.000Z"
		"createdate_timestamp" = 1468308380626
		quota[max_files,max_size] = ..£¬
		stat[cur_files,cur_size] = .. ,
		..
		..
	},
	uid_bucketname2 = {

	},
	......
]
]]

function _M.retrieve_AWS_SecretAccessKey(self, accessid)
	ngx.log(ngx.INFO, "##### Enter retrieve_AWS_SecretAccessKey and accessid is ", accessid)

	local API_uri = "/user/" .. accessid .."/"

	local ok, res = _hbase_get(API_uri)
	if not ok then
		return ok, nil
	end

	return true, res
end

return _M