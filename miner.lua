-- Strip mine bot

-- imports

local logging = require("afscript.core.logging")
local movement = require("afscript.turtle.movement")
local inventory = require("afscript.turtle.inventory")
local state = require("afscript.core.state")
local utils = require("afscript.turtle.utils")

movement.logger.level = logging.LEVEL.DEBUG

local logger = logging.new("stripmine")

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



local function mine()
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

    -- fuel check
    local required_fuel = _getFuelRequired(branch_spacing, branch_length, branch_pair_count)
    if prerun_fuel_check then
        local fuel_level = turtle.getFuelLevel()
        if fuel_level < required_fuel then
            logger.error("Not enough fuel to complete trip. Need %d more.", required_fuel - fuel_level)
            return
        end
    end

    -- torch check
    local required_torches = math.ceil(branch_length / torch_light) * branch_pair_count
    local current_torches = inventory.count("minecraft:torch")

    if current_torches < required_torches then
        logger.error("Not enough torches to complete trip. Need %d more.", required_torches - current_torches)
        return
    end

    -- mine

    for _ = 1, branch_pair_count do
        -- continue main branch
        for _ = 1, branch_spacing + 1 do
            turtle.dig()
            movement.forward()

            turtle.digUp()
        end

        -- update home location current point on main branch
        _mine_state.home_location = movement.current_position

        -- mine left branch
        movement.turnLeft()
        for _ = 1, 2 do
            for _ = 1, branch_length do
                turtle.dig()
                movement.forward()
                turtle.digUp()
            end

            -- go back to main branch
            movement.turnAround()

            -- dump inventory of trash
            for bad_block_i = 1, #_bad_blocks do
                local bad_block = _bad_blocks[bad_block_i]
                local did_drop = true
                while did_drop do
                    logger.info("Dumping %s blocks.", bad_block)
                    did_drop = inventory.dump(bad_block) > 0
                end
            end

            -- start lighting and heading back
            local first_torch = true
            current_light_level = torch_light
            for branch_position = 1, branch_length do
                -- place torches if necessary
                local target_light = 0
                if not first_torch then
                    target_light = -(torch_light + 1)
                end

                if do_place_torches and current_light_level <= target_light then
                    if first_torch then
                        first_torch = false
                    end

                    if inventory.select("minecraft:torch") > 0 then
                        turtle.placeUp()
                        current_light_level = torch_light
                    else
                        do_place_torches = false
                    end
                end

                turtle.dig()
                movement.forward()

                current_light_level = current_light_level - 1

                -- at end of branch if there's not enough light, slap a torch down
                if branch_position == branch_length - 1 and do_place_torches and current_light_level <= -1 then
                    if inventory.select("minecraft:torch") > 0 then
                        turtle.placeUp()
                        current_light_level = torch_light
                    else
                        do_place_torches = false
                    end
                end
            end
        end

        -- face forward again to prepare for next branch pair
        movement.turnRight()
    end
end

mine()
