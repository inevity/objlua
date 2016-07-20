local json=require('cjson')

_M = {}

function _M.genuuid()
    local template ="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
    d = io.open("/dev/urandom", "r"):read(4)
    math.randomseed(os.time() + d:byte(1) + (d:byte(2) * 256) + (d:byte(3) * 65536) + (d:byte(4) * 4294967296))

    a, b = string.gsub(template, "x",
        function (c)
            local v = (c == "x") and math.random(0, 0xf) or math.random(8, 0xb)
            return string.format("%x", v)
        end
    )
    return a
end

function _M.genuuid1()
    local seed={'0','1','2','3','4','5','6','7','8','9','a','b','c','d','e','f'}
    local tb={}
    for i=1,32 do
        table.insert(tb,seed[math.random(1,16)])
    end
    return table.concat(tb)
end

--字符串分割函数
function _M.strsplit(str, pattern, num)
    print("begin to strsplist, str is ", str, " , and pattern is ", pattern, " , num is ", num)
    local sub_str_tab = {}

    if nil == str then
        return sub_str_tab
    end
    if nil == pattern then
        return {str} 
    end

    local i = 0
    local j = 0
    if num == nil then
        num = -1
    end

    while true do
        if num == 0 then
            table.insert(sub_str_tab, string.sub(str, i, -1))
            break
        end

        j = string.find(str, pattern, i+1)
        if j == nil then
            table.insert(sub_str_tab, string.sub(str, i, -1))
            break
        end
        table.insert(sub_str_tab, string.sub(str, i, j-1))
        i = j + 1
        num = num - 1
    end

    return sub_str_tab
end

return _M
