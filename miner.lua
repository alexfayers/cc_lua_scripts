-- Strip mine bot

local update = require("afscript.meta.update")
update.update_file("teller")  -- update/require the teller script
local teller = require("teller")  -- require the teller script
teller.initialize()

-- imports

local logging = require("afscript.core.logging")
local movement = require("afscript.turtle.movement")
local inventory = require("afscript.turtle.inventory")
local state = require("afscript.core.state")
local utils = require("afscript.turtle.utils")
local notify = require("afscript.core.notify")

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
    "minecraft:cobbled_deepslate",
    "minecraft:gravel",
    "minecraft:tuff",
    "minecraft:andesite",
    "minecraft:diorite",
    "minecraft:granite",
}

-- ores that we want to notifiy about
local _notable_ores = {
    "coal",
    "iron",
    "gold",
    "diamond",
    "emerald",
    "lapis",
    "redstone",
    -- "ancient_debris",
}


local computer_id = os.getComputerID()
-- blocks to leave between each branch
local branch_spacing = 3
-- number of blocks to mine in each branch
local branch_length = 47
-- total number of pairs of branches
local branch_pair_count = 2
-- check if enough fuel before mining
local prerun_fuel_check = true
-- whether to place torches in the stripmine
local do_place_torches = true
-- amount of blocks that torch light travels
local torch_light = 12
-- current light level on the turtle
local current_light_level = 0


-- local function _mineNotify(title, message)
--     notify.join(
--         "CC: Miner #" .. os.getComputerID() .. " " .. title,
--         message
--     )
-- end

local function _privateNotify(_, message)
    teller.tell("Ariakis921", "#" .. computer_id .. " - [" .. os.date("%H:%M:%S") .. "]: " .. message)
end

local _mineNotify = _privateNotify


local function _waypointShare(name, position)
    -- xaero-waypoint:The Tree Of Ponder:T:2138:162:-3221:1:false:0:Internal-overworld-waypoints
    local payload = "xaero-waypoint:"
    payload = payload .. name .. ":" -- name of the waypoint
    payload = payload .. "X:"  -- letter for waypoint in HUD (X marks the spot!)
    payload = payload .. position.x .. ":"  -- x coord
    payload = payload .. position.y .. ":"  -- y coord
    payload = payload .. position.z .. ":"  -- z coord
    payload = payload .. "6:"  -- color of the waypoint
    payload = payload .. "false:"  -- visible
    payload = payload .. "0:"  -- color
    payload = payload .. "Internal-overworld-waypoints"  -- group

    teller.tell("Ariakis921", payload)  -- TODO: make this configurable
end


local function _getFuelRequired(branch_spacing, branch_length, branch_pair_count)
    -- TODO: check this calculation lol
    return (
        (
            branch_spacing + 1
        )  -- spacing between branches, plus 1 for the connection between branches
        + (
            branch_length * 4 * 2 + 1
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

        for _, notable_ore in ipairs(_notable_ores) do
            if string.find(block.name, notable_ore) then
                _mineNotify("Found " .. notable_ore, "Found " .. block.name .. " at " .. movement.current_position.x .. ", " .. movement.current_position.y .. ", " .. movement.current_position.z)
                sleep(0.1)
                _waypointShare(notable_ore, movement.current_position)
            end
            logger.info("Found " .. block.name .. " at " .. movement.current_position.x .. ", " .. movement.current_position.y .. ", " .. movement.current_position.z)
        end

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
        "minecraft:cobbled_deepslate",
        "minecraft:tuff",
        "minecraft:andesite",
        "minecraft:diorite",
        "minecraft:granite",
        
    }
    for _, placeable in ipairs(placeables) do
        if inventory.select(placeable) > 0 then
            return true
        end
    end
    return false
end


---While there is a falling block in front of the turtle, mine it
---and wait a bit for the next one to fall before checking again
local function _mineFallingBlocks()
    local falling_blocks = {
        "minecraft:gravel",
        "minecraft:sand"
    }

    local mined_blocks = 0

    while true do
        local is_block, block = turtle.inspect()
        if is_block then
            local is_falling_block = false
            for _, falling_block in ipairs(falling_blocks) do
                if block.name == falling_block then
                    is_falling_block = true
                    if turtle.dig() then
                        mined_blocks = mined_blocks + 1
                        os.sleep(0.5)
                    end
                end
            end
            if not is_falling_block then
                break
            end
        else
            break
        end
    end

    if mined_blocks > 0 then
        logger.debug("Mined " .. mined_blocks .. " falling blocks at " .. movement.current_position.x .. ", " .. movement.current_position.y .. ", " .. movement.current_position.z)
    end

    return mined_blocks > 0
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

    _mineNotify(
        "Starting mine",
        "Starting mine with branch spacing " .. branch_spacing .. ", branch length " .. branch_length .. ", and branch pair count " .. branch_pair_count
    )

    for _ = 1, branch_pair_count do
        -- continue main branch
        logger.info("Continuing main branch")
        for _ = 1, branch_spacing + 1 do
            turtle.dig()
            _mineFallingBlocks()
            movement.forward()
            turtle.digUp()
        end

        -- update home location current point on main branch
        _mine_state.home_location = movement.current_position
        state.save(_mine_state, STATEFILE)
        logger.debug("Set home location to " .. _mine_state.home_location.x .. ", " .. _mine_state.home_location.y .. ", " .. _mine_state.home_location.z)

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
                _mineFallingBlocks()

                if not _fuelCheckForward() then
                    -- we ran out of fuel and returned to home
                    _mineNotify(
                        "Out of fuel",
                        "Ran out of fuel and returned to " .. _mine_state.home_location.x .. ", " .. _mine_state.home_location.y .. ", " .. _mine_state.home_location.z
                    )
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
    
                    movement.up()
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
    
                    movement.down()
                    if _mineAdjacent() then  -- mine any ore blocks on the top layer
                        branch_has_ore = true
                    end
                end
            end

            -- if the branch length is odd, we need to move down back to the floor
            if branch_length % 2 == 1 then
                if _mineIfOre(turtle.inspectDown, turtle.digDown, true) then
                    branch_has_ore = true
                else
                    turtle.digDown()
                end
                movement.down()
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
                _mineFallingBlocks()
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

                -- _mineNotify(
                --     "Found ore",
                --     "Found ore in the branch at " .. movement.current_position.x .. ", " .. movement.current_position.y .. ", " .. movement.current_position.z
                -- )
            else
                logger.info("No ore found in this branch")

                if _selectPlaceable() then  -- we mined a placeable block, so place it
                    movement.turnAround()
                    turtle.place()
                    movement.turnAround()
                end
            end

            if branch_side == 1 then logger.info("Completed left branch") else logger.info("Completed right branch") end

            inventory.compact()  -- compact inventory before moving on to the next branch
        end

        logger.info("Completed branch pair")
        -- face forward again to prepare for next branch pair
        movement.turnRight()
    end

    logger.info("Completed mining")

    _mineNotify(
        "Completed mining",
        "Completed mining at " .. movement.current_position.x .. ", " .. movement.current_position.y .. ", " .. movement.current_position.z
    )
end

mine()
