-- By Yuanguo, 21/7/2016

local NUM_SLOT = 16384

-- We need to refresh the slotmap in the following 2 cases:
--   1. When we get a "MOVED" error;
--   2. When the total error reaches a threshold;
-- Case 1 is straightforward; while the logic for case 2 is:
--   if a master node is down and fails over to a slave, error (not MOVED) will
--   occurr because the slotmap is outdated. Thus, if the total error number 
--   reaches a given threshold, a refresh should be done:
--         threshold = errnum2refresh * {number of master nodes}
--   ERRNUM2REFRESH is the default value for errnum2refresh; caller may
--   overwrite the value by function:
--         set_errnum2refresh()
--
local ERRNUM2REFRESH = 600

local ok, new_tab = pcall(require, "table.new")
if not ok or type(new_tab) ~= "function" then
    new_tab = function (narr, nrec) return {} end
end

local ok, node = pcall(require, "redis.node")
if not ok or not node then
    error("failed to load node:" .. (node or "nil"))
end

local ok, crc16 = pcall(require, "crc16")
if not ok or not crc16 then
    error("failed to load crc16:" .. (crc16 or "nil"))
end

local _M = new_tab(0, 155)
_M._VERSION = '0.1'


function _M.new(self, ...)
    local nodes = new_tab(0, 155)
    local args = {...}
    for i = 1, #args do
        local node_key = args[i]  -- unix socket or host:port

        ngx.log(ngx.DEBUG, "node_key: "..(node_key or "nil"))

        nodes[node_key] = node:new(node_key)
        if not nodes[node_key] then
            return nil,"failed to create node " .. (node_key or "nil")
        end
    end

    local slotmap = new_tab(NUM_SLOT, 0)

    return setmetatable(
               {nodes = nodes, nodenum = 0, slotmap = slotmap, needrefresh = false, errnum2refresh = ERRNUM2REFRESH, errnum = 0},
               {__index = self}
           )
end


function _M.refresh(self)
    local got = false
    self.nodenum = 0
    for nodekey,nd in pairs(self.nodes) do
        ngx.log(ngx.DEBUG, "connect "..(nodekey or "nil").. " to get node map")
        local res, err = nd:do_cluster_cmd("nodes")
        if not res then   -- failed to get node map 
            ngx.log(ngx.WARN, "failed to get node map from " .. (nodekey or "nil"))
        else              -- succeeded to get node map
            ngx.log(ngx.DEBUG, "succeeded to get node map from " .. (nodekey or "nil"))
            --[[
            an example of node map:
            62f05cdf4bcaad8fcfa0cc2c32ac8e19e1c538b9 127.0.0.1:7001 master - 0 1469374853889 2 connected 6462-10922
            82ef688fd2bb3de2ae2e503925c5cf78ae8ce320 127.0.0.1:7000 myself,master - 0 0 1 connected 999-5460
            5870f4c91d1cab3cdd213e81f99f0a1d8c783a35 127.0.0.1:7004 slave 62f05cdf4bcaad8fcfa0cc2c32ac8e19e1c538b9 0 1469374855404 5 connected
            ad1538a53ff6cf1db8a0f59bcb9c88f307cbc07d 127.0.0.1:7005 slave 83ab234d0dd5a0d4423bfb2033cedab33bf18e5e 0 1469374854395 7 connected
            83ab234d0dd5a0d4423bfb2033cedab33bf18e5e 127.0.0.1:7002 master - 0 1469374855909 7 connected 0-998 5461-6461 10923-16383
            4834b7f8a6f418e3d1006513561149e580768d5b 127.0.0.1:7003 slave 82ef688fd2bb3de2ae2e503925c5cf78ae8ce320 0 1469374854898 4 connected

            fields of each line:
            1. Node ID
            2. ip:port
            3. flags: master, slave, myself, fail, ...
            4. if it is a slave, the Node ID of the master
            5. Time of the last pending PING still waiting for a reply.
            6. Time of the last PONG received.
            7. Configuration epoch for this node (see the Cluster specification).
            8. Status of the link to this node.
            9. Slots served...
            --]]
            for line in string.gmatch(res, "[^\r\n]+") do
                ngx.log(ngx.DEBUG, "line: ".. (line or "nil"))
                local nid,nkey,nflags,master,tlast_ping,tlast_pong,conf_epoch,status = 
                      string.match(line,"([^%s]+)[%s]+([^%s]+)[%s]+([^%s]+)[%s]+([^%s]+)[%s]+([^%s]+)[%s]+([^%s]+)[%s]+([^%s]+)[%s]+([^%s]+)")

                ngx.log(ngx.DEBUG, "    nodeId     :  " .. (nid or "nil"))
                ngx.log(ngx.DEBUG, "    nodeKey    :  " .. (nkey or "nil"))
                ngx.log(ngx.DEBUG, "    flags      :  " .. (nflags or "nil"))
                ngx.log(ngx.DEBUG, "    masterID   :  " .. (master or "nil"))
                ngx.log(ngx.DEBUG, "    tlastPing  :  " .. (tlast_ping or "nil"))
                ngx.log(ngx.DEBUG, "    tlastPong  :  " .. (tlast_pong or "nil"))
                ngx.log(ngx.DEBUG, "    conf_epoch :  " .. (conf_epoch or "nil"))
                ngx.log(ngx.DEBUG, "    status     :  " .. (status or "nil"))

                if nid then   -- current line is a valid line
                    local i,j = string.find(nflags, "master") 
                    if i then -- current line is master
                        self.nodes[nkey] = node:new(nkey)
                        if not self.nodes[nkey] then
                            return nil,"failed to create node " .. (nkey or "nil")
                        end
                        self.nodenum = self.nodenum + 1

                        local s,p = string.find(line,status)
                        local slotRanges = string.sub(line, p+1)   -- get everything after status field, that's slot ranges
                        ngx.log(ngx.DEBUG, "    slotRanges :  " .. (slotRanges or "nil"))

                        for range in string.gmatch(slotRanges, "[^ ]+") do  -- slotRanges is a string like "0-998 5461-6461 10923-16383, we get each range"
                            local s,e = string.match(range, "(%d+)-(%d+)")
                            ngx.log(ngx.DEBUG, "        range      :  " .. (s or "nil") .. "-" .. (e or "nil") .. "==> node:" .. (nkey or "nil"))
                            for k = s, e do
                                self.slotmap[k] = self.nodes[nkey]
                            end
                        end
                    else  -- current line is slave
                        ngx.log(ngx.DEBUG, "    skip slave " .. (nkey or "nil"))
                    end
                end
            end
            got = true
            break
        end
    end
    if not got then
        return nil, "command 'cluster nodes' failed on all nodes"
    end
    return true, "SUCCESS"
