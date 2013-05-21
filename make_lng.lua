if not arg[1] or not arg[2] then
    print([[

usage:
    lua make_lng.lua input.txt output.lng

    input.txt - path to translated text
    output.lng - path to output language file
]])
    os.exit()
end

local sub = string.sub
local tochar = string.char
local insert = table.insert
local concat = table.concat

require("binary_reader")

local lng = file_open(arg[1])

assert(read_u8(lng) == 255, "ERROR: not UTF-16LE file")
assert(read_u8(lng) == 254, "ERROR: not UTF-16LE file")

local strings = {}
local chars = {}

local eol = tochar(0x0d)
local eol0 = tochar(0x0d) .. tochar(0x00)

local lng_size = read_size(lng)

print("read file...")
while read_pos(lng) < lng_size do
    -- read key
    local t = {}
    while true do
        local ch = lng:read(1)
        if ch == eol then break end
        lng:read(1)             -- skip 0x00
        insert(t, ch)
    end
    lng:read(3)                 -- skip 0x00\r
    local key = concat(t)
    key = sub(key, 1, -6)       -- chop ' = [['

    -- read string
    t = {}
    while true do
        local ch = lng:read(2)
        if ch == eol0 then break end
        if chars[ch] then
            chars[ch] = chars[ch] + 1
        else
            chars[ch] = 1
        end
        insert(t, ch)
    end
    lng:read(14)                -- skip \r\n\r]]\n\r\n\r
    local str = concat(t)
    insert(strings, {key = key, str = str})
end
print(#strings .. " strings readed.")
lng:close()


print("counting the frequency of the use of symbols...")
local chars_sorted = {}
for k, v in pairs(chars) do
    table.insert(chars_sorted, {char = k, count = v})
end

table.sort(chars_sorted, function(a, b) return a.count > b.count end)

for k, v in ipairs(chars_sorted) do
    --print(v.char, v.count)
    chars[v.char] = k
end
local chars_count = #chars_sorted
print(chars_count .. " chars used.")


-------------------------------------------------------------------------------
local function write_u32(handle, int)
    local i84 = tochar(           bit32.rshift(int, 24)       )
    local i83 = tochar(bit32.band(bit32.rshift(int, 16), 0xff))
    local i82 = tochar(bit32.band(bit32.rshift(int, 8),  0xff))
    local i81 = tochar(bit32.band(int,                   0xff))
    local out = i81 .. i82 .. i83 .. i84
    handle:write(out)
end


print("write new .lng...")
local t = {0,0,0,0,4,0,0,0,0,0,0,0,1,0,0,0,2,0,0,0}
local zero = tochar(0x00)
lng = assert(io.open(arg[2], "w+b"))

write_u32(lng, 0)
write_u32(lng, 4)
write_u32(lng, 0)
write_u32(lng, 1)

print("write lookup table...")
write_u32(lng, chars_count * 2 + 2)
lng:write(zero)
lng:write(zero)
for k, v in ipairs(chars_sorted) do
    lng:write(v.char)
end
chars_sorted = nil

print("write key/string pairs...")
write_u32(lng, 2)
-- calculate size of key-string pairs
local size = 0
for k, v in ipairs(strings) do
    size = size + #v.key + (#v.str / 2) + 2
end
write_u32(lng, size)

for k, v in ipairs(strings) do
    lng:write(v.key)
    lng:write(zero)
    for w in string.gmatch(v.str, "..") do
        lng:write(tochar(chars[w]))
    end
    lng:write(zero)
end

lng:close()

