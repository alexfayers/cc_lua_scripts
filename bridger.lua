-- turtle script to bridge gaps

-- constants

local args = {...}
local bridge_block = args[1]
local bridge_length = tonumber(args[2])

-- functions

function selectFromInventory(item_name)
    for i = 1, 16 do
        turtle.select(i)
        local item = turtle.getItemDetail()
        if item ~= nil and item.name == item_name then
            return item.count
        end
    end
    return 0
end

function placeBlocks()
    if turtle.detectDown() == false then
        selectFromInventory(bridge_block)
        turtle.placeDown()
    end

    turtle.turnLeft()

    if turtle.detect() == false then
        selectFromInventory(bridge_block)
        turtle.place()
    end

    turtle.turnRight()
    turtle.turnRight()

    if turtle.detect() == false then
        selectFromInventory(bridge_block)
        turtle.place()
    end

    turtle.turnLeft()
end

function bridgeGap(length)
    for i = 1, length do
        placeBlocks()

        if turtle.detect() then
            turtle.dig()
        end

        turtle.forward()
    end
end

function come_back(length)
    turtle.turnLeft()
    turtle.turnLeft()
    for i = 1, length do
        turtle.forward()
    end
    turtle.turnLeft()
    turtle.turnLeft()
end

function main()
    bridgeGap(bridge_length)
    come_back(bridge_length)
end

main()
