local ok,cluster = pcall(require, "redis.cluster")
if not ok or not cluster then
    ngx.say("failed to load redis.cluster. err="..(cluster or "nil"))
    return
end

local c1,err=cluster:new("127.3.3.1:9000","127.0.0.1:7000")

if not c1 then
    ngx.say("failed to new a cluster. err="..(err or "nil"))
    return
end

local ok,err = c1:refresh()
if not ok then
    ngx.say("failed to refresh cluster. err="..(err or "nil"))
    return
end

local count = ngx.var.arg_c or 12345
for i = 1, count do
    local res, err = c1:do_cmd("incr", "foobar")
    if not res then
        ngx.say("ERROR: failed to incr foobar. err="..(err or "nil"))
    end
end
