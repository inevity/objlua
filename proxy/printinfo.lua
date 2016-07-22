--[[

]]

local _M = {
    _VERSION = '1.00',
}

function _printtable(table_name)
    for k,v in pairs(table_name) do    	
		if type(v) == "table" then	
			ngx.log(ngx.INFO, "k is " .. k .. " and v is a table")
			for k1,v1 in pairs(v) do				
				if type(v1) == "table" then
					ngx.log(ngx.INFO, "k1 is " .. k1 .. " and v1 is a table")
					for k2,v2 in pairs(v1) do
						if type(v2) == "table" then
							ngx.log(ngx.INFO, "k2 is " .. k2 .. " and v2 is a table")
							for k3,v3 in pairs(v2) do								
								if type(v3) == "table" then
									ngx.log(ngx.INFO, "k3 is " .. k3 .. " and v3 is a table")
									for k4,v4 in pairs(v3) do
										if type(v4) == "table" then
											ngx.log(ngx.INFO, "k4 is " .. k5 .. " and v4 is a table")
											for k5,v5 in pairs(v4) do
												if type(v5) == "table" then
													ngx.log(ngx.INFO, "k5 is " .. k5 .. " and v5 is a table")
												else
													ngx.log(ngx.INFO, "k5 is " .. k5 .. " : " .. tostring(v5))
												end
											end
										else
											ngx.log(ngx.INFO, "k4 is " .. k4 .. " : " .. tostring(v4))
										end
									end
								else
									ngx.log(ngx.INFO, "k3 is " .. k3 .. " : " .. tostring(v3))
								end
							end
						else
							ngx.log(ngx.INFO, "k2 is " .. k2 .. " : " .. tostring(v2))
						end
					end
				else
					ngx.log(ngx.INFO, "k1 is " .. k1 .. " : " .. tostring(v1))
				end
			end
		else
			ngx.log(ngx.INFO, "k is " .. k .. " : " .. tostring(v))
		end
	end
end

function _normalprint(printinfo)
	if nil == printinfo then
		ngx.log(ngx.INFO, "printinfo is nil")
	end
	local typestr = type(printinfo)

	if typestr == "table" then
		if nil == next(printinfo) then
			ngx.log(ngx.INFO, "printinfo is a empty table")
		else
			ngx.log(ngx.INFO, "printinfo is a ", typestr)
			_printtable(printinfo)
		end
	elseif typestr == "string" or typestr == "number"then
		ngx.log(ngx.INFO, "printinfo is " .. printinfo .. "and type is " .. typestr)
	elseif typestr == "boolean" then
		ngx.log(ngx.INFO, "printinfo is " .. tostring(printinfo))
	else
		ngx.log(ngx.INFO, "Error invoke printinfo: " .. tostring(printinfo))
	end

	return
end
_M.normalprint = _normalprint

return _M