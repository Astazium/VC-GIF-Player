local image = require ("libpng:image")

local M = {}

local blacklist = {
    ["base:sand"] = true,
    ["base:torch"] = true,
    ["base:grass"] = true,
    ["base:flower"] = true,
    ["maybeblocks:intercom"] = true,
    ["maybeblocks:snow_grass"] = true,
    ["maybeblocks:withered_bush"] = true,
    ["maybeblocks:fallen_pebble"] = true,
    ["maybeblocks:fallen_stick"] = true,
    ["maybeblocks:fallen_sakura_flower"] = true,
    ["moreblocks:black_glass"] = true,
    ["moreblocks:white_glass"] = true,
    ["base:glass"] = true,
    ["maybeblocks:glass_black"] = true,
    ["moreblocks:black_concrete_column"] = true
}

local function getBlockTexturesPath()
    local contents = pack.get_installed()
    local blockTextures = {}

    for _, packName in ipairs(contents) do
        local blockConfigs = packName .. ":blocks"
        local ok, files = pcall(file.list, blockConfigs)

        if ok and files then
            for _, fname in ipairs(files) do
                local raw = file.read(fname)
                local parsed = json.parse(raw)

                if parsed then
                    local blockName = packName .. ":" .. file.stem(fname)
                    if not blacklist[blockName] then
                        if block.is_extended(block.index(blockName)) then 

                        else
                            blockTextures[blockName] = blockTextures[blockName] or {}
                            local seen = {}

                            local function addTexture(textureName)
                                local fullPath = file.find("textures/blocks/" .. textureName .. ".png")
                                if fullPath and not seen[fullPath] then
                                    table.insert(blockTextures[blockName], fullPath)
                                    seen[fullPath] = true
                                end
                            end

                            if parsed["texture"] then
                                addTexture(parsed["texture"])
                            end

                            if parsed["texture-faces"] then
                                for _, faceTexture in ipairs(parsed["texture-faces"]) do
                                    addTexture(faceTexture)
                                end
                            end

                            if parsed["model-primitives"] then
                                local primitives = parsed["model-primitives"]

                                if primitives["aabbs"] then
                                    for _, arr in ipairs(primitives["aabbs"]) do
                                        for _, v in ipairs(arr) do
                                            if type(v) == "string" then
                                                addTexture(v)
                                            end
                                        end
                                    end
                                end

                                if primitives["tetragons"] then
                                    for _, arr in ipairs(primitives["tetragons"]) do
                                        for _, v in ipairs(arr) do
                                            if type(v) == "string" then
                                                addTexture(v)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                else
                    print("Ошибка разбора JSON в файле: " .. fname)
                end
            end
        else
            --print("Папка не найдена или ошибка: " .. blockConfigs)
            debug.print(files .. " occurred while trying to process: " .. blockConfigs)
        end
    end

    debug.print(blockTextures)
    return blockTextures
end

local function findAverageColorRGB(pixels)
    if not pixels or #pixels == 0 then
        return {0, 0, 0}
    end

    local rSum, gSum, bSum = 0, 0, 0
    local count = 0

    for i, pixel in ipairs(pixels) do
        local r, g, b = pixel[1], pixel[2], pixel[3]

        if r ~= 0 or g ~= 0 or b ~= 0 then
            rSum = rSum + r
            gSum = gSum + g
            bSum = bSum + b
            count = count + 1
        end
    end

    if count == 0 then
        return {0, 0, 0}
    end

    local avgR = math.floor(rSum / count + 0.5)
    local avgG = math.floor(gSum / count + 0.5)
    local avgB = math.floor(bSum / count + 0.5)

    return {avgR, avgG, avgB}
end

function M.getColorMap()
    local textures = getBlockTexturesPath()
    local result = {}

    for block, texture_paths in pairs(textures) do
        local colors = {}

        for _, texture in pairs(texture_paths) do
            local success, img = pcall(image.from_png, texture)
            if not success or not img then
                debug.print(img .. " occurred while trying to read: " .. texture)
            else
                local rgbPixels = {}
                for i = 1, #img.pixels do
                    local pixel = img.pixels[i]  -- pixel = {r,g,b,a}
                    local r, g, b, a = pixel[1], pixel[2], pixel[3], pixel[4]
                    if a > 0 then
                        table.insert(rgbPixels, {r, g, b})
                    end
                end

                if #rgbPixels > 0 then
                    local avg = findAverageColorRGB(rgbPixels)
                    table.insert(colors, avg)
                end
            end
        end

        if #colors > 0 then
            local sum = {0, 0, 0}
            for _, c in ipairs(colors) do
                for i = 1, 3 do
                    sum[i] = sum[i] + c[i]
                end
            end
            for i = 1, 3 do
                sum[i] = math.floor(sum[i] / #colors + 0.5)
            end

            result[block] = sum
            print("Block:", block, "Color:", unpack(sum))
        end
    end

    return result
end

return M
