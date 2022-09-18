local pretty = require("cc.pretty")

-- define constants

local INVENTORY_FILE = ".storage_completion.txt"

-- define setttings

settings.define("storage.chest_name", {
    description = "Network name for the chest for input/output within your storage system",
    default=nil,
    type = "string"
})

-- read settings

local _peripherals = {
    chest_input = {
        name = settings.get("storage.chest_name"),
        object = nil
    },
    chest_output = {
        name = settings.get("storage.chest_name"),
        object = nil
    },
    modem = {
        name = nil,
        object = nil
    }
}

local exact_prefixes = {
    "minecraft:",
    "computercraft:"
}

-- validate settings

if _peripherals.chest_input.name == nil then
    print("No chest name specified in settings. Please run 'set storage.chest_name {NAME}'.")
    error("No chest name specified in settings.")
end

-- get the main chest

_peripherals.chest_input.object = peripheral.wrap(_peripherals.chest_input.name)

if _peripherals.chest_input.object == nil then
    print("No chest found with name '" .. _peripherals.chest_input.name .. "'. Please run 'set storage.chest_name {NAME}'.")
    print("And ensure that the full name is specified.")
    error("No chest found with name " .. _peripherals.chest_input.name)
end

_peripherals.chest_output.object = peripheral.wrap(_peripherals.chest_output.name)

if _peripherals.chest_output.object == nil then
    print("No chest found with name '" .. _peripherals.chest_output.name .. "'. Please run 'set storage.chest_name {NAME}'.")
    print("And ensure that the full name is specified.")
    error("No chest found with name " .. _peripherals.chest_output.name)
end

-- get the modem

_peripherals.modem.object = peripheral.find("modem")

if _peripherals.modem.object == nil then
    error("No modem found")
end

-- get all the chests on the modem

local storage_chests = _peripherals.modem.object.getNamesRemote()

-- ensure that the main chests are on the modem

local main_chest_in_on_modem = false
for i = 1, #storage_chests do
    if storage_chests[i] == _peripherals.chest_input.name then
        table.remove(storage_chests, i)
        main_chest_in_on_modem = true
        break
    end
end

if not main_chest_in_on_modem then
    error("Main input chest is not on the modem")
end


if _peripherals.chest_output.name ~= _peripherals.chest_input.name then
    local main_chest_out_on_modem = false
    for i = 1, #storage_chests do
        if storage_chests[i] == _peripherals.chest_output.name then
            table.remove(storage_chests, i)
            main_chest_out_on_modem = true
            break
        end
    end

    if not main_chest_out_on_modem then
        error("Main output chest is not on the modem")
    end
end

-- loop through all the chests

local function pullItemsFromStorage(search_term, search_requested_count)
    local do_search = true
    local moved_items = 0
    local do_substring_search = false

    if string.sub(search_term, 1, 1) == "!" then
        -- remove the ! from the search term
        search_term = string.sub(search_term, 2)
        do_substring_search = true
    end

    for i = 1, #storage_chests do
        -- get the current chest
        local current_chest = peripheral.wrap(storage_chests[i])
        -- get the items in the chest
        local items = current_chest.list()
        -- loop through all the items
        for current_slot, current_item in pairs(items) do

            local item_matches_search = false

            -- if the search term starts with a ! then we are looking for non - exact match
            if do_substring_search then
                -- if the search term matches then mark it as a match
                if string.find(current_item.name, search_term) then
                    item_matches_search = true
                end
            else
                -- if the search term matches then mark it as a match
                for _, prefix in pairs(exact_prefixes) do
                    if current_item.name == prefix .. search_term then
                        item_matches_search = true
                        break
                    end
                end
            end

            -- check if the item contains the search term
            if item_matches_search then
                -- check how many items we need to move
                if search_requested_count == "all" or search_requested_count == nil then
                    -- if we want to move all items, then we don't need to check how many items we need to move
                    moved_items = moved_items + current_chest.pushItems(_peripherals.chest_output.name, current_slot)
                else
                    -- check how many items we need to move
                    local items_to_move = search_requested_count - moved_items

                    if items_to_move > 0 then
                        -- move the item to the main chest
                        moved_items = moved_items + current_chest.pushItems(_peripherals.chest_output.name, current_slot, items_to_move)
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

local function pushItemsToStorage(slot_to_push, item_count)
    local moved_items = 0

    for i = 1, #storage_chests do
        -- try to push the items from the main chest to the current chest
        local items_pushed = _peripherals.chest_input.object.pushItems(storage_chests[i], slot_to_push)
        
        moved_items = moved_items + items_pushed

        if moved_items >= item_count then
            break
        end
    end

    print("...pushed " .. moved_items .. " items")
    return moved_items
end

local function pushAllToStorage()
    local transferred = 0
    local attempted_transfer = true
    for current_slot, current_item in pairs(_peripherals.chest_input.object.list()) do
        transferred = transferred + pushItemsToStorage(current_slot, current_item.count)
        attempted_transfer = true
    end

    if attempted_transfer then
        print()
        print("Pushed " .. transferred .. " items total")
    else
        print("No items to push")
    end
end


