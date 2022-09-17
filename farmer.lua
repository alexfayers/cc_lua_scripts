-- A computercraft wheat farmer

-- imports

local logging = require("afscript.core.logging")
local movement = require("afscript.turtle.movement")
local inventory = require("afscript.turtle.inventory")
local state = require("afscript.core.state")
local utils = require("afscript.turtle.utils")
local notify = require("afscript.core.notify")

movement.logger.level = logging.LEVEL.DEBUG

local logger = logging.new("wheatfarmer")

-- define config

local farm_width = 9
local farm_height = 9

local fuel_threshold = 100

local max_seeds = farm_width * farm_height - 1  -- minus 1 for water slot

local fuel_source = "minecraft:charcoal"
local seed_source = "minecraft:wheat_seeds"
local sleep_time = 300

local STATEFILE = ".farmer.state"

local _farm_state = state.load(STATEFILE) or {
    fuel_level = 0,
    time_to_harvest = 0,
    always_plant = true
}

local function _notify(title, message)
    notify.join(
        "CC: Farmer #" .. os.getComputerID() .. " " .. title,
        message
    )
end

local function harvest()
    -- check if the turtle is on top of a fully grown wheat

    local success, data = turtle.inspectDown()
    if success and data.name == "minecraft:wheat" and data.state.age >= 7 then
        return turtle.digDown()
    end
    return false
end

local function plant()
    if inventory.select(seed_source) > 0 then
        turtle.placeDown()
    else
        logger.warn("No wheat seeds found in inventory")
        _notify("No seeds", "No wheat seeds found in inventory")
    end
end

local function harvestAndPlant()
    local did_harvest = harvest()
    if did_harvest == true or _farm_state.always_plant == true then
        plant()
    end

    return did_harvest
end

local function deposit()
    while inventory.select("minecraft:wheat") > 0 do
        logger.info("Depositing wheat ...")
        turtle.dropDown()
    end

    local total_seed_count = inventory.count(seed_source)
    while total_seed_count > max_seeds do
        logger.info("Depositing seeds ...")
        local stack_seed_count = inventory.select(seed_source)
        local extra_seed_count = total_seed_count - max_seeds
        local drop_count = math.min(extra_seed_count, stack_seed_count)

        if turtle.dropDown(drop_count) then
            total_seed_count = total_seed_count - drop_count
        end
    end
end

local function depositIfChest()
    local success, data = turtle.inspectDown()
    if success and data.name == "minecraft:chest" then
        deposit()
    end
end

local function farm()
    local harvest_count = 0
    movement.moveTo(0, 0, 0)
    movement.face("north")

    -- do the first plant
    movement.forward()
    if harvestAndPlant() then 
        harvest_count = harvest_count + 1
    end

    -- do the whole farm
    for i = 1, farm_width do
        for j = 1, (farm_height - 1) do
            if i ~= farm_width or j ~= (farm_height - 1) then
                movement.forward()
            end
            if harvestAndPlant() then 
                harvest_count = harvest_count + 1
            end
        end
        if i ~= farm_width then
            if i % 2 == 0 then
                movement.turnLeft()
                movement.forward()
                movement.turnLeft()
            else
                movement.turnRight()
                movement.forward()
                movement.turnRight()
            end
        else
            movement.forward()
        end
        if harvestAndPlant() then 
            harvest_count = harvest_count + 1
        end
    end
    movement.moveTo(0, 0, 0)
    movement.face("north")

    _notify("Harvested", harvest_count .. " wheat harvested")
end

local function main()
    while true do
        while _farm_state.time_to_harvest > 0 do
            if _farm_state.time_to_harvest % 60 == 0 then
                logger.info("Waiting " .. _farm_state.time_to_harvest .. " seconds before harvesting again")
            end

            sleep(1)
            _farm_state.time_to_harvest = _farm_state.time_to_harvest - 1
            state.save(_farm_state, STATEFILE)
        end

        utils.refuel(fuel_source, fuel_threshold)
        farm()
        depositIfChest()
        inventory.compact()  -- compact inventory to make everything neat

        -- only always plant on the first run
        if _farm_state.always_plant == true then
            _farm_state.always_plant = false
        end

        _farm_state.time_to_harvest = sleep_time  -- wait 20 minutes before harvesting again
        state.save(_farm_state, STATEFILE)
    end
end

function test()
    logger.info("Testing ...")
    logger.info("Fuel level: " .. turtle.getFuelLevel())
    logger.info("Position: " .. _farm_state.position.x .. ", " .. _farm_state.position.y .. ", " .. _farm_state.position.z)
    logger.info("Direction: " .. _farm_state.direction)
    logger.info("Fuel threshold: " .. fuel_threshold)
    logger.info("Farm width: " .. farm_width)
    logger.info("Farm height: " .. farm_height)
    logger.info("Tesing movement ...")
    movement.moveTo(2, 0, 0)
    movement.moveTo(0, 0, 0)
    movement.moveTo(0, 2, 0)
    movement.moveTo(0, 0, 0)
    movement.moveTo(0, 0, 2)
    movement.moveTo(0, 0, 0)

    movement.moveTo(-2, 0, 0)
    movement.moveTo(0, 0, 0)
    movement.moveTo(0, -2, 0)
    movement.moveTo(0, 0, 0)
    movement.moveTo(0, 0, -2)
    movement.moveTo(0, 0, 0)

    logger.info("Position: " .. _farm_state.position.x .. ", " .. _farm_state.position.y .. ", " .. _farm_state.position.z)

    -- moveTo(0, 0, 0)
    logger.info("Testing done")
end

main()
