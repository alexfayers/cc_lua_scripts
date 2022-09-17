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


---Stack all items in the turtle's inventory by attempting to place items in each slot
---Into every other slot. Sorting is complete when no items are moved.
local function _stack()
    local sorted = false
    while not sorted do
        sorted = true
        for i = 16, 1, -1 do
            local item = turtle.getItemDetail(i)
            if item ~= nil then
                turtle.select(i)
                for j = 1, 16 do
                    if i ~= j then
                        if turtle.compareTo(j) and turtle.transferTo(j) then
                            sorted = false
                            break
                        end
                    end
                end
            end
        end
    end
end


---Move all items in the turtle's inventory to the beginning of the inventory
---This is done by stacking the inventory, then moving items to the beginning
---of the inventory.
local function _compact()
    _stack()

    for i = 16, 1, -1 do
        local item = turtle.getItemDetail(i)
        if item ~= nil then
            turtle.select(i)
            for j = 1, 16 do
                if j > i then
                    break
                end
                if i ~= j then
                    local other_item = turtle.getItemDetail(j)
                    if other_item == nil and turtle.transferTo(j) then
                        break
                    end
                end
            end
        end
    end
end


return {
    select = _select,
    count = _count,
    dump = _dump,
    stack = _stack,
    compact = _compact,
    logger = logger,
}
