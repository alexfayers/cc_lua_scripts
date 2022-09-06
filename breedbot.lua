-- define config

local wheat_slot = 1
local sleep_time = 300

-- define functions

function breedBelow()

    -- use the wheat to breed the animals 20 times
    turtle.select(wheat_slot)

    for i = 1, 20 do
        print("Breeding animals ..." .. i)

        turtle.placeDown()

        sleep(0.5)
    end
end

function main()
    
    while true do
        breedBelow()

        print("Sleeping for " .. sleep_time .. " seconds before next breeding")
        sleep(sleep_time)
    end
end

-- run the program

main()