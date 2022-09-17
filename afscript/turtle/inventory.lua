-- Turtle inventory management functions

local logging = require("afscript.core.logging")
local logger = logging.new("turtle.inventory")

---Select an item with an exact name from the turtle's inventory
---@param item_name string The name of the item to select
---@return number _ The number of items in the inventory if the item is selected, or 0 if the item is not found
local function _select(item_name)
    for i = 1, 16 do
        local item = turtle.getItemDetail(i)
        if item ~= nil and item.name == item_name then
            turtle.select(i)
            logger.debug("Selected slot " .. i .. " for " .. item_name)
            return item.count
        end
    end
    return 0
end

---Get the total count of an item in the turtle's inventory
---@param item_name string The name of the item to count
---@return number _ The number of items in the inventory
local function _count(item_name)
    local count = 0
    for i = 1, 16 do
        local item = turtle.getItemDetail(i)
        if item ~= nil and item.name == item_name then
            count = count + item.count
        end
    end
    logger.debug("Found " .. count .. " of " .. item_name)
    return count
end

---Dump all items matching above the turtle
---@param item_name string The name of the item to dump
---@return number _ The number of items dumped
local function _dump(item_name)
    local count = 0
    for i = 1, 16 do
        local item = turtle.getItemDetail(i)
        if item ~= nil and item.name == item_name then
            turtle.select(i)
            turtle.dropUp()
            count = count + item.count
        end
    end
    logger.debug("Dumped " .. count .. " of " .. item_name)
    return count
end


return {
    select = _select,
    count = _count,
    dump = _dump,
    logger = logger,
}
