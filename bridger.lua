-- Turtle script to bridge gaps

-- imports

local logging = require("afscript.logging")
local movement = require("afscript.turtle.movement")
local interaction = require("afscript.turtle.interaction")

local logger = logging.new("bridgebot")

-- constants

local args = {...}
local bridge_block = args[1]
local bridge_length = tonumber(args[2])

-- functions

---Place blocks below and left and right of the turtle
local function placeBlocks()
    interaction.placeBlockDown(bridge_block)

    movement.turnLeft()

    interaction.placeBlock(bridge_block)

    movement.turnRight()
    movement.turnRight()

    interaction.placeBlock(bridge_block)

    movement.turnLeft()

    logger.debug("Completed one slot")
end

---Place blocks in a row
local function bridgeGap(length)
    for i = 1, length do
        placeBlocks()

        if turtle.detect() then
            turtle.dig()
        end

        movement.forward()
    end
    logger.debug("Completed bridge")
end

---Build a bridge
local function main()
    bridgeGap(bridge_length)
    -- movement.moveTo(0,0,0)
end

main()
