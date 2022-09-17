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
    _ore_locations = {},
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
local branch_length = 20 -- 47
-- total number of pairs of branches
local branch_pair_count = 1
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


---Mine ore and store it's location
---@param inspect_action function function to call to inspect the block
---@param mine_action function function to call to mine the block
---@param do_mine boolean whether to mine the block
---@return boolean
local function _mineIfOre(inspect_action, mine_action, do_mine)
    local is_block, block = inspect_action()
    if is_block and string.find(block.name, "ore") then
        table.insert(_mine_state._ore_locations, {
            x = movement.current_position.x,
            y = movement.current_position.y,
            z = movement.current_position.z,
            name = block.name
        })
        state.save(_mine_state, STATEFILE)

        if do_mine then
            if mine_action() then
                logger.debug("Mined " .. block.name .. " at " .. movement.current_position.x .. ", " .. movement.current_position.y .. ", " .. movement.current_position.z)
                return true
            else
                logger.debug("Could not mine " .. block.name .. " at " .. movement.current_position.x .. ", " .. movement.current_position.y .. ", " .. movement.current_position.z)
            end
        else
            logger.debug("Found " .. block.name .. " at " .. movement.current_position.x .. ", " .. movement.current_position.y .. ", " .. movement.current_position.z)
            return true
        end
    end
    return false
end



---Check if any of the adjacent blocks are ore blocks.
---If they are, mine them and add the location to the list of locations to mine
local function _mineAdjacent()
    local did_mine = false
    for i = 1, 4 do
        if _mineIfOre(turtle.inspect, turtle.dig, true) then
            did_mine = true
        end
        movement.turnRight()
    end

    -- check above for ore
    if _mineIfOre(turtle.inspectUp, turtle.digUp, true) then
        did_mine = true
    end

    -- check below for ore
    if _mineIfOre(turtle.inspectDown, turtle.digDown, false) then
        did_mine = true
    end

    return did_mine
end


---Select the first placeable block in the inventory
---@return boolean
local function _selectPlaceable()
    local placeables = {
        "minecraft:dirt",
        "minecraft:cobblestone",
        "minecraft:cobbled_deepslate"
    }
    for _, placeable in ipairs(placeables) do
        if inventory.select(placeable) > 0 then
            return true
        end
    end
    return false
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
        state.save(_mine_state, STATEFILE)

        -- mine left branch
        movement.turnLeft()
        for branch_side = 1, 2 do
            local branch_has_ore = false
            if branch_side == 1 then logger.info("Mining left branch") else logger.info("Mining right branch") end

            for branch_length_position = 1, branch_length do
                -- mine in front
                if _mineIfOre(turtle.inspect, turtle.dig, true) then
                    branch_has_ore = true
                else
                    turtle.dig()
                end

                if not _fuelCheckForward() then
                    -- we ran out of fuel and returned to home
                    return
                end
                if _mineAdjacent() then  -- mine any ore blocks on the bottom layer
                    branch_has_ore = true
                end

                if branch_length_position % 2 == 1 then
                    -- mine the layer above if we're at an odd number
                    if _mineIfOre(turtle.inspectUp, turtle.digUp, true) then
                        branch_has_ore = true
                    else
                        turtle.digUp()
                    end
    
                    turtle.up()
                    if _mineAdjacent() then  -- mine any ore blocks on the top layer
                        branch_has_ore = true
                    end
                else
                    -- mine the layer below if we're at an even number
                    if _mineIfOre(turtle.inspectDown, turtle.digDown, true) then
                        branch_has_ore = true
                    else
                        turtle.digDown()
                    end
    
                    turtle.down()
                    if _mineAdjacent() then  -- mine any ore blocks on the top layer
                        branch_has_ore = true
                    end
                end
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
                if branch_position == branch_length - 1 then
                    if not branch_has_ore then
                        -- mine a block ready to block off the end of the branch because there's no ore
                        turtle.digDown()
                    end
                    if do_place_torches and current_light_level <= target_light then
                        _placeTorchIfNeeded()
                    end
                end
            end

            if branch_has_ore then
                logger.info("Found ore in the branch at " .. movement.current_position.x .. ", " .. movement.current_position.y .. ", " .. movement.current_position.z)
            else
                logger.info("No ore found in this branch")

                if _selectPlaceable() then  -- we mined a placeable block, so place it
                    turtle.turnAround()
                    turtle.place()
                    turtle.turnAround()
                end
            end

            if branch_side == 1 then logger.info("Completed left branch") else logger.info("Completed right branch") end
        end

        logger.info("Completed branch pair")
        -- face forward again to prepare for next branch pair
        movement.turnRight()
    end
end

mine()
