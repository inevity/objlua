--[[

]]

local _M = {
    _VERSION = '1.00',
}

local i = 0

function _printtable(table_name)
	i = i + 1
	for k,v in pairs(table_name) do
		if type(v) == "table" then
			if 3 >= i then
				print(k, ":", table.concat(v, ", "))
			else
				print(k .. ", but v is table")
				_printtable(v)
			end
		else
			print(k .. " : " .. v)
		end
	end
end

function _M.normalprint(self, printinfo)
	local typestr = type(printinfo)

	if typestr == "table" then
		print("printinfo is a ", typestr)
		_printtable(printinfo)
	elseif typestr == "string" or typestr == "number" or nil == printinfo then
		print(printinfo, " and its type is ", typestr)
	elseif typestr == "boolean" then
		print(tostring(printinfo))
	else
		print("Error invoke printinfo: " .. tostring(printinfo))
	end
end


function _ngx_printtable(table_name)
	local tablestr
	for k,v in pairs(table_name) do
		if type(v) == "table" then
			local str = _ngx_printtable(v)
			tablestr = tablestr .."(" .. k .. ": (" .. str .. ");"
		else
			tablestr = tablestr .. "(" .. k .. ": " .. v .. ");"
		end
	end

	return tablestr
end

function _M.ngxprint(self, printinfo)
	local typestr = type(printinfo)

	if typestr == "table" then
		return _ngx_printtable(printinfo)
	elseif typestr == "string" or typestr == "number" or nil == printinfo then
		return printinfo .. "its type is " .. typestr
	elseif typestr == "boolean" then
		return tostring(printinfo) .. "its type is " .. typestr
	else
		return "Error invoke printinfo: " .. tostring(printinfo)
	end
end

return _M