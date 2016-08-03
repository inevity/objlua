-- By Yuanguo, 22/7/2016

local NODE_CONN = 64 

local ok, new_tab = pcall(require, "table.new")
if not ok or type(new_tab) ~= "function" then
    new_tab = function (narr, nrec) return {} end
end

local ok, queue = pcall(require, "queue")
if not ok or not queue then
    error("failed to load queue:" .. (queue or "nil"))
end

local ok, tcpsock = pcall(require, "tcpsock")
if not ok or not tcpsock then
    error("failed to load tcpsock:" .. (tcpsock or "nil"))
end

local _M = new_tab(0, 155)
_M._VERSION = '0.1'

function _M.new(self, addr, cachesize)
    -- Yuanguo:
    -- A request uses the socket in this way:
    --     1. get a "socket object" from the queue 'socks';
    --     2. connect. if there is any underlying connection in the cosocket
    --        connection pool, get one from the cosocket connection pool and 
    --        bind the "socket object" to it (thus there is no real connect);
    --     3. use the "socket object" (which has been bound to an underlying
    --        connection) to do its job;
    --     4. setkeepalive. that's to mark the "socket object" as 'closed' (un-
    --        bind with the underlying connection); but the underlying 
    --        connection is not closed, instead, it is put back to the cosocket 
    --        connection pool;
    --     5. put the "socket object" back to the queue 'socks';
    -- Note that:
    --     a. the "socket object" is different from the underlying connection in
    --        the cosocket connection pool;
    --     b. the life cycle of the "socket objects" in the queue 'socks' is 
    --        "per request", thus different requets never reuse the same socket;
    --     c. but the life cycle of cosocket connection pool is the same as
    --        nginx, so, in step 2, different "socket object" (in the same 
    --        request or in different requests) may bind to the same underlying
    --        connection;
    -- So:
    --     A. the aim of the queue 'socks' here is to reuse "socket object" in
    --        the same request (the life cycle of the "socket object" is "per
    --        request"). It has nothing to do with "connection reuse"; even if
    --        you get the same "socket object" from the queue, it may bind to  
    --        different underlying connections in the "connect" (step 2).
    --     B. the cosocket connection pool gives us the ability to reuse
    --        connections; "socket objects" in the same request or different
    --        requests may bind to the same underlying connection (func 
    --        getreusedtimes can be used to get the reuse times);
    local cap = cachesize or NODE_CONN
    local socks = queue:new(cap)
    --local socks = queue:new(cap, true, addr)
    for i = 1, cap do
        local sock = tcpsock:new()
        socks:enqueue(sock)
    end

    local host = nil
    local port = nil
    local unisock = nil

    local i,j = string.find(addr, ":")
    if not i then  --unix sock
        unisock = addr
    else
        host = string.sub(addr,1,i-1)
        port = string.sub(addr,i+1,-1)
        if not tonumber(port) then
            return nil, "port "..(port or "nil").." invalid"
        end
    end

    return setmetatable(
               {host = host, port = port, unisock = unisock, sockets = socks},
               { __index = self }
           )
end

--no need to call init() function. if called, it will make NODE_CONN connections before used
function _M.init(self)
    for n, sock in pairs(self.sockets.data) do
        if not self.host then  -- unix socket
            local ok, err = sock:connect(self.unisock)
            if not ok then
                return nil,"connect " .. (self.unisock or "nil") .. " failed: " .. (err or "nil")
            end
        else                   -- host:port
            local ok, err = sock:connect(self.host, self.port)
            if not ok then
                return nil,"connect " .. (self.host or "nil") .. ":" .. (self.port or "nil") .. " failed: " .. (err or "nil")
            end
        end
    end
end

local function _gen_req(args)
    local nargs = #args

    local req = new_tab(nargs * 5 + 1, 0)
    req[1] = "*" .. nargs .. "\r\n"
    local nbits = 2

    for i = 1, nargs do
        local arg = args[i]
        if type(arg) ~= "string" then
            arg = tostring(arg)
        end

        req[nbits] = "$"
        req[nbits + 1] = #arg
        req[nbits + 2] = "\r\n"
        req[nbits + 3] = arg
        req[nbits + 4] = "\r\n"

        nbits = nbits + 5
    end

    -- it is much faster to do string concatenation on the C land
    -- in real world (large number of strings in the Lua VM)
    return req
end

local function _read_reply(self, sock)
    local line, err = sock:receive()
    if not line then
        return nil, err
    end

    local prefix = string.byte(line)

    if prefix == 36 then    -- char '$'
        -- print("bulk reply")
        local size = tonumber(string.sub(line, 2))
        if size < 0 then
            return ngx.null
        end

        local data, err = sock:receive(size)
        if not data then
            return nil, err
        end

        local dummy, err = sock:receive(2) -- ignore CRLF
        if not dummy then
            return nil, err
        end
        return data
    elseif prefix == 43 then    -- char '+'
        -- print("status reply")

        return string.sub(line, 2)

    elseif prefix == 42 then -- char '*'
        local n = tonumber(string.sub(line, 2))

        -- print("multi-bulk reply: ", n)
        if n < 0 then
            return ngx.null
        end

        local vals = new_tab(n, 0)
        local nvals = 0
        for i = 1, n do
            local res, err = _read_reply(self, sock)
            if res then
                nvals = nvals + 1
                vals[nvals] = res

            elseif res == nil then
                return nil, err

            else
                -- be a valid redis error value
                nvals = nvals + 1
                vals[nvals] = {false, err}
            end
        end

        return vals

    elseif prefix == 58 then    -- char ':'
        -- print("integer reply")
        return tonumber(string.sub(line, 2))

    elseif prefix == 45 then    -- char '-'
        -- print("error reply: ", n)

        return false, string.sub(line, 2)

    else
        -- when `line` is an empty string, `prefix` will be equal to nil.
        return nil, "unkown prefix: \"" .. tostring(prefix) .. "\""
    end
end

local function _do_cmd(self, ...)
    local ok, sock = self.sockets:dequeue()
    if not ok then  -- if not ok, must be empty 
        ngx.log(ngx.WARN, "failed to get a sock from queue, err="..(sock or "nil"))
        sock = tcpsock:new()
    end

    if not self.host then  -- unix socket
        local ok, err = sock:connect(self.unisock)
        if not ok then
            return nil,"connect " .. (self.unisock or "nil") .. " failed: " .. (err or "nil")
        end
    else                   -- host:port
        local ok, err = sock:connect(self.host, self.port)
        if not ok then
            return nil,"connect " .. (self.host or "nil") .. ":" .. (self.port or "nil") .. " failed: " .. (err or "nil")
        end
    end

    local args = {...}
    local req = _gen_req(args)

    local bytes, err = sock.sock:send(req)
    if not bytes then
        -- in the case of error, not put the socket in queue again, but drop it
        sock:close()
        return nil, err
    end

    local res, err = _read_reply(self, sock.sock)
    if not res then
        -- in the case of error, not put the socket in queue again, but drop it
        sock:close()
        return nil, err
    end

    ngx.log(ngx.DEBUG, "Current socket reused times: " .. (sock:get_reused_times() or "nil"))

    --succeeded: try to put the socket in queue
    sock:setkeepalive()  --use the default value set by lua_socket_keepalive_timeout and lua_socket_pool_size in nginx conf
    local ok,err1 = self.sockets:enqueue(sock)
    if not ok then
        ngx.log(ngx.WARN, "failed to put sock into the queue, err="..(err1 or "nil"))
    end

    return res, err
end

function _M.do_cmd(self, cmd, ...)
    return _do_cmd(self, cmd, ...)
end

function _M.do_cluster_cmd(self, cmd, ...)
    --return nil, "debug"
    return _do_cmd(self, "cluster", cmd, ...)
end

return _M
