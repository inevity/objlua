-- By Yuanguo, 22/7/2016

local ok, new_tab = pcall(require, "table.new")
if not ok or type(new_tab) ~= "function" then
    new_tab = function (narr, nrec) return {} end
end

local _M = new_tab(0, 16)
_M._VERSION = '0.1'

function _M.new(self)
    local sock = ngx.socket.tcp()
    return setmetatable(
               {sock = sock, connected = false},
               {__index = self}
           )
end

function _M.connect(self, ...)
    if not self.sock then
        return nil, "socket is not initialized"
    end 
    if self.connected then
        return true, "already connected"
    end
    local ok, err = self.sock:connect(...)
    if not ok then
        return nil, err
    end

    self.connected = true
    return true, "SUCCESS"
end

function _M.setkeepalive(self, ...)
    if not self.sock then
        return nil, "socket is not initialized"
    end 
    if not self.connected then
        return true, "socket is not connected"
    end

    local ok, err = self.sock:setkeepalive(...)
    if not ok then
        return nil, err
    end

    self.connected = false
    return true, "SUCCESS"
end

function _M.close(self)
    if not self.sock then
        return nil, "socket is not initialized"
    end 
    if not self.connected then
        return true, "already closed"
    end

    local ok, err = self.sock:close()
    if not ok then
        return nil, err
    end

    self.connected = false
    return true, "SUCCESS"
end

function _M.get_reused_times(self)
    if not self.sock then
        return nil, "socket is not initialized"
    end
    return self.sock:getreusedtimes()
end

return _M
