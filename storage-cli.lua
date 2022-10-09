error("Depricated. Use storage.lua instead.")

local storage = require("afscript.storage.storage")

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

-- handle autocompletfion
local completion = require "cc.completion"

local function complete(_, index, argument, previous)
    if index == 1 then
        return completion.choice(argument, {"push", "pull", "count", "inventory"}, true)
    elseif index == 2 then
        if previous[#previous] == "pull" then
            local inventory_names = {}
            for key,_ in pairs(storage.getInventoryFromFile()) do
                table.insert(inventory_names, key)
            end
            return completion.choice(argument, inventory_names, false)
        elseif previous[#previous] == "count" then
            local inventory_names = {}
            for key,_ in pairs(storage.getInventoryFromFile()) do
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

shell.setCompletionFunction("storage-cli.lua", complete)

-- setup s alias for the script
shell.setAlias("sc", "storage-cli.lua")


-- handle commandline arguments

local do_inventory_save = true
local search_term = ""
local search_requested_count = ""

if #arg > 0 then
    if arg[1] == "push" then
        storage.pushAllToStorage()
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
            storage.getStorageItemCount(search_term)
            return
        end

        storage.pullFromStorage(search_term, search_requested_count)
    elseif arg[1] == "count" then
        if #arg > 1 then
            search_term = arg[2]
        else
            print("Error: No search term provided.")
            publicUsage()
            return
        end

        storage.getStorageItemCount(search_term)
        do_inventory_save = false
    elseif arg[1] == "inventory" then
        storage.fullInventoryCheck()
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
    storage.saveInventoryToCompletionFile()
end