local function getStorageItemCount(search_term)
    local item_count = 0

    local item_table = {}
    local do_substring_search = false

    if string.sub(search_term, 1, 1) == "!" then
        -- remove the ! from the search term
        search_term = string.sub(search_term, 2)
        do_substring_search = true
    end

    for i = 1, #storage_chests do
        -- get the current chest
        local current_chest = peripheral.wrap(storage_chests[i])
        -- get the items in the chest
        local items = current_chest.list()
        -- loop through all the items
        for current_slot, current_item in pairs(items) do
            -- check if the item contains the search term

            local item_matches_search = false

            -- if the search term starts with a ! then we are looking for non - exact match
            if do_substring_search then
                -- if the search term matches then mark it as a match
                if string.find(current_item.name, search_term) then
                    item_matches_search = true
                end
            else
                -- if the search term matches then mark it as a match
                for _, prefix in pairs(exact_prefixes) do
                    if current_item.name == prefix .. search_term then
                        item_matches_search = true
                        break
                    end
                end
            end

            if item_matches_search then
                item_count = item_count + current_item.count
                if item_table[current_item.name] == nil then
                    item_table[current_item.name] = current_item.count
                else
                    item_table[current_item.name] = item_table[current_item.name] + current_item.count
                end
            end
        end
    end

    pretty.print(pretty.pretty(item_table))
    print("Found " .. item_count .. " items matching the search '" .. search_term .. "'")

    return item_count
end

local function getInventory()
    local item_table = {}

    for i = 1, #storage_chests do
        -- get the current chest
        local current_chest = peripheral.wrap(storage_chests[i])
        -- get the items in the chest
        local items = current_chest.list()
        -- local slots = current_chest.size()

        -- loop through all the items
        for _, current_item in pairs(items) do
            -- if the item is not in the table, add it
            if item_table[current_item.name] == nil then
                item_table[current_item.name] = current_item.count
            else
                item_table[current_item.name] = item_table[current_item.name] + current_item.count
            end
        end
    end

    return item_table
end

local function getInventoryFromFile()
    local file = fs.open(INVENTORY_FILE, "r")
    if file == nil then
        return {}
    end
    local inventory = textutils.unserialize(file.readAll())
    file.close()
    return inventory
end

local function saveInventoryToCompletionFile(item_table)
    if item_table == nil then
        item_table = getInventory()
    end

    -- write the pure item table to a file for auto completion
    local file = fs.open(INVENTORY_FILE, "w")
    local clean_table = {}
    for k, v in pairs(item_table) do
        local c = 0
        for match in string.gmatch(k, '([^:]+)') do
            if c == 1 then
                clean_table[match] = v
            end
            c = c + 1
        end
    end
    file.write(textutils.serialize(clean_table))
    file.close()
end


local function fullInventoryCheck()
    -- Dump all items within storage to a file
    local item_table = getInventory()

    -- print the table
    pretty.print(pretty.pretty(item_table))

    -- write the table to a file
    local file = fs.open("inventory.txt", "w")
    file.write(pretty.render(pretty.pretty(item_table), 20))
    file.close()

    saveInventoryToCompletionFile(item_table)

    print("Storage inventory written to inventory.txt")
end

-- public wrappers

local function publicPushAllToStorage()
    pushAllToStorage()
end

local function publicPullFromStorage(search_term, search_requested_count)
    local item_count = getStorageItemCount(search_term)
    if type(search_requested_count) == "string" and search_requested_count == "all" then
        search_requested_count = item_count
    end
    search_requested_count = tonumber(search_requested_count)
    if item_count >= search_requested_count then
        print("Pulling " .. search_requested_count .. " out of " .. item_count .. " '".. search_term .."' from storage")
        pullItemsFromStorage(search_term, search_requested_count)
    else
        print("Error: Not enough items to pull. Have " .. item_count .. " '".. search_term .. "', need " .. search_requested_count)
    end
end

local function publicUsage()
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

-- handle autocompletion
local completion = require "cc.completion"

local function complete(_, index, argument, previous)
    if index == 1 then
        return completion.choice(argument, {"push", "pull", "count", "inventory"}, true)
    elseif index == 2 then
        if previous[#previous] == "pull" then
            local inventory_names = {}
            for key,_ in pairs(getInventoryFromFile()) do
                table.insert(inventory_names, key)
            end
            return completion.choice(argument, inventory_names, false)
        elseif previous[#previous] == "count" then
            local inventory_names = {}
            for key,_ in pairs(getInventoryFromFile()) do
                table.insert(inventory_names, key)
            end

            return completion.choice(argument, inventory_names, false)
        end
        
    elseif index == 3 then
        if previous[#previous - 1] == "pull" then
            return completion.choice(argument, {"all"}, false)
        end
    end
end

shell.setCompletionFunction("storage.lua", complete)


-- handle commandline arguments

local do_inventory_save = true
local search_term = ""
local search_requested_count = ""

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
            search_requested_count = arg[3]
        else
            print("Error: No requested count provided. Must be an integer or 'all'.")
            publicUsage()
            getStorageItemCount(search_term)
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
        do_inventory_save = false
    elseif arg[1] == "inventory" then
        fullInventoryCheck()
        do_inventory_save = false
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

if do_inventory_save == true then
    saveInventoryToCompletionFile()
end
