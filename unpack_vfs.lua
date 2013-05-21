local q = io.read()

if not arg[1] then
    print([[

usage:
luajit unpack_vfs.lua vfx [outdir vfs_idx]
    vfx     - fullpath to .vfx
    outdir  - output directory
    vfs_idx - number, unpack only this archive, 0 - full unpack
]])
    os.exit()
end

require("binary_reader")
local vfx = file_open(arg[1])
local in_dir = string.match(arg[1], "(.+)\\.+") .. "\\"
local out_dir = arg[2]

local header = {}
local vfs = {}
local handle = {}
local ans = -1

local entry = {}
local dir  = { count = 0, processed = 0 }
local file = { count = 0, processed = 0 }
local tmp_t = {}
local tmp_s = ""
local tmp_f

print("\nread header...")
header.ver1 = read_u32(vfx)
header.ver2 = read_u32(vfx)
header.hash1 = read_hex(vfx, 8)
header.hash2 = read_hex(vfx, 8)
header.num_vfs = read_u32(vfx)
header.num_entries = read_u32(vfx)
header.num_records = read_u32(vfx)

print(string.format("%d:%d, (%s %s)", 
    header.ver1, header.ver2, header.hash1, header.hash2))
print(string.format("vfss: %d, entries: %d, records: %d", 
    header.num_vfs, header.num_entries, header.num_records))



print("\nread and open " .. header.num_vfs .. " .vfs...\n")
for i = 1, header.num_vfs do
    local t = {}
    t.name = read_str(vfx)
    t.fullname = in_dir .. t.name
    t.size = read_u32(vfx)
    table.insert(vfs, t)
    print("#"..i, t.name, t.size.." bytes")
end



if arg[3] then
    ans = tonumber(arg[3])
    if type(ans) ~= "number" then
        print("\nyou must enter a number as index")
        os.exit()
    elseif ans == 0 then
        print("\nselected all archives")
    elseif ans > 0 and ans <= header.num_vfs then
        print("\nselected only " .. vfs[ans].name)
    else
        print("\nno file with index " .. ans)
        os.exit()
    end
else
    os.exit()
end



print("\nread " .. header.num_entries .. " entries...")
for i = 1, header.num_entries do
    local t = {}
    local typ = read_u16(vfx)
    t.typ = typ
    t.used = false
    if typ > 0 then
        -- directory
        t.count = read_u16(vfx)
        t.first = read_u32(vfx)+1
        local path = read_xor_str(vfx)
        if #path == 0 then path = "." end
        t.path  = path
        dir.count = dir.count + 1
    else
        -- file
        t.vfs = read_u16(vfx)+1
        t.off = read_u32(vfx)
        t.unp = read_u32(vfx)
        t.pak = read_u32(vfx)
        t.fn  = read_xor_str(vfx)
        file.count = file.count + 1
    end
    table.insert(entry, t)
end
--print(read_pos(vfx), read_size(vfx))
vfx:close()



io.write("\nparse " .. dir.count .. " dirs and " .. file.count .. " files...")
local function parse_dirs(idx, path)
    local d = entry[idx]
    d.used = true
    local first = d.first
    local last = first + d.count - 1
    local fullpath = path .. "\\" .. d.path
    dir.processed = dir.processed + 1
    for i = first, last do
        local f = entry[i]
        if f.typ == 0 then
            f.used = true
            file.processed = file.processed + 1

            local t = {}
            t.vfs = f.vfs
            t.off = f.off
            t.pak = f.pak
            t.unp = f.unp
            t.fn  = fullpath .. "\\" .. f.fn

            if ans == 0 or ans == t.vfs then
                table.insert(file, t)
            end

        else
            parse_dirs(i, fullpath)
        end
    end
end
parse_dirs(1, ".")

while dir.processed < dir.count do
    for i = 1, header.num_entries do
        if not entry[i].used then
            parse_dirs(i, ".")
            io.write(".")
        end
    end
end
entry = nil
print("\nfounded " .. dir.processed .. " dirs and " .. file.processed .. " files")



print("\nprepare dir list...")
for k, v in ipairs(file) do
    local fn = string.match(v.fn, "(.+)\\.+") .. "\\"
    table.insert(dir, fn)
end
table.sort(dir)
for k, v in ipairs(dir) do
    if v ~= tmp_s then
        tmp_s = v
        table.insert(tmp_t, tmp_s)
    end
end
dir = {}
for k, v in ipairs(tmp_t) do
    table.insert(dir, v)
