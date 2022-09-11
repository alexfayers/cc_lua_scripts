-- Turtle script to breed animals

-- imports
local logging = require("afscript.core.logging")
local inventory = require("afscript.turtle.inventory")

local logger = logging.new("breedbot")

-- define config

local breeding_item = "minecraft:wheat"  -- item to use for breeding
local sleep_time = 300  -- 5 minutes
local breedCount = 48  -- number of times to attempt to breed each run

---Breed animals in the pen
local function breedBelow()
    -- use the wheat to breed the animals 20 times
    inventory.select(breeding_item)

    for i = 1, breedCount do
        logger.info("Breeding animals ..." .. i)

        turtle.placeDown()

        sleep(0.5)
    end
end

---Breed animals, sleep, repeat
local function main()
    while true do
        breedBelow()

        logger.info("Sleeping for " .. sleep_time .. " seconds before next breeding")
        sleep(sleep_time)
    end
end

-- run the program

main()
