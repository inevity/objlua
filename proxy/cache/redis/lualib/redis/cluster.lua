-- By Yuanguo, 21/7/2016

local NUM_SLOT = 16384

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
        ngx.say("node_key: "..node_key)
        local i,j = string.find(node_key, ":")
        if not i then  -- unix socket
            nodes[node_key] = node:new(nil, nil, node_key)
        else           -- host:port
            local host = string.sub(node_key, 1,i-1)
            local port = string.sub(node_key, i+1)
            ngx.say(host, "  " ,port)
            nodes[node_key] = node:new(host,port)
        end
        if not nodes[node_key] then
            return nil,"failed to create node " .. (node_key or "nil")
        end
    end

    local slotmap = new_tab(NUM_SLOT, 0)

    return setmetatable(
               {nodes = nodes, slotmap = slotmap, needrefresh = false},
               {__index = self}
           )
end


function _M.refresh(self)
    local got = false
    for nodekey,nd in pairs(self.nodes) do
        ngx.say("\r\n---------- connect "..nodekey.." to get node map ----------")
        local res, err = nd:do_cluster_cmd("nodes")
        if not res then   -- failed to get node map 
            ngx.say("failed to get node map from " .. (nodekey or "nil"))
        else              -- succeeded to get node map
            ngx.say("succeeded to get node map from " .. (nodekey or "nil"))
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
                ngx.say("line: ".. (line or "nil"))
                local nid,nkey,nflags,master,tlast_ping,tlast_pong,conf_epoch,status = 
                      string.match(line,"([^%s]+)[%s]+([^%s]+)[%s]+([^%s]+)[%s]+([^%s]+)[%s]+([^%s]+)[%s]+([^%s]+)[%s]+([^%s]+)[%s]+([^%s]+)")
                ngx.say(
                        "    nodeId     :  " .. nid .. "\r\n",
                        "    nodeKey    :  " .. nkey .. "\r\n",
                        "    flags      :  " .. nflags .. "\r\n",
                        "    masterID   :  " .. master .. "\r\n",
                        "    tlastPing  :  " .. tlast_ping .. "\r\n",
                        "    tlastPong  :  " .. tlast_pong .. "\r\n",
                        "    conf_epoch :  " .. conf_epoch .. "\r\n",
                        "    status     :  " .. status
                    )
                if nid then   -- current line is a valid line
                    local i,j = string.find(nflags, "master") 
                    if i then -- current line is master
                        local s,p = string.find(nkey, ":")
                        if not s then  -- unix socket
                            self.nodes[nkey] = node:new(nil, nil, nkey)
                        else           -- host:port
                            local host = string.sub(nkey, 1,s-1)
                            local port = string.sub(nkey, s+1)
                            self.nodes[nkey] = node:new(host,port)
                        end
                        if not self.nodes[nkey] then
                            return nil,"failed to create node " .. (nkey or "nil")
                        end

                        local s,p = string.find(line,status)
                        local slotRanges = string.sub(line, p+1)   -- get everything after status field, that's slot ranges
                        ngx.say("    slotRanges :  " .. slotRanges)

                        for range in string.gmatch(slotRanges, "[^ ]+") do  -- slotRanges is a string like "0-998 5461-6461 10923-16383, we get each range"
                            local s,e = string.match(range, "(%d+)-(%d+)")
                            ngx.say("        range      :  " .. (s or "nil") .. "-" .. (e or "nil") .. "==> node:" .. (nkey or "nil"))
                            for k = s, e do
                                self.slotmap[k] = self.nodes[nkey]
                            end
                        end
                    else  -- current line is slave
                        ngx.say("    skip slave " .. (nkey or "nil"))
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
        ngx.say("refresh because key moved ...")
        local ok,err = _M.refresh(self)
        if ok then
            ngx.say("refresh success")
            self.needrefresh = false
        else
            ngx.say("refresh failed: "..(err or "nil"))
        end
    end

    local nd = self.slotmap[slot]
    local res,err = nd:do_cmd(...)
    if not res and string.match(err,"MOVED%s+%d+%s+") then
        ngx.say("key moved, need refresh")
        self.needrefresh = true
    end
    return res, err
end

function _M.do_cmd(self, ...)
    local args = {...}
    if not args[1] then
        ngx.say("invalid command: args[1] is nil")
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
                ngx.say("invalid command: args[2] which is the key cannot be nil")
            else
                local slot = _get_slot(key)
                return _do_cmd(self, slot, ...)
            end
        else
            ngx.say("command " .. cmd .. " not supported")
        end
    end
end

return _M
