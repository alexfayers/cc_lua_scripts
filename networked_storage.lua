local pretty = require("cc.pretty")


local main_chest_in_name = "minecraft:chest_0"
local main_chest_out_name = "minecraft:chest_1"

-- get the main chest

local main_chest_in = peripheral.wrap(main_chest_in_name)
local main_chest_out = peripheral.wrap(main_chest_out_name)

-- get the modem

local modem = peripheral.find("modem")

-- get all the chests on the modem

local chests = modem.getNamesRemote()

-- ensure that the main chests are on the modem

local main_chest_in_on_modem = false
for i = 1, #chests do
    if chests[i] == main_chest_in_name then
        table.remove(chests, i)
        main_chest_in_on_modem = true
        break
    end
end

if not main_chest_in_on_modem then
    error("Main input chest is not on the modem")
end

local main_chest_out_on_modem = false
for i = 1, #chests do
    if chests[i] == main_chest_out_name then
        table.remove(chests, i)
        main_chest_out_on_modem = true
        break
    end
end

if not main_chest_out_on_modem then
    error("Main output chest is not on the modem")
end

-- loop through all the chests

function pullItemsFromStorage(search_term, search_requested_count)
    local do_search = true
    local moved_items = 0

    for i = 1, #chests do
        -- get the current chest
        local current_chest = peripheral.wrap(chests[i])
        -- get the items in the chest
        local items = current_chest.list()
        -- loop through all the items
        for current_slot, current_item in pairs(items) do
            -- check if the item contains the search term
            if string.find(current_item.name, search_term) then
                -- check how many items we need to move
                if search_requested_count == "all" then
                    -- if we want to move all items, then we don't need to check how many items we need to move
                    moved_items = moved_items + current_chest.pushItems(main_chest_out_name, current_slot)
                else
                    -- check how many items we need to move
                    local items_to_move = search_requested_count - moved_items

                    if items_to_move > 0 then
                        -- move the item to the main chest
                        moved_items = moved_items + current_chest.pushItems(main_chest_out_name, current_slot, items_to_move)
                    else
                        do_search = false
                        break
                    end
                end
            end
        end

        if not do_search then
            break
        end
    end

    print("Pulled " .. moved_items .. " '".. search_term .."'")
    return moved_items
end

function pushItemsToStorage(slot_to_push)
    local moved_items = 0

    for i = 1, #chests do
        -- try to push the items from the main chest to the current chest
        local items_pushed = main_chest_in.pushItems(chests[i], slot_to_push)
        
        moved_items = moved_items + items_pushed
    end

    print("Pushed " .. moved_items .. " items")
    return moved_items
end

function pushAllToStorage()
    local transferred = 0
    local attempted_transfer = true
    for current_slot, current_item in pairs(main_chest_in.list()) do
        transferred = transferred + pushItemsToStorage(current_slot, current_item.count)
        attempted_transfer = true
    end

    if attempted_transfer then
        print("Pushed " .. transferred .. " items total")
    else
        print("No items to push")
    end
end


function getStorageItemCount(search_term)
    local item_count = 0

    for i = 1, #chests do
        -- get the current chest
        local current_chest = peripheral.wrap(chests[i])
        -- get the items in the chest
        local items = current_chest.list()
        -- loop through all the items
        for current_slot, current_item in pairs(items) do
            -- check if the item contains the search term
            if string.find(current_item.name, search_term) then
                item_count = item_count + current_item.count
            end
        end
    end

    print("Found " .. item_count .. " items matching the search '" .. search_term .. "'")

    return item_count
end

function fullInventoryCheck()
    -- Dump all items within storage to a file
    item_table = {}

    for i = 1, #chests do
        -- get the current chest
        local current_chest = peripheral.wrap(chests[i])
        -- get the items in the chest
        local items = current_chest.list()
        local slots = current_chest.size()

        -- loop through all the items
        for current_slot, current_item in pairs(items) do
            -- if the item is not in the table, add it
            if item_table[current_item.name] == nil then
                item_table[current_item.name] = current_item.count
            else
                item_table[current_item.name] = item_table[current_item.name] + current_item.count
            end
        end
    end

    -- print the table
    pretty.print(pretty.pretty(item_table))

    -- write the table to a file
    local file = fs.open("storage_inventory.txt", "w")
    file.write(pretty.render(pretty.pretty(item_table), 20))
    file.close()

    print("Storage inventory written to storage_inventory.txt")
end

-- public wrappers

function publicPushAllToStorage()
    pushAllToStorage()
end

function publicPullFromStorage(search_term, search_requested_count)
    local item_count = getStorageItemCount(search_term)
    if item_count >= search_requested_count then
        print("Pulling " .. search_requested_count .. " out of " .. item_count .. " '".. search_term .."' from storage")
        pullItemsFromStorage(search_term, search_requested_count)
    else
        print("Error: Not enough items to pull. Have " .. item_count .. " '".. search_term .. "', need " .. search_requested_count)
    end
end

function publicUsage()
    local script_name = arg[0]
    print()
    print("Usage:")
    print("Pull items from storage:")
    print("    " .. script_name .. " pull [search_term] [search_requested_count]")
    print("Push all items to storage:")
    print("    " .. script_name .. " push")
    print("Check the current amount of an item in storage:")
    print("    " .. script_name .. " count [search_term]")
    print("Check the current inventory of storage:")
    print("    " .. script_name .. " inventory")
end

-- handle commandline arguments

if #arg > 0 then
    if arg[1] == "push" then
        pushAllToStorage()
    elseif arg[1] == "pull" then
        if #arg > 1 then
            search_term = arg[2]
        else
            print("Error: No search term provided.")
            publicUsage()
            return
        end

        if #arg > 2 then
            search_requested_count = tonumber(arg[3])
        else
            print("Error: No requested count provided. Must be an integer or 'all'.")
            publicUsage()
            return
        end

        publicPullFromStorage(search_term, search_requested_count)
    elseif arg[1] == "count" then
        if #arg > 1 then
            search_term = arg[2]
        else
            print("Error: No search term provided.")
            publicUsage()
            return
        end

        getStorageItemCount(search_term)
    elseif arg[1] == "inventory" then
        fullInventoryCheck()
    else
        print("Error: Unknown command '" .. arg[1] .. "'.")
        publicUsage()
        return
    end
else
    print("Error: No command provided.")
    publicUsage()
    return
end
