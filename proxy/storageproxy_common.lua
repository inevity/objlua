--[[
存储代理公共函数处理模块v1
Author:      杨婷
Mail:        yangting@dnion.com
Version:     1.0
Doc:
Modify：
    2016-07-19  杨婷  初始版本
]]

local _M = {
    _VERSION = '1.00',
}

function _M.s3_dateTOtimestamp(self, protocaltype, date, date_name)
    local timestamp

    if "aws2" == protocaltype then
        if "Date" == date_name then
           timestamp = ngx.parse_http_time(date)
        elseif "x-amz-date" == date_name then
            timestamp = ngx.parse_http_time(date)
        end
    elseif "aws4" == protocaltype then
        if "Date" == date_name then
           timestamp = ngx.parse_http_time(date)
        elseif "x-amz-date" == date_name then
            timestamp = ngx.parse_http_time(date)
        end
    end

    return true, timestamp
end

return _M