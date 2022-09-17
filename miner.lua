-- Strip mine bot

-- imports

local logging = require("afscript.core.logging")
local movement = require("afscript.turtle.movement")
local inventory = require("afscript.turtle.inventory")
local state = require("afscript.core.state")
local utils = require("afscript.turtle.utils")

-- movement.logger.level = logging.LEVEL.DEBUG

local logger = logging.new("stripmine")

logger.level = logging.LEVEL.DEBUG

local STATEFILE = ".stripmine.state"

local _mine_state = state.load(STATEFILE) or {
    home_location = {
        x = 0,
        y = 0,
        z = 0,
        direction = "north"
    },
}

local _bad_blocks = {
    "minecraft:dirt",
    "minecraft:cobblestone",
    "minecraft:gravel",
    "minecraft:tuff",
    "minecraft:andesite",
    "minecraft:diorite",
    "minecraft:granite",
}


-- blocks to leave between each branch
local branch_spacing = 3
-- number of blocks to mine in each branch
local branch_length = 47
-- total number of pairs of branches
local branch_pair_count = 4
-- check if enough fuel before mining
local prerun_fuel_check = true
-- whether to place torches in the stripmine
local do_place_torches = true
-- amount of blocks that torch light travels
local torch_light = 12
-- current light level on the turtle
local current_light_level = 0


local function _getFuelRequired(branch_spacing, branch_length, branch_pair_count)
    return (
        (
            branch_spacing + 1
        )  -- spacing between branches, plus 1 for the connection between branches
        + (
            branch_length * 4 + 1
        )  -- length of mining each branch and going back to main
    ) * branch_pair_count
end


---Check if the turtle has enough fuel to get back home
---and return to the main branch if it does not, otherwise move forward
local function _fuelCheckForward()
    local fuel_required = movement.distance(
        movement.current_position.x,
        movement.current_position.y,
        movement.current_position.z,
        _mine_state.home_location.x,
        _mine_state.home_location.y,
        _mine_state.home_location.z
    )
    if turtle.getFuelLevel() < fuel_required then
        logger.warn("Not enough fuel to mine this branch, refueling")
        local did_refuel = (
            utils.refuel("minecraft:coal", fuel_required)
            or utils.refuel("minecraft:charcoal", fuel_required)
        )

        if not did_refuel then
            logger.error("Could not refuel, heading home")
            movement.moveTo(_mine_state.home_location.x, _mine_state.home_location.y, _mine_state.home_location.z)
            return false
        end
    end

    return movement.forward()
end


---Dump bad blocks
local function _dumpBadBlocks()
    for _, bad_block in ipairs(_bad_blocks) do
        local did_drop = true
        local dumped_count = 0
        while did_drop do
            dumped_count = inventory.dump(bad_block)
            if dumped_count > 0 then
                logger.info("Dropped " .. dumped_count .. " " .. bad_block)
            end
            did_drop = dumped_count > 0
        end
    end
end


---Place a torch if needed
local function _placeTorchIfNeeded()
    if inventory.select("minecraft:torch") > 0 then
        if turtle.placeUp() then
            logger.debug("Placed torch at " .. movement.current_position.x .. ", " .. movement.current_position.y .. ", " .. movement.current_position.z)
            current_light_level = torch_light
        else
            logger.debug("Could not place torch at " .. movement.current_position.x .. ", " .. movement.current_position.y .. ", " .. movement.current_position.z)
        end
    else
        do_place_torches = false
    end
end


local function mine()
    -- fuel check
    local required_fuel = _getFuelRequired(branch_spacing, branch_length, branch_pair_count)
    if prerun_fuel_check then
        local fuel_level = turtle.getFuelLevel()
        if fuel_level < required_fuel then
            logger.error("Not enough fuel to complete trip. Need " .. required_fuel - fuel_level .. " more.")
            return
        end
    end

    -- torch check
    local required_torches = math.ceil(branch_length / torch_light) * branch_pair_count
    local current_torches = inventory.count("minecraft:torch")

    if current_torches < required_torches then
        logger.error("Not enough torches to complete trip. Need " .. required_torches - current_torches .. " more.")
        return
    end

    -- mine

    for _ = 1, branch_pair_count do
        -- continue main branch
        logger.info("Continuing main branch")
        for _ = 1, branch_spacing + 1 do
            turtle.dig()
            movement.forward()
            turtle.digUp()
        end

        -- update home location current point on main branch
        _mine_state.home_location = movement.current_position

        -- mine left branch
        movement.turnLeft()
        for branch_side = 1, 2 do
            if branch_side == 1 then logger.info("Mining left branch") else logger.info("Mining right branch") end

            for _ = 1, branch_length do
                turtle.dig()
                if not _fuelCheckForward() then
                    -- we ran out of fuel and returned to home
                    return
                end
                turtle.digUp()
            end

            -- go back to main branch
            movement.turnAround()

            -- dump inventory of trash
            logger.info("Dumping trash")
            _dumpBadBlocks()

            logger.info("Heading back to main branch")

            -- start lighting and heading back
            local first_torch = true
            current_light_level = torch_light
            for branch_position = 1, branch_length do
                -- place torches if necessary
                local target_light
                if not first_torch then target_light = -(torch_light + 1) else target_light = 0 end

                if do_place_torches and current_light_level <= target_light then
                    if first_torch then
                        first_torch = false
                    end

                    _placeTorchIfNeeded()
                end

                turtle.dig()
                movement.forward()  -- just move forward, no need to check fuel since we're already heading to the safe spot
                turtle.digUp()

                current_light_level = current_light_level - 1

                -- at end of branch if there's not enough light, slap a torch down
                if branch_position == branch_length - 1 and do_place_torches and current_light_level <= -1 then
                    _placeTorchIfNeeded()
                end
            end

            if branch_side == 1 then
                logger.info("Completed left branch")
            else
                logger.info("Completed right branch")
            end
        end

        logger.info("Completed branch pair")
        -- face forward again to prepare for next branch pair
        movement.turnRight()
    end
end

mine()