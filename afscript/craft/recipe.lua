---Functions to fetch crafting recipes for minecraft item ids

local logging = require("afscript.core.logging")
local logger = logging.new("afscript.craft.recipe")

---Get the crafting recipe for a given item id from the github repo
---@param item_id string _ The item id to get the recipe for
---@return table|nil _ The crafting recipe for the given item id
local function getRaw(item_id)
    local base_url = "https://raw.githubusercontent.com/alexfayers/cc_lua_scripts/main/_recipes/"

    local res = http.get(base_url .. item_id .. ".json")

    if res == nil then
        logger.error("Could not fetch recipe for item id '" .. item_id .. "'")
        return
    end

    local recipe = textutils.unserialiseJSON(res.readAll())

    if recipe == nil then
        logger.error("Could not decode recipe for item id '" .. item_id .. "'")
        return
    end

    return recipe
end

---Convert a raw recipe into a table of items in the correct pattern for the 3x3 crafting grid
---@param raw_recipe table _ The raw recipe to convert
---@return table _ The converted recipe
local function convertToPattern(raw_recipe)
    -- raw_recipe example:
    -- {
    --     "type": "minecraft:crafting_shaped",
    --     "key": {
    --         "I": {
    --         "item": "minecraft:iron_block"
    --         },
    --         "i": {
    --         "item": "minecraft:iron_ingot"
    --         }
    --     },
    --     "pattern": [
    --         "III",
    --         " i ",
    --         "iii"
    --     ],
    --     "result": {
    --         "item": "minecraft:anvil"
    --     }
    -- }

    local recipe = {
        {"", "", ""},
        {"", "", ""},
        {"", "", ""}
    }

    if raw_recipe.type == "minecraft:crafting_shaped" then
        --- handle shaped crafting
        for row_index, row in pairs(raw_recipe.pattern) do
            local column_index = 1
            for column in row:gmatch"." do
                if column ~= " " then
                    recipe[row_index][column_index] = raw_recipe.key[column].item
                else
                    recipe[row_index][column_index] = ""
                end
                column_index = column_index + 1
            end
        end
    elseif raw_recipe.type == "minecraft:crafting_shapeless" then
        --- handle shapeless crafting
        for index, item in pairs(raw_recipe.ingredients) do
            local row_index = math.floor((index - 1) / 3) + 1
            local column_index = (index - 1) % 3 + 1

            if item[1] then
                recipe[row_index][column_index] = item[1].item
            else
                recipe[row_index][column_index] = item.item
            end
        end
    else
        logger.error("Unsupported recipe type '" .. raw_recipe.type .. "'")
    end

    return recipe
end

---Get the crafting recipe for a given item id
---@param item_id string _ The item id to get the recipe for
---@return table|nil _ The crafting recipe for the given item id, or nil if the recipe could not be found
local function get(item_id)
    local raw_recipe = getRaw(item_id)
    if raw_recipe == nil then
        return
    end

    return convertToPattern(raw_recipe)
end

return {
    get = get
}