end


-- If the total error number reaches a given threshold, a refresh should be done.
--         threshold = errnum2refresh * {number of master nodes}
-- this function is to set errnum2refresh, whose default value is ERRNUM2REFRESH
function _M.set_errnum2refresh(self, num)
    self.errnum2refresh = (num or ERRNUM2REFRESH) 
end

-- Yuanguo: according to the Redis Cluster specification: when calculating the
-- slot of a given key, if there is a hash tag (substring inside {}) in the key,
-- only the hash tag is hashed;
-- Yuanguo: if there is nothing inside {}, I don't think it's a valid hash tag,
-- and thus, I still hash the whole key.
local function _get_slot(key)
    local hashtag = string.match(key,"{(.+)}")
    if not hashtag then
        hashtag = key
    end
    return crc16:crc({hashtag:byte(1,-1)}) % NUM_SLOT
end

local function _do_cmd(self, slot, ...)
    if self.needrefresh then
        ngx.log(ngx.WARN, "refresh slotmap ...")
        local ok,err = _M.refresh(self)
        if ok then
            ngx.log(ngx.WARN, "refresh success")
            self.needrefresh = false
            self.errnum = 0
        else
            ngx.log(ngx.ERR, "refresh failed: "..(err or "nil"))
        end
    end

    local nd = self.slotmap[slot]
    local res,err = nd:do_cmd(...)

    if not res then
        self.errnum = self.errnum + 1
        if string.match(err,"MOVED%s+%d+%s+") then
            ngx.log(ngx.WARN, "key moved, need refresh")
            self.needrefresh = true
        end

        local total_errnum2refresh = self.errnum2refresh * self.nodenum 
        if self.errnum >= total_errnum2refresh then
            ngx.log(ngx.WARN, "too many errors ("..self.errnum.."), need refresh")
            self.needrefresh = true
            self.errnum = 0
        end
    end

    return res, err
end

function _M.do_cmd(self, ...)
    local args = {...}
    if not args[1] then
        ngx.log(ngx.ERR, "invalid command: args[1] is nil")
        return nil, "Invalid Arg"
    else
        local cmd = string.lower(args[1])
        if cmd == "set" or 
           cmd == "get" or 
           cmd == "hset" or 
           cmd == "hget" or 
           cmd == "incr" 
        then
            local key = args[2]
            if not key then
                ngx.log(ngx.ERR, "invalid command: args[2] which is the key cannot be nil")
                return nil, "Invalid Arg"
            else
                local slot = _get_slot(key)
                return _do_cmd(self, slot, ...)
            end
        else
            ngx.log(ngx.ERR, "command " .. (cmd or "nil") .. " not supported")
            return nil, "Invalid Arg"
        end
    end
end

return _M
