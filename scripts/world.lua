local gifplayer = require("gifplayer:gif")
local testing = require("gifplayer:colormap")

-----------------------------------------------

local function hexToRGB(hex)
    if type(hex) == "number" then
        hex = string.format("%06X", hex)
    end
    return { tonumber(hex:sub(1,2),16), tonumber(hex:sub(3,4),16), tonumber(hex:sub(5,6),16) }
end

local function getClosestBlock(blockColors, color)
    local r,g,b = color[1], color[2], color[3]
    local bestBlock, bestDist = nil, math.huge
    for blockName, c in pairs(blockColors) do
        local dr, dg, db = r-c[1], g-c[2], b-c[3]
        local d = dr*dr + dg*dg + db*db
        if d < bestDist then bestDist, bestBlock = d, blockName end
    end
    return bestBlock
end

-----------------------------------------------

local function processFrame(frame, blockColors)
    local result, cache = {}, {}
    for row = 1, #frame do
        local srcRow = frame[row]
        local dstRow = {}
        result[row] = dstRow
        for col = 1, #srcRow do
            local hex = srcRow[col]
            if hex == -1 then
                dstRow[col] = nil
            else
                local blockName = cache[hex]
                if not blockName then
                    blockName = getClosestBlock(blockColors, hexToRGB(hex))
                    cache[hex] = blockName
                end
                dstRow[col] = blockName
            end
        end
    end
    return result
end

local playing = false
local first_frame = nil
local frames_cache = {}
local total_frames = 0
local fps = 10
local frame_timer = 0
local current_frame = 1
local originX, originY, originZ = 0,0,0

local function preprocessFrames(allFrames)
    frames_cache = {}

    local idCache = {}
    local function nameToId(name)
        if not name then return 0 end
        local id = idCache[name]
        if not id then
            id = block.index(name)
            idCache[name] = id
        end
        return id
    end

    first_frame = allFrames[1]
    for r = 1, #first_frame do
        local row = first_frame[r]
        for c = 1, #row do
            row[c] = nameToId(row[c])
        end
    end

    local prev = first_frame
    for f = 2, #allFrames do
        local currNames = allFrames[f]
        local rowRanges = {}  -- [id] -> { {r,c1,c2}, ... }

        for r = 1, #currNames do
            local c = 1
            while c <= #currNames[r] do
                local newId = nameToId(currNames[r][c])
                if newId ~= prev[r][c] then
                    local startC, endC = c, c
                    while endC+1 <= #currNames[r] do
                        local nextId = nameToId(currNames[r][endC+1])
                        if nextId ~= newId or prev[r][endC+1] == newId then break end
                        endC = endC + 1
                    end
                    local list = rowRanges[newId]
                    if not list then list = {}; rowRanges[newId] = list end
                    list[#list+1] = {r, startC, endC}
                    c = endC + 1
                else
                    c = c + 1
                end
            end
        end

        local delta = {}
        for newId, ranges in pairs(rowRanges) do
            table.sort(ranges, function(a,b) return (a[1]==b[1]) and (a[2]<b[2]) or (a[1]<b[1]) end)
            local i = 1
            while i <= #ranges do
                local r, c1, c2 = ranges[i][1], ranges[i][2], ranges[i][3]
                local r1, r2 = r, r
                local j = i + 1
                while j <= #ranges and ranges[j][2]==c1 and ranges[j][3]==c2 and ranges[j][1]==r2+1 do
                    r2 = ranges[j][1]
                    j = j + 1
                end
                local rects = delta[newId]
                if not rects then rects = {}; delta[newId] = rects end
                rects[#rects+1] = {r1, r2, c1, c2}
                i = j
            end
        end

        frames_cache[f] = delta

        prev = {}
        for r = 1, #currNames do
            local rowNames = currNames[r]
            local rowIds = {}
            for c = 1, #rowNames do
                rowIds[c] = nameToId(rowNames[c])
            end
            prev[r] = rowIds
        end
    end
end

local function buildFrameFull(ids2D, ox, oy, oz)
    local h = #ids2D
    for r = 1, h do
        local y = oy + (h - r)
        local row = ids2D[r]
        local c = 1
        while c <= #row do
            local id = row[c]
            if id ~= nil then
                local startC = c
                local endC = c
                while endC + 1 <= #row and row[endC+1] == id do
                    endC = endC + 1
                end
                local baseX = ox + (startC - 1)
                for x = baseX, baseX + (endC - startC) do
                    block.set(x, y, oz, id)
                end
                c = endC + 1
            else
                c = c + 1
            end
        end
    end
end

function on_world_tick()
    if not playing then return end

    frame_timer = frame_timer + 1/20
    local delay = 1 / fps
    if frame_timer < delay then return end
    frame_timer = frame_timer - delay

    local h = #first_frame

    if current_frame == 1 then
        buildFrameFull(first_frame, originX, originY, originZ)
    else
        local delta = frames_cache[current_frame]
        for id, rects in pairs(delta) do
            for i = 1, #rects do
                local r1, r2, c1, c2 = rects[i][1], rects[i][2], rects[i][3], rects[i][4]
                local width = c2 - c1 + 1
                for r = r1, r2 do
                    local y = originY + (h - r)
                    local x0 = originX + (c1 - 1)
                    for dx = 0, width - 1 do
                        block.set(x0 + dx, y, originZ, id)
                    end
                end
            end
        end
    end

    current_frame = current_frame + 1
    if current_frame > total_frames then current_frame = 1 end
end

local function startGIF(fps_, x, y, z)
    fps = fps_ or 10
    originX, originY, originZ = x or 0, y or 0, z or 0
    current_frame = 1
    frame_timer = 0
    playing = true
end

local function stopGIF() playing = false end

function on_world_open()
    if not file.exists(pack.shared_file(PACK_ID, "README.txt")) then
        file.write(pack.shared_file(PACK_ID, "README.txt"), "В этой папке должны находится .gif файлы для воспроизведения.")
    end

    console.add_command("gif.start name:str fps:num x:num y:num z:num", "Start GIF", function(args)
        local filename = args[1]
        local fps_arg = args[2] or 10
        local x, y, z = args[3] or 0, args[4] or 0, args[5] or 0

        local path = pack.shared_file(PACK_ID, filename)
        if not file.exists(path) then return ".gif file not found: "..path end

        local gif = gifplayer(path)
        local blockColors = testing.getColorMap()
        total_frames = gif.get_file_parameters().number_of_images

        local allFrames = {}
        for i = 1, total_frames do
            local matrix = gif.read_matrix()
            allFrames[#allFrames+1] = processFrame(matrix, blockColors)
            gif.next_image("always")
        end
        gif.close()

        preprocessFrames(allFrames)
        startGIF(fps_arg, x, y, z)
        return "Playing..."
    end)

    console.add_command("gif.stop", "Stop GIF", function()
        stopGIF()
        console.log("Stopped")
    end)
end
