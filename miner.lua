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


-- for _ in range(self.branch_pair_count):
-- # continue main branch
-- for _ in range(self.branch_spacing + 1):
--     await self.falling_block_check()
--     await self.dig_move(Direction.FORWARD)
--     await self.dig(Direction.UP)

-- # update home location current point on main branch
-- self._home_location = Location(
--     x=self.position.location.x,
--     y=self.position.location.y,
--     z=self.position.location.z,
-- )

-- # mine left branch
-- await self.turn_left()
-- for _ in range(2):
--     for _ in range(self.branch_length):
--         await self.falling_block_check()
--         await self.dig_move(Direction.FORWARD)
--         await self.dig(Direction.UP)

--     # go back to main branch
--     await self.turn_right()
--     await self.turn_right()

--     # dump inventory of trash
--     for bad_block in self._bad_blocks:
--         did_drop: bool = True
--         while did_drop:
--             self._logger.info(f"Dumping {bad_block} blocks.")
--             try:
--                 await self.inventory_dump(bad_block, Direction.UP)
--             except InventoryException:
--                 did_drop = False

--     # start lighting and heading back
--     first_torch = True
--     self.current_light_level = self.torch_light
--     for branch_position in range(self.branch_length):
--         # place torches if necessary
--         target_light: int = 0 if first_torch else -(self.torch_light + 1)

--         if (
--             self.do_place_torches
--             and self.current_light_level <= target_light
--         ):
--             if first_torch:
--                 first_torch = False

--             try:
--                 await self.place_torch()
--             except InventoryException:
--                 # place failed
--                 self.do_place_torches = False
--             except InteractionException:
--                 # place failed because no blocks to place on
--                 pass
--             else:
--                 # place success
--                 self.current_light_level = self.torch_light

--         await self.falling_block_check()
--         await self.dig_move(Direction.FORWARD)
--         self.current_light_level -= (
--             1  # decrease light level because we moved
--         )

--         # at end of branch if there's not enough light, slap a torch down
--         if (
--             branch_position == (self.branch_length - 2)
--             and self.do_place_torches
--             and self.current_light_level <= -1
--         ):
--             try:
--                 await self.place_torch()
--             except InventoryException:
--                 # place failed
--                 self.do_place_torches = False
--             except InteractionException:
--                 # place failed because no blocks to place on
--                 pass
--             else:
--                 # place success
--                 self.current_light_level = self.torch_light

-- # face forward again to prepare for next branch pair
-- await self.turn_right()

-- self._home_location = Location(x=0, y=0, z=0)

-- await self._process_complete()


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
                    local did_place = false
                    if inventory.select("minecraft:torch") > 0 then
                        did_place = turtle.placeUp()
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
