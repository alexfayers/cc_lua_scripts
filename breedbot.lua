-- define config

local wheat_slot = 1  -- slot of wheat in the turtle's inventory
local sleep_time = 300  -- 5 minutes
local breedCount = 48  -- number of times to attempt to breed each run

function log(msg)
    msg = os.date("%c") .. " " .. msg
    print(msg)
    local file = fs.open("breedbot.log", "a")
    file.writeLine(msg)
    file.close()
end

-- define functions

function breedBelow()

    -- use the wheat to breed the animals 20 times
    turtle.select(wheat_slot)

    for i = 1, breedCount do
        log("Breeding animals ..." .. i)

        turtle.placeDown()

        sleep(0.5)
    end
end

function main()
    
    while true do
        breedBelow()

        log("Sleeping for " .. sleep_time .. " seconds before next breeding")
        sleep(sleep_time)
    end
end

-- run the program

main()