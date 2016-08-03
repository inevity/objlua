--[[
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

--]]
local ok,cluster = pcall(require, "redis.cluster")
if not ok or not cluster then
    ngx.say("failed to load redis.cluster. err="..(cluster or "nil"))
    return
end

local c1=cluster:new("127.0.0.1:7000")
local ok,err = c1:refresh()
if not ok then
    ngx.say("failed to refresh cluster: "..(err or "nil"))
    return
end


local succ = true 

-- test set
for i = 1, 10 do
    local res, err = c1:do_cmd("set", "cluster-key-"..i, "cluster-value-"..i)
    if not res then
        ngx.say("ERROR: failed to set cluster-key-"..i..". err="..(err or "nil"))
        succ = false
    end
end

-- test get
for i = 1, 10 do
    local res, err = c1:do_cmd("get", "cluster-key-"..i)
    local expected = "cluster-value-"..i
    if not res == expected then
        ngx.say("ERROR: failed to get cluster-key-"..i..". res="..(res or "nil").."; err="..(err or "nil"))
        succ = false
    end
end

-- test hset
for i = 1, 15 do
    for j = 1,15 do
        local res, err = c1:do_cmd("hset", "myhash"..i, "mykey"..j, "value"..(i*j))
        if not res then
            ngx.say("ERROR: failed to hset myhash"..i.." mykey"..j..". err="..(err or "nil"))
            succ = false
        end
    end
end

-- test hget
for i = 1, 15 do
    for j = 1,15 do
        local res, err = c1:do_cmd("hget", "myhash"..i, "mykey"..j)
        local expected = "value"..(i*j)
        if not res == expected then
            ngx.say("ERROR: failed to hget myhash"..i.." mykey"..j..". res="..(res or "nil").."; err="..(err or "nil"))
            succ = false
        end
    end
end


-- test incr
local initial = nil
local res, err = c1:do_cmd("get", "foobar")
if not res or type(res) == "userdata" then
    initial = 54321
    c1:do_cmd("set", "foobar", initial)
else
    initial = res
end

local steps = 12345
for i = 1, steps do
    local res, err = c1:do_cmd("incr", "foobar")
    if not res then
        ngx.say("ERROR: failed to incr foobar. err="..(err or "nil"))
        succ = false
    end
end

local expected = initial + steps
local res, err = c1:do_cmd("get", "foobar")
if not res then
    ngx.say("ERROR: failed to get foobar after incr. err="..(err or "nil"))
    succ = false
else
    if not res == expected then
        ngx.say("ERROR: incr failed, expected="..(expected or "nil")..", but actual="..(res or "nil"))
        succ = false
    end
end

if succ then
    ngx.say("All basic tests have succeeded.")
else
    ngx.say("Some of the baisc tests have failed.")
end
