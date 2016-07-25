function printStruct(struct,nspaces)
    local spaces = ""
    for i=1,nspaces do
        spaces = spaces.." "
    end
    if (type(struct) == "nil") then
        ngx.say(spaces.."nil")
    elseif (type(struct) == "boolean") then
        if struct then
            ngx.say(spaces.."true")
        else
            ngx.say(spaces.."false")
        end
    elseif (type(struct) == "number") then
        ngx.say(spaces..struct)
    elseif (type(struct) == "string") then
        ngx.say(spaces..struct)
    elseif (type(struct) == "function") then
        ngx.say(spaces.."function(not supported yet)")
    elseif (type(struct) == "thread") then
        ngx.say(spaces.."thread(not supported yet)")
    elseif (type(struct) == "table") then
        ngx.say(spaces.."{") 
        for n,k in pairs(struct) do
            printStruct(k, nspaces+4)
        end
        ngx.say(spaces.."}") 
    end
end

ngx.say("--------------[package.loaded]--------------")
for n in pairs(package.loaded) do
    ngx.say(n)
end

ngx.say("--------------[package.preload]--------------")
for n in pairs(package.preload) do
    ngx.say(n)
end

ngx.say("--------------[package.path]--------------")
ngx.say(package.path)

ngx.say("--------------[package.cpath]--------------")
ngx.say(package.cpath)

ngx.say("\r\n-------------------------------------------\r\n")

local cluster = require "redis.cluster"
if cluster then
    ngx.say("cluster loaded")
end

local c1=cluster:new("127.0.0.1:7000")
local ok,err = c1:refresh()
if not ok then
    ngx.say("failed to refresh cluster: "..(err or "nil"))
    return
end

for i = 1, 10 do
    local res, err = c1:do_cmd("set", "cluster-key-"..i, "cluster-value-"..i)
    ngx.say("set: cluster-key-"..i..": ",  res, "    ", err)
end

for i = 1, 10 do
    local res, err = c1:do_cmd("get", "cluster-key-"..i)
    ngx.say("get: cluster-key-"..i..": ",  res, "    ", err)
end

for i = 1, 100000 do
    local res, err = c1:do_cmd("incr", "foobar")
    ngx.say("incr foobar: ",  res, "    ", err)
end
