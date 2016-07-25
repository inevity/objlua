-- By Yuanguo, 22/7/2016

local DEF_CAPACITY = 32 

local ok, new_tab = pcall(require, "table.new")
if not ok or type(new_tab) ~= "function" then
    new_tab = function (narr, nrec) return {} end
end

local _M = new_tab(0, 16)
_M._VERSION = '0.1'

function _M.new(self,c)
    local cap = c or DEF_CAPACITY
    local tab = new_tab(cap, 0)
    return setmetatable(
               {data = tab, capacity = cap, size = 0, head = 1, tail = 1},
               {__index = self}
           )
end

function _M.enqueue(self,element)
    if self.size == self.capacity then
        return nil, "queue is full, size=".. (self.size or "nil")..", capacity="..(self.capacity or "nil")
    end
    self.data[self.tail] = element
    self.tail = self.tail % self.capacity + 1
    self.size = self.size + 1
    return true, "SUCCESS"
end

function _M.dequeue(self)
    if self.size == 0 then
        return nil, "queue is empty"
    end
    local element = self.data[self.head]
    self.data[self.head] = nil
    self.head = self.head % self.capacity + 1
    self.size = self.size - 1
    return true, element 
end

function _M.get_size(self)
    return self.size
end

return _M
