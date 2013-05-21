if not arg[1] or not arg[2] then
    print([[

usage:
    lua extract_lng.lua input.lng output.txt

    input.lng - path to source language
    output.txt - path to converted text file
]])
    os.exit()
end

local tochar = string.char
local insert = table.insert
local concat = table.concat

require("binary_reader")

print("read file...")
local lng = file_open(arg[1])

assert(read_u32(lng) == 0)
assert(read_u32(lng) == 4)
assert(read_u32(lng) == 0)
assert(read_u32(lng) == 1)

local lookup_t_size = read_u32(lng) / 2

local lookup_t = {}
for i = 1, lookup_t_size do
    local char = lng:read(2)
    insert(lookup_t, char)
end

assert(read_u32(lng) == 2)
assert(read_u32(lng) == read_size(lng) - read_pos(lng)) -- size of key-string pairs

local strings = {}
local lng_size = read_size(lng)
while lng:seek() < lng_size do
    local t = {}
    t.key = read_str(lng, true)
    t.str = read_packed_str(lng, lookup_t)
    insert(strings, t)
end

lng:close()



print("sort by keys...")
table.sort(strings, function(a, b) return a.key < b.key end)

local chars1 = {0x20, 0x3d, 0x20, 0x5b, 0x5b, 0x0d, 0x0a}       -- ' = [[\n\r'
local chars2 = {0x0d, 0x0a, 0x5d, 0x5d, 0x0d, 0x0a, 0x0d, 0x0a} -- '\n\r]]\n\r\n\r'
local chars3 = {}
local chars4 = {}
for k, v in ipairs(chars1) do
    insert(chars3, tochar(v))
    insert(chars3, tochar(0x00))
end
chars1 = concat(chars3)
for k, v in ipairs(chars2) do
    insert(chars4, tochar(v))
    insert(chars4, tochar(0x00))
end
chars2 = concat(chars4)



print("write converted file...")
local out = assert(io.open(arg[2], "w+b"))
out:write(tochar(0xff))
out:write(tochar(0xfe))
for k, v in ipairs(strings) do
    out:write(v.key)
    out:write(chars1)
    out:write(v.str)
    out:write(chars2)
end

out:close()

