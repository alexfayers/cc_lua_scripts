-- Functions for interaction with the outside world

local inventory = require("afscript.turtle.inventory")

---Place a block in front of the turtle of the specified type
---@param block_name string The name of the block to place
---@return boolean _ True if the block was placed, false otherwise
local function _placeBlock(block_name)
    assert(type(block_name) == "string", "block_name must be a string")

    local success = false

    if inventory.select(block_name) > 0 then
        success = turtle.place()
    end

    return success
end

---Place a block below the turtle of the specified type
---@param block_name string The name of the block to place
---@return boolean _ True if the block was placed, false otherwise
local function _placeBlockDown(block_name)
    assert(type(block_name) == "string", "block_name must be a string")

    local success = false

    if inventory.select(block_name) > 0 then
        success = turtle.placeDown()
    end

    return success
end

return {
    placeBlock = _placeBlock,
    placeBlockDown = _placeBlockDown
}