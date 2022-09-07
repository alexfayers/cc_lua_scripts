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
end

function moveBackward()
    if turtle.back() then
        if state.direction == "north" then
            state.position.z = state.position.z + 1
        elseif state.direction == "east" then
            state.position.x = state.position.x - 1
        elseif state.direction == "south" then
            state.position.z = state.position.z - 1
        elseif state.direction == "west" then
            state.position.x = state.position.x + 1
        end
    end
end

function moveUp()
    if turtle.up() then
        state.position.y = state.position.y + 1
    end
end

function moveDown()
    if turtle.down() then
        state.position.y = state.position.y - 1
    end
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
                -- do nothing
            elseif state.direction == "east" then
                turnLeft()
            elseif state.direction == "south" then
                turnAround()
            elseif state.direction == "west" then
                turnRight()
            end
        else
            if state.direction == "north" then
                turnAround()
            elseif state.direction == "east" then
                turnRight()
            elseif state.direction == "south" then
                -- do nothing
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
    if turtle.detectDown() then
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
    for i = 1, farm_width * farm_height do
        plant()
        moveForward()
    end
    moveTo(0, 0, 0)
end

function main()
    while true do
        refuel()
        farm()
        sleep(60)
    end
end

main()