end
tmp_t = {}
print("found and sorted " .. #dir .. " unique dirs")



print("saving dir list...")
if ans == 0 then
    tmp_s = "\\list_dirs.txt"
else
    tmp_s = "\\" .. vfs[ans].name .. "_dirs.txt"
end
tmp_f = assert(io.open(out_dir .. tmp_s, "w+"))
tmp_s = ""
for k, v in ipairs(dir) do
    tmp_f:write(v)
    tmp_f:write("\n")
end
tmp_f:close()



print("\nsort files by vfs index and offset...")
for i = 1, header.num_vfs do
    tmp_t[i] = {}
end
for k, v in ipairs(file) do
    local t = {off = v.off, pak = v.pak, unp = v.unp, fn = v.fn}
    table.insert(tmp_t[v.vfs], t)
end

file = {}
for i = 1, header.num_vfs do
    file[i] = {}
end
for k, v in ipairs(tmp_t) do
    table.sort(v, function(a, b) return a.off < b.off end)
    for kk, vv in ipairs(v) do
        local t = {off = vv.off, pak = vv.pak, unp = vv.unp, fn = vv.fn}
        table.insert(file[k], t)
    end
end
tmp_t = {}



print("saving file list...")
if ans == 0 then
    tmp_s = "\\list_files.txt"
else
    tmp_s = "\\" .. vfs[ans].name .. "_files.txt"
end
tmp_f = assert(io.open(out_dir .. tmp_s, "w+"))
tmp_s = ""
for k, v in ipairs(file) do
    for kk, vv in ipairs(v) do
        local str = string.format("%s\t%d\t%d\t%d\t%d\t%s\n",
            vfs[k].name, kk, vv.off, vv.pak, vv.unp, vv.fn)
        tmp_f:write(str)
    end
end
tmp_f:close()



-------------------------------------------------------------------------------
local lzm = require("metro_lz")

local function unpack_chunk(vfs)
    local in_len  = 0
    local out_len = 0
    local buf = ""
    local out = ""

    local prefix = read_u8(vfs)
    if     prefix == 0x7f then
        in_len  = read_u32(vfs) - 9
        out_len = read_u32(vfs)
        buf = vfs:read(in_len) --read_str(vfs, in_len)
        out = lzm.xdecompress(buf, out_len)
    elseif prefix == 0x7e then
        in_len  = read_u32(vfs) - 9
        out_len = read_u32(vfs)
        out = vfs:read(in_len)
    elseif prefix == 0x7d then
        in_len  = read_u8(vfs) - 3
        out_len = read_u8(vfs)
        buf = vfs:read(in_len)
        out = lzm.xdecompress(buf, out_len)
    elseif prefix == 0x7c then
        in_len  = read_u8(vfs) - 3
        out_len = read_u8(vfs)
        out = vfs:read(in_len)
    else
        local str = prefix .. " " .. vfs:seek()
        assert(false, str)
    end
    return out
end



print("\nmake dirs...")
local cnt = 0.05
local max = #dir-1
for k, v in ipairs(dir) do
    local i = k / max
    if i >= cnt then
        io.write(cnt*100 .. "%.")
        cnt = cnt + 0.05
    end
    os.execute("mkdir \"" .. out_dir .. "\\" .. v .. "\" >nul 2>&1")
end



for i = 1, header.num_vfs do
    local hdl = assert(io.open(vfs[i].fullname, "rb"))
    table.insert(handle, hdl)
end

print("\nstart unpack...")
for k, v in ipairs(file) do
    if (ans > 0 and ans == k) or (ans == 0) then
        print("\n" .. vfs[k].name)
        local cnt = 0.05
        local max = #v-1
        for kk, vv in ipairs(v) do

            local i = kk / max
            if i >= cnt then
                io.write(cnt*100 .. "%.")
                cnt = cnt + 0.05
            end

            local w = assert(io.open(out_dir .. "\\" .. vv.fn, "w+b"))
            local hdl = handle[k]
            hdl:seek("set", vv.off)
            if vv.pak == vv.unp then
                local data = hdl:read(vv.pak)
                w:write(data)
            else
                local stop = vv.off + vv.pak
                while read_pos(hdl) < stop do
                    local data = unpack_chunk(hdl)
                    w:write(data)
                end
            end
            w:close()
        end
    end
end


-------------------------------------------------------------------------------
print("\n\nclose files and exit...")
for k, v in ipairs(handle) do
    v:close()
end
os.exit()


