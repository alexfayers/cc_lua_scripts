-- define config

local breeding_item = "minecraft:wheat"  -- item to use for breeding
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


function breedBelow()

    -- use the wheat to breed the animals 20 times
    selectFromInventory(breeding_item)

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