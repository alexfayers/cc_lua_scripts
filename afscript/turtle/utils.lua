-- Misc functions for turtles

local logging = require("afscript.core.logging")
local inventory = require("afscript.turtle.inventory")

local logger = logging.new("turtle.utils")

---Check that an item is contained within a chest
---@param chest table The wrapped chest to check
---@param item_name string The name of the item to check
---@return boolean _ True if the item is in the chest
local function _checkItemInChest(chest, item_name)
    for i = 1, chest.size() do
        local item = chest.getItemDetail(i)
        if item ~= nil and item.name == item_name then
            return true
        end
    end
    return false
end

---Pull an item from the chest below the turtle
---@param item_name string The name of the item to pull
---@return boolean _ True if the item was pulled successfully
local function _pullFromChestBelow(item_name)
    local success, data = turtle.inspectDown()
    if success and data.name == "minecraft:chest" then
        local chest = peripheral.wrap("down")

        if _checkItemInChest(chest, item_name) then
            return turtle.suckDown()
        else
            logger.warn("No " .. item_name .. " in chest!") -- TODO: notify
        end
    else
        logger.warn("No chest below turtle!") -- TODO: notify
    end
    return false
end

---Refuel the turtle to a specified level, using a specified fuel item
---@param fuel_name string The name of the fuel item to use
---@param fuel_threshold number The level to refuel to
---@return boolean _ True if the turtle was refueled to the target level, false if not
local function _refuel(fuel_name, fuel_threshold)
    while turtle.getFuelLevel() < fuel_threshold do
        logger.debug("Refueling ...")
        if inventory.select(fuel_name) > 0 then
            turtle.refuel(1)
        else
            logger.warn("Ran out of fuel locally - trying chest!") -- TODO: notify
            if not _pullFromChestBelow(fuel_name) then
                logger.error("Ran out of fuel!")
                return false
            end
        end
    end
    return true
end

return {
    checkItemInChest = _checkItemInChest,
    pullFromChestBelow = _pullFromChestBelow,
    refuel = _refuel,
    logger = logger,
}
