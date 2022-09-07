-- A computercraft wheat farmer

-- define config

local farm_width = 9
local farm_height = 9

local fuel_threshold = 100

local max_seeds = farm_width * farm_height - 1  -- minus 1 for water slot

local fuel_source = "minecraft:charcoal"

local state = {
    position = {
        x = 0,
        y = 0,
        z = 0,
    },
    direction = "north",
    fuel_level = 0,
    time_to_harvest = 0,
    always_plant = true
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
            return item.count
        end
    end
    return 0
end

function inventoryCount(item_name)
    local count = 0
    for i = 1, 16 do
        turtle.select(i)
        local item = turtle.getItemDetail()
        if item ~= nil and item.name == item_name then
            count = count + item.count
        end
    end
    return count
end

function refuel()
    while turtle.getFuelLevel() < fuel_threshold do
        log("Refueling ...")
        if selectFromInventory(fuel_source) > 0 then
            turtle.refuel(1)
        else
            log("Ran out of fuel locally - trying chest!")  -- TODO: notify
            pullFuelFromChest()
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
    if success and data.name == "minecraft:wheat" and data.state.age >= 7 then
        return turtle.digDown()
    end
    return false
end

function plant()
    if selectFromInventory("minecraft:wheat_seeds") > 0 then
        turtle.placeDown()
    else
        log("No wheat seeds found in inventory")  -- TODO: notify
    end
end

function harvestAndPlant()
    if harvest() == true or state.always_plant == true then
        plant()
    end
end

function deposit()
    log("Depositing wheat ...")
    while selectFromInventory("minecraft:wheat") > 0 do
        turtle.dropDown()
    end

    log("Depositing seeds ...")
    local total_seed_count = inventoryCount("minecraft:wheat_seeds")
    while total_seed_count > max_seeds do
        log("got enough seeds - depositing extras")
        local stack_seed_count = selectFromInventory("minecraft:wheat_seeds")
        local extra_seed_count = total_seed_count - max_seeds
        local drop_count = math.min(extra_seed_count, stack_seed_count)

        if turtle.dropDown(drop_count) then
            total_seed_count = total_seed_count - drop_count
        end
    end
end

function depositIfChest()
    local success, data = turtle.inspectDown()
    if success and data.name == "minecraft:chest" then
        deposit()
    end
end

function pullFuelFromChest()
    local success, data = turtle.inspectDown()
    if success and data.name == "minecraft:chest" then
        if checkItemFirstInChest(fuel_source) then
            turtle.suckDown()
        else
            error("No fuel found in chest")  -- TODO: notify
        end
    end
end

function checkItemFirstInChest(searchItem)
    local chest = peripheral.wrap("bottom")

    for i = 1, chest.size() do
        local item = chest.getItemDetail(i)
        if item ~= nil and item.name == searchItem then
            return true
        end
    end

    return false
end

function farm()
    moveTo(0, 0, 0)
    faceDirection("north")

    -- do the first plant
    moveForward()
    harvestAndPlant()

    -- do the whole farm
    for i = 1, farm_width do
        for j = 1, (farm_height - 1) do
            if i ~= farm_width or j ~= (farm_height - 1) then
                moveForward()
            end
            harvestAndPlant()
        end
        if i ~= farm_width then
            if i % 2 == 0 then
                turnLeft()
                moveForward()
                turnLeft()
            else
                turnRight()
                moveForward()
                turnRight()
            end
        else
            moveForward()  -- is this right?
        end
        harvestAndPlant()
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
        while state.time_to_harvest > 0 do
            if state.time_to_harvest % 60 == 0 then
                log("Waiting " .. state.time_to_harvest .. " seconds before harvesting again")
            end

            sleep(1)
            state.time_to_harvest = state.time_to_harvest - 1
            saveState()
        end

        refuel()
        farm()
        depositIfChest()

        -- only always plant on the first run
        if state.always_plant == true then
            state.always_plant = false
        end

        state.time_to_harvest = 600  -- wait 10 minutes before harvesting again
        saveState()
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
