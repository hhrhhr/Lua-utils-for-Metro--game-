local bit = bit or bit32    -- lua52 - bit32, luajit 2.0.1 - bit
local byte = string.byte
local char = string.char
local insert = table.insert
local concat = table.concat

function file_open(filename)
    return assert(io.open(filename, "rb"))
end

function read_pos(handle)
    return handle:seek()
end

function read_size(handle)
    local pos = handle:seek()
    local size = handle:seek("end")
    handle:seek("set", pos)
    return size
end

function read_u8(handle)
    local u8 = 0
    u8 = u8 + byte(handle:read(1)) * 2^0
    return u8
end

function read_u16(handle)
    local u16 = 0
    u16 = u16 + byte(handle:read(1)) * 2^0
    u16 = u16 + byte(handle:read(1)) * 2^8
    return u16
end

function read_u32(handle)
    local u32 = 0
    u32 = u32 + byte(handle:read(1)) * 2^0
    u32 = u32 + byte(handle:read(1)) * 2^8
    u32 = u32 + byte(handle:read(1)) * 2^16
    u32 = u32 + byte(handle:read(1)) * 2^24
    return u32
end

function read_str(handle, toutf16)
    local chars = {}
    local zero = char(0x00)
    while true do
        local ch = handle:read(1)
        if ch == zero then break end
        insert(chars, ch)
        if toutf16 then
            insert(chars, zero)   -- make UTF-16 :)
        end
    end
    str = concat(chars)
    return str
end

function read_packed_str(handle, lookup_t)
    local chars = {}
    local zero = 0x00
    while true do
        local ch = byte(handle:read(1))
        if ch == zero then break end
        insert(chars, lookup_t[ch+1])
    end
    local str = concat(chars)
    return str
end

function read_xor_str(handle)
    local len = read_u8(handle)
    local xor = read_u8(handle)
    local chars = {}
    for i = 1, len-1 do
        local bt = byte(handle:read(1))
        bt = bit.bxor(bt, xor)
        local ch = char(bt)
        insert(chars, ch)
    end
    local str = concat(chars)
    handle:read(1)   -- last 0x00
    return str
end

function read_hex(handle, len)
    local str = {}
    local len = len or 4
    for i = 1, len do
        local u8 = read_u8(handle)
        local hex = string.format("%02X", u8)
        insert(str, hex)
    end
    str = concat(str)
    return str
end
