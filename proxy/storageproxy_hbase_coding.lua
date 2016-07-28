--[[
hbase编解码模块v1
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
local ngxprint = require("printinfo")

function _M.base64_decode(self, jbody)
	ngx.log(ngx.INFO, "##### Enter sbase64_decode")
	if nil == jbody then
		return false, nil
	end
	ngx.log(ngx.INFO, "###############before_decode body##################")
	ngxprint.normalprint(jbody)
	ngx.log(ngx.INFO, "###############before_decode body##################")

	local decode_table = {}

	--jbody is a table
	for k,v in pairs(jbody) do
		if "Row" == k then
			--v is a array
			for i2,v2 in ipairs(v) do
				--v2 is a table
				if type(v2)~= "table" then
					return false, nil
				else
					if nil == v2["key"] then
						return false, nil
					end
					if nil == v2["Cell"] and "table" ~= type(v2["Cell"]) then
						return false, nil
					end
				end
				
				----analyse v2["Cell"] and it is a array
				local table3 = {}
				for i3,v3 in pairs(v2["Cell"]) do
					--v3 is a table,have elments for("column"\"$"\timestamp)
					if nil == v3["column"] or nil == v3["$"] or nil == v3["timestamp"] then
						return false, nil
					end

					local rowkey_columnname = ngx.decode_base64(v3["column"])
					local rowkey_columnname_timestamp = rowkey_columnname .. "_timestamp"
					table3[rowkey_columnname] = ngx.decode_base64(v3["$"])
					table3[rowkey_columnname_timestamp] = v3["timestamp"]
				end

				----analyse v2["key"]
				decode_table[ngx.decode_base64(v2["key"])] = table3
			end
		else
			ngx.log(ngx.ERR, "would-be decodebody has exceptional key is ", k)
			return false, nil
		end
	end

	ngx.log(ngx.INFO, "###############after decode_table##################")
	ngxprint.normalprint(decode_table)
	ngx.log(ngx.INFO, "###############after decode_table##################")

	return true, decode_table
end

function _M.base64_encode(self, op_ob, body)
	ngx.log(ngx.INFO, "##### Enter base64_encode")
	if nil == body then
		return false, nil
	end
	ngx.log(ngx.INFO, "###############before_encode body##################")
	ngxprint.normalprint(body)
	ngx.log(ngx.INFO, "###############before_encode body##################")
	
	local encode_table = {
		Row = {}
	}
	local table1 = {}
	
	table1["Cell"] = {}
	if "bucket" == op_ob then
		if nil == body["uid:"] or nil == body["bucketname"] then
			return false, nil
		end

		table1["key"] = ngx.encode_base64(body["uid:"] .. "_" .. body["bucketname"])
		
		for k2, v2 in pairs(body["bucketinfo"]) do
			local table2 = {}
			table2["column"] =  ngx.encode_base64(k2)
			table2["$"] = ngx.encode_base64(v2)
			table.insert(table1["Cell"], table2)
		end		
	-- elseif "object" == op_ob then
	-- 	table1["key"] = ngx.encode_base64(body["objectname"])

	-- 	for k2, v2 in pairs(body["objectinfo"]) do
	-- 		local table2 = {}
	-- 		table2["column"] =  ngx.encode_base64(k2)
	-- 		table2["$"] = ngx.encode_base64(v2)
	-- 		table.insert(table1["Cell"], table2)
	-- 	end
	-- else
	end
	table.insert(encode_table["Row"], table1)

	ngx.log(ngx.INFO, "###############after encode_table##################")
	ngxprint.normalprint(encode_table)
	ngx.log(ngx.INFO, "###############after encode_table##################")

	return true, encode_table
end

return _M