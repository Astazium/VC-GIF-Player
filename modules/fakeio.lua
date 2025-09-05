local buffer = require "core:data_buffer"

local M = {}

local buff = buffer({}, "LE", true)

function M.open(filename)
    assert(file.isfile(filename), 
           "Path to file doesn't exist or it's not a file")
    assert(buff:size() == 0, "Can't open new file while other file is open")

    local ok, rawbytearray = pcall(file.read_bytes, filename, false)
    assert(ok and rawbytearray, "Can't read the file: " .. tostring(rawbytearray))

    buff:set_bytes(rawbytearray)
    buff:set_position(1)
    return M
end

function M:seek(whence, offset)
    whence = whence or "cur"
    offset = offset or 0
    local new_pos

    if whence == "set" then
        offset = math.max(0, math.min(offset, buff:size()))
        new_pos = offset + 1
    elseif whence == "cur" then
        new_pos = buff.pos + offset
        new_pos = math.max(1, math.min(new_pos, buff:size() + 1))
    elseif whence == "end" then
        new_pos = buff:size() + offset + 1
        new_pos = math.max(1, math.min(new_pos, buff:size() + 1))
    else
        return nil, "invalid whence"
    end

    buff:set_position(new_pos)
    return new_pos
end

function M:read(fmt)
    fmt = fmt or 1

    if type(fmt) == "number" then
        if buff.pos > buff:size() then return nil end
        local n = math.min(fmt, buff:size() - buff.pos + 1)
        local bytes = buff:get_bytes(n)

        if n < fmt then
            local temp = Bytearray()
            temp:append(bytes)
            temp:append(Bytearray(fmt - n))
            bytes = temp
        end

        return Bytearray_as_string(bytes)
    end

    if fmt == "*all" then
        if buff.pos > buff:size() then return nil end
        local bytes = buff:get_bytes(buff:size() - buff.pos + 1)
        buff:seek("set", buff:size())
        return Bytearray_as_string(bytes)
    elseif fmt == "*line" then
        if buff.pos > buff:size() then return nil end
        local line = Bytearray()
        while buff.pos <= buff:size() do
            local b = buff:get_bytes(1)[1]
            if b == 10 then break end
            if b ~= 13 then line:append(b) end
        end
        return #line > 0 and Bytearray_as_string(line) or nil
    elseif fmt == "*number" then
        local line = Bytearray()
        while buff.pos <= buff:size() do
            local b = buff:get_bytes(1)[1]
            local c = string.char(b)
            if not c:match("[%d%+%-%e%.]") then
                buff:seek("cur", -1)
                break
            end
            line:append(b)
        end
        if #line == 0 then return nil end
        return tonumber(Bytearray_as_string(line))
    else
        return nil, "invalid format"
    end
end

function M:close()
    buff:set_bytes({})
    buff:set_position(1)
end

return M
