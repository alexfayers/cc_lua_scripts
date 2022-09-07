-- A computercraft wheat farmer

-- define config

local farm_width = 9
local farm_height = 9

local fuel_threshold = 100

local state = {
    position = {
        x = 0,
        y = 0,
        z = 0,
    },
    direction = "north",
    fuel_level = 0
}

function logTime()
    return os.date("%H:%M:%S")
end

function saveState()
    local file = fs.open("state", "w")
    file.writeLine(textutils.serialize(state))
    file.close()
end

function loadState()
    local file = fs.open("state", "r")
    state = textutils.unserialize(file.readAll())
    file.close()
end

function log(msg)
    msg = logTime() .. " I: " .. msg
    print(msg)
    local file = fs.open("farmer.log", "a")
    file.writeLine(msg)
    file.close()
end

function debugLog(msg)
    msg = logTime() .. " D: " .. msg
    print(msg)
    local file = fs.open("farmer.log", "a")
    file.writeLine(msg)
    file.close()
end

function selectFromInventory(item_name)
    for i = 1, 16 do
        turtle.select(i)
        local item = turtle.getItemDetail()
        if item ~= nil and item.name == item_name then
            return true
        end
    end
    return false
end

function refuel()
    while turtle.getFuelLevel() < fuel_threshold do
        log("Refueling ...")
        if selectFromInventory("minecraft:coal") then
            turtle.refuel(1)
        else
            error("Ran out of fuel!")  -- TODO: notify
        end
    end
end

function turnLeft()
    turtle.turnLeft()
    if state.direction == "north" then
        state.direction = "west"
    elseif state.direction == "west" then
        state.direction = "south"
    elseif state.direction == "south" then
        state.direction = "east"
    elseif state.direction == "east" then
        state.direction = "north"
    end

    saveState()
end

function turnRight()
    turtle.turnRight()
    if state.direction == "north" then
        state.direction = "east"
    elseif state.direction == "east" then
        state.direction = "south"
    elseif state.direction == "south" then
        state.direction = "west"
    elseif state.direction == "west" then
        state.direction = "north"
    end

    saveState()
end

function turnAround()
    turnLeft()
    turnLeft()
end

function moveForward()
    local success = turtle.forward()
    if success then
        if state.direction == "north" then
            state.position.z = state.position.z - 1
        elseif state.direction == "east" then
            state.position.x = state.position.x + 1
        elseif state.direction == "south" then
            state.position.z = state.position.z + 1
        elseif state.direction == "west" then
            state.position.x = state.position.x - 1
        end
        saveState()
    end

    log("Moved to " .. state.position.x .. ", " .. state.position.y .. ", " .. state.position.z)

    return success
end

function moveUp()
    local success = turtle.up()
    if success then
        state.position.y = state.position.y + 1
        saveState()
    end

    return success
end

function moveDown()
    local success = turtle.down()
    if success then
        state.position.y = state.position.y - 1
        saveState()
    end

    return success
end

function faceDirection(direction)
    if state.direction == direction then
        return
    end

    if state.direction == "north" then
        if direction == "east" then
            turnRight()
        elseif direction == "south" then
            turnAround()
        elseif direction == "west" then
            turnLeft()
        end
    elseif state.direction == "east" then
        if direction == "south" then
            turnRight()
        elseif direction == "west" then
            turnAround()
        elseif direction == "north" then
            turnLeft()
        end
    elseif state.direction == "south" then
        if direction == "west" then
            turnRight()
        elseif direction == "north" then
            turnAround()
        elseif direction == "east" then
            turnLeft()
        end
    elseif state.direction == "west" then
        if direction == "north" then
            turnRight()
        elseif direction == "east" then
            turnAround()
        elseif direction == "south" then
            turnLeft()
        end
    end
end

function moveTo(x, y, z)
    while state.position.x ~= x do
        if state.position.x < x then
            faceDirection("east")
        elseif state.position.x > x then
            faceDirection("west")
        end
        if moveForward() == false then
            -- TODO: move around?
            error("Failed to move to " .. x .. ", " .. y .. ", " .. z)
        end
    end
    while state.position.z ~= z do
        if state.position.z < z then
            faceDirection("south")
        elseif state.position.z > z then
            faceDirection("north")
        end
        if moveForward() == false then
            error("Failed to move to " .. x .. ", " .. y .. ", " .. z)
        end
    end
    while state.position.y ~= y do
        if state.position.y < y then
            if moveUp() == false then
                error("Failed to move to " .. x .. ", " .. y .. ", " .. z)
            end
        elseif state.position.y > y then
            if moveDown() == false then
                error("Failed to move to " .. x .. ", " .. y .. ", " .. z)
            end
        end
    end
end

function harvest()
    -- check if the turtle is on top of a fully grown wheat

    local success, data = turtle.inspectDown()
    if success and data.name == "minecraft:wheat" and data.state.age == "7" then
        turtle.digDown()
    end
end

function plant()
    if selectFromInventory("minecraft:wheat_seeds") then
        turtle.placeDown()
    else
        log("No wheat seeds found in inventory")  -- TODO: notify
    end
end

function farm()
    moveTo(0, 0, 0)
    faceDirection("north")
    for i = 1, (farm_width - 1) do
        for j = 1, (farm_height - 1) do
            if i ~= farm_width or j ~= farm_height then
                moveForward()
            end
            harvest()
            plant()
        end
        if i % 2 == 0 then
            turnLeft()
            moveForward()
            turnLeft()
        else
            turnRight()
            moveForward()
            turnRight()
        end
        harvest()
        plant()
    end
    moveTo(0, 0, 0)
    faceDirection("north")
end

function main()
    if fs.exists("state") then
        loadState()
    else
        saveState()
    end
    while true do
        refuel()
        farm()
        sleep(60)
    end
end

function test()
    if fs.exists("state") then
        loadState()
    else
        saveState()
    end

    log("Testing ...")
    log("Fuel level: " .. turtle.getFuelLevel())
    log("Position: " .. state.position.x .. ", " .. state.position.y .. ", " .. state.position.z)
    log("Direction: " .. state.direction)
    log("Fuel threshold: " .. fuel_threshold)
    log("Farm width: " .. farm_width)
    log("Farm height: " .. farm_height)
    log("Tesing movement ...")
    moveTo(2, 0, 0)
    moveTo(0, 0, 0)
    moveTo(0, 2, 0)
    moveTo(0, 0, 0)
    moveTo(0, 0, 2)
    moveTo(0, 0, 0)

    moveTo(-2, 0, 0)
    moveTo(0, 0, 0)
    moveTo(0, -2, 0)
    moveTo(0, 0, 0)
    moveTo(0, 0, -2)
    moveTo(0, 0, 0)

    log("Position: " .. state.position.x .. ", " .. state.position.y .. ", " .. state.position.z)

    -- moveTo(0, 0, 0)
    log("Testing done")
end

main()
