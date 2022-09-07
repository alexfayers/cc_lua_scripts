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
    msg = os.date("%c") .. " " .. msg
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
    if turtle.getFuelLevel() < fuel_threshold then
        log("Refueling ...")
        if selectFromInventory("minecraft:coal") then
            turtle.refuel(1)
        else
            log("No coal found in inventory")
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
    if turtle.forward() then
        if state.direction == "north" then
            state.position.z = state.position.z - 1
        elseif state.direction == "east" then
            state.position.x = state.position.x + 1
        elseif state.direction == "south" then
            state.position.z = state.position.z + 1
        elseif state.direction == "west" then
            state.position.x = state.position.x - 1
        end
    end

    log("Moved to " .. state.position.x .. ", " .. state.position.y .. ", " .. state.position.z)

    saveState()
end

function moveUp()
    if turtle.up() then
        state.position.y = state.position.y + 1
    end

    saveState()
end

function moveDown()
    if turtle.down() then
        state.position.y = state.position.y - 1
    end

    saveState()
end

function moveTo(x, y, z)
    while state.position.x ~= x do
        if state.position.x < x then
            if state.direction == "north" then
                turnRight()
            elseif state.direction == "east" then
                -- do nothing
            elseif state.direction == "south" then
                turnLeft()
            elseif state.direction == "west" then
                turnAround()
            end
        else
            if state.direction == "north" then
                turnLeft()
            elseif state.direction == "east" then
                turnAround()
            elseif state.direction == "south" then
                turnRight()
            elseif state.direction == "west" then
                -- do nothing
            end
        end
        moveForward()
    end
    while state.position.z ~= z do
        if state.position.z < z then
            if state.direction == "north" then
                turnAround()
            elseif state.direction == "east" then
                turnLeft()
            elseif state.direction == "south" then
                -- do nothing
            elseif state.direction == "west" then
                turnRight()
            end
        else
            if state.direction == "north" then
                -- do nothing
            elseif state.direction == "east" then
                turnRight()
            elseif state.direction == "south" then
                turnAround()
            elseif state.direction == "west" then
                turnLeft()
            end
        end
        moveForward()
    end
    while state.position.y ~= y do
        if state.position.y < y then
            moveUp()
        else
            moveDown()
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
        log("No wheat seeds found in inventory")
    end
end

function farm()
    for i = 1, farm_width do
        for j = 1, farm_height do
            harvest()
            plant()
            if i ~= farm_width or j ~= farm_height then
                moveForward()
            end
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
    end
    moveTo(0, 0, 0)
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
    turnAround()
    log("Position: " .. state.position.x .. ", " .. state.position.y .. ", " .. state.position.z)

    -- moveTo(0, 0, 0)
    log("Testing done")
end

test()
