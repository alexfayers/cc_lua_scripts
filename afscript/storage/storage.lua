local pretty = require("cc.pretty")
local logging = require("afscript.core.logging")

local logger = logging.new("afscript.storage", logging.LEVEL.ERROR)

-- define constants

-- local INVENTORY_FILE = ".storage_completion.txt"
local NO_PUSH_FILE = ".storage_no_push.txt"

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

-- validate settings

if _peripherals.chest_input.name == nil then
    logger.error("No chest name specified in settings. Please run 'set storage.chest_name {NAME}'.")
    error("No chest name specified in settings.")
end

-- get the main chest

_peripherals.chest_input.object = peripheral.wrap(_peripherals.chest_input.name)

if _peripherals.chest_input.object == nil then
    logger.error("No chest found with name '" .. _peripherals.chest_input.name .. "'. Please run 'set storage.chest_name {NAME}'.")
    logger.error("And ensure that the full name is specified.")
    error("No chest found with name " .. _peripherals.chest_input.name)
end

_peripherals.chest_output.object = peripheral.wrap(_peripherals.chest_output.name)

if _peripherals.chest_output.object == nil then
    logger.error("No chest found with name '" .. _peripherals.chest_output.name .. "'. Please run 'set storage.chest_name {NAME}'.")
    logger.error("And ensure that the full name is specified.")
    error("No chest found with name " .. _peripherals.chest_output.name)
end

-- get the modem

_peripherals.modem.object = peripheral.find("modem")

if _peripherals.modem.object == nil then
    error("No modem found")
end

-- read the non-push list

local no_push_list = { }

local no_push_file = fs.open(NO_PUSH_FILE, "r")

if no_push_file then
    for line in io.lines(NO_PUSH_FILE) do
        table.insert(no_push_list, line)
    end
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

-- VERSION 2

---Get a count of all non-nil items in a table.
---@param t table
---@return number
local function countItems(t)
    local count = 0
    for _, v in pairs(t) do
        if v ~= nil then
            count = count + 1
        end
    end
    return count
end

---Apply a function to all items in a table, and return a new table with the results.
---The parallel api is used to speed up the process.
---@param t table
---@param f function
---@return table
local function tableMap(t, f)
    local threads = {}
    local results = {}
    for k, v in pairs(t) do
        table.insert(threads, function()
            results[k] = f(v)
        end)
    end
    parallel.waitForAll(table.unpack(threads))
    return results
end


---Apply a function to all items in a table, and if the function returns true, add the item to a new table.
---The parallel api is used to speed up the process.
---@param t table
---@param f function
---@return table
local function tableFilter(t, f)
    local threads = {}
    local results = {}
    for k, v in pairs(t) do
        table.insert(threads, function()
            if f(v) then
                results[k] = v
            end
        end)
    end
    parallel.waitForAll(table.unpack(threads))
    return results
end


---Create a map of all items in the storage system.
---This consists of a table containing each chest as a key, and a table as the value.
---The chest table contains the wrapped chest object (object), the chest name (name), and a table of all items in the chest (items).
---The items table contains the slot number as the key, and the following information as the value:
---    name: The name of the item
---    count: The number of items in the slot
---    slot: The slot number that the item is in
---The parallel api is used to speed up the process.
---@return table _ The map of all items in the storage system
local function createStorageMap()
    local storage_map = {}

    local function parallelMap(chest_name)
        if chest_name == _peripherals.chest_input.name then
            return
        end

        if chest_name == _peripherals.chest_output.name then
            return
        end
    

        -- get the current chest
        local current_chest = peripheral.wrap(chest_name)
        -- get the items in the chest
        local items = current_chest.list()
        local size = current_chest.size()

        -- create the chest table
        local chest_table = {}
        chest_table.object = current_chest
        chest_table.name = chest_name
        chest_table.size = size
        chest_table.items = {}

        -- loop through all the items

        local slots = {}

        for slot, _ in pairs(items) do
            table.insert(slots, slot)
        end

        tableMap(slots, function(slot)
            -- create the item table
            local item_table = {}
            item_table.slot = slot

            local details = current_chest.getItemDetail(slot)
            item_table.name = details.name
            item_table.count = details.count
            item_table.displayName = details.displayName
            item_table.damage = details.damage or -1 -- default to -1 if no damage value
            item_table.maxDamage = details.maxDamage or -1 -- default to -1 if no maxDamage value
            item_table.nbt = details.nbt or "" -- default to empty string if no nbt value

            -- tags is a table with keys that are the tag names, and values that always seem to be true
            item_table.tags = details.tags or {} -- default to empty table if no tags value

            -- add the item table to the chest table
            chest_table.items[slot] = item_table
        end)

        -- add the chest table to the storage map
        storage_map[chest_name] = chest_table
    end

    local threads = {}

    for _, chest in pairs(storage_chests) do
        table.insert(threads, function ()
            parallelMap(chest)
        end)
    end

    parallel.waitForAll(table.unpack(threads))

    return storage_map
end


---Tests the createStorageMap function
---Ensures that the storage map is created correctly, with at least one chest (containing an object and items key), and at least one item in the chests items
---Also ensures that each item has all required attributes
local function testCreateStorageMap()
    print("Starting testCreateStorageMap")
    local storage_map = createStorageMap()
    local required_item_attributes = {"name", "count", "slot", "displayName", "damage", "maxDamage", "nbt", "tags"}

    -- ensure that the storage map has at least one chest
    assert(countItems(storage_map) > 0, "Storage map does not contain any chests")

    -- ensure that each chest has an object and items key
    for _, chest in pairs(storage_map) do
        assert(chest.object ~= nil, "Chest does not contain an object")
        assert(chest.items ~= nil, "Chest does not contain any items")
        assert(chest.name ~= nil, "Chest does not contain a name")
    end

    -- ensure that there is at least one item in the storage map
    local item_count = 0
    for _, chest in pairs(storage_map) do
        item_count = item_count + countItems(chest.items)
    end
    assert(item_count > 0, "Storage map does not contain any items")

    -- ensure that each item has all required attributes
    for _, chest in pairs(storage_map) do
        for _, item in pairs(chest.items) do
            for _, attribute in pairs(required_item_attributes) do
                assert(item[attribute] ~= nil, "Item does not contain the required attribute '" .. attribute .. "'")
            end
        end
    end
end


---Apply a filter to a storage map
---This will remove any items from the map that do not match the filter
---The filter is a function which is called with each item in the system as it's first parameter. If the function returns true, the item will be kept, otherwise it will be removed.
---The parallel api is used to speed up the process.
---@param storage_map table _ The storage map to apply the filter to
---@param filter any _ The filter to apply
---@return table _ The filtered storage map
local function filterStorageMap(storage_map, filter)
    local filtered_storage_map = tableMap(storage_map, function (chest)
        -- filter the items using the filter and return true if there are any items left
        chest.items = tableFilter(chest.items, filter)

        return chest
    end)

    filtered_storage_map = tableFilter(filtered_storage_map, function (chest)
        return countItems(chest.items) > 0
    end)

    return filtered_storage_map
end


---Tests the filterStorageMap function
---Ensures that the storage map is filtered correctly, with at least one chest, and at least one item in that chest
local function testFilterStorageMap(storage_map)
    print("Starting testFilterStorageMap")
    local filtered_storage_map = filterStorageMap(storage_map, function (item)
        return item.name == "minecraft:stone"
    end)

    -- ensure that the storage map has at least one chest
    assert(countItems(filtered_storage_map) > 0, "Filtered storage map does not contain any chests. Make sure that the filter is not removing all items, and that at least one stone is actually in the storage system.")

    -- ensure that there is at least one item in the storage map
    local item_count = 0
    for _, chest in pairs(filtered_storage_map) do
        item_count = item_count + countItems(chest)
    end
    assert(item_count > 0, "Filtered storage map does not contain any items")

    -- ensure that each item is a stone
    for _, chest in pairs(filtered_storage_map) do
        for _, item in pairs(chest.items) do
            assert(item.name == "minecraft:stone", "Filtered storage map contains an item that is not a stone")
        end
    end

    -- ensure that the filtered storage map is not the same as the original storage map
    assert(filtered_storage_map ~= storage_map, "Filtered storage map is the same as the original storage map")
end


---Get the total number of items in a storage map.
---The map function is used to speed up the process by running the countItems function in parallel.
---@param storage_map table _ The storage map to get the total number of items from
---@return number _ The total number of items in the storage map
local function getTotalItems(storage_map)
    local total_items = 0

    tableMap(storage_map, function (chest)
        -- add the number of items in the chest to the total
        total_items = total_items + countItems(chest.items)
    end)

    return total_items
end


---Tests the getTotalItems function
---Ensures that the total number of items is at least 1
local function testGetTotalItems(storage_map)
    print("Starting testGetTotalItems")
    local total_items = getTotalItems(storage_map)

    -- ensure that the total items is greater than 0
    assert(total_items > 0, "Total items is not greater than 0")
end


---Get the total number of items in a storage map that match a filter.
---The map function is used to speed up the process by running the countItems function in parallel.
---@param storage_map table _ The storage map to get the total number of items from
---@param filter any _ The filter to apply
---@return number _ The total number of items in the storage map that match the filter
local function getTotalFilteredItems(storage_map, filter)
    local total_items = 0

    tableMap(storage_map, function (chest)
        -- filter the items using the filter and add the number of items in the chest to the total
        total_items = total_items + countItems(tableFilter(chest.items, filter))
    end)

    return total_items
end


---Tests the getTotalFilteredItems function
---Ensures that the total number of items is at least 1
local function testGetTotalFilteredItems(storage_map)
    print("Starting testGetTotalFilteredItems")
    local total_items = getTotalFilteredItems(storage_map, function (item)
        return item.name == "minecraft:stone"
    end)

    -- ensure that the total items is greater than 0
    assert(total_items > 0, "Total items is not greater than 0")
end


---Pull all items from a storage map that match a filter into a given inventory until a target count is reached.
---First the storage map is filtered, then all items are pulled from the filtered storage map into the inventory.
---@param storage_map table _ The storage map to pull items from
---@param filter any _ The filter to apply
---@param inventory string _ The name of the inventory to pull items into
---@param target_count number _ The target number of items to pull
---@return number _ The number of items pulled
local function pullFilteredItems(storage_map, filter, inventory, target_count)
    -- filter the storage map
    local filtered_storage_map = filterStorageMap(storage_map, filter)

    -- synchronously create a table of all items in the filtered storage map
    -- updating the count of items to be limited to the target count
    local to_pull_map = filtered_storage_map
    local will_pull_count = 0

    if type(target_count) == "number" then
        for _, chest in pairs(to_pull_map) do
            for _, item in pairs(chest.items) do
                -- update the count of items to be pulled
                will_pull_count = will_pull_count + item.count
                if will_pull_count > target_count then
                    item.count = item.count - (will_pull_count - target_count)
                    will_pull_count = target_count
                end
            end
        end
    elseif type(target_count) == "string" and target_count == "all" then
        -- do nothing
    else
        error("Invalid target count: " .. tostring(target_count))
    end
    
    -- pull all of the items from the to_pull_map, parallelising the process
    local pulled_items = 0

    -- pull all items from the filtered storage map into the inventory
    tableMap(to_pull_map, function (chest)
        tableMap(chest.items, function (item)
            -- these need to be on separate lines to prevent weird behaviour. Think it's a bug in the compiler.
            local res = chest.object.pushItems(inventory, item.slot, item.count)
            pulled_items = pulled_items + res
        end)
    end)

    return pulled_items
end


---Tests the pullFilteredItems function
---Ensures that the correct number of items are pulled
local function testPullFilteredItems(storage_map)
    print("Starting testPullFilteredItems")
    local TO_PULL = 127

    local pulled_items = pullFilteredItems(storage_map, function (item)
        return item.name == "minecraft:stone"
    end, _peripherals.chest_output.name, TO_PULL)

    -- ensure that the correct number of items are pulled
    assert(pulled_items == TO_PULL, "Incorrect number of items pulled (" .. pulled_items .. " instead of " .. TO_PULL ..")")
end


---Push all items from a given inventory into any free slots in chests in a storage map.
---The map function is used to speed up the process by running in parallel.
---@param storage_map table _ The storage map to push items into
---@param inventory string _ The name of the inventory to push items from
---@return number _ The number of items pushed
local function pushItems(storage_map, inventory)
    -- synchronously create a table of all items in the inventory
    local to_push_map = {}
    local wrapped_input = peripheral.wrap(inventory)
    for slot, item in pairs(wrapped_input.list()) do
        table.insert(to_push_map, {
            slot = slot,
            name = item.name,
            count = item.count
        })
    end

    -- push all of the items from the to_push_map, parallelising the process
    local pushed_items = 0

    tableMap(storage_map, function (chest)
        tableMap(to_push_map, function (item)
            -- these need to be on separate lines to prevent weird behaviour. Think it's a bug in the compiler.
            local res = wrapped_input.pushItems(chest.name, item.slot, item.count)
            pushed_items = pushed_items + res
        end)
    end)

    return pushed_items
end


---Tests the pushItems function
---Ensures that the correct number of items are pushed
local function testPushItems(storage_map)
    print("Starting testPushItems")
    local EXPECTED_PUSH = 127

    local pushed_items = pushItems(storage_map, _peripherals.chest_input.name)

    -- ensure that the correct number of items are pushed
    assert(pushed_items >= EXPECTED_PUSH, "Incorrect number of items pushed (" .. pushed_items .. " instead of " .. EXPECTED_PUSH ..")")
end


--- public functions


---Push all items from the input chest into the storage system.
---@param storage_map table _ The storage map to push items into
local function _pushAllToStorage(storage_map)
    pushItems(storage_map, _peripherals.chest_input.name)

    local new_map = createStorageMap()

    return new_map
end

---Test the storage pushing
local function test_pushAllToStorage(_)
    print("Starting test_pushAllToStorage")
    -- no test needed - it's covered by testPushItems
    assert(true)
end

---Pull all items matching a search term into the output chest.
---If the search starts with a ! then the search is an exact match.
---Otherwise, the search is a partial match.
---@param search_term string _ The search term
---@param requested_count number _ The number of items to pull
---@return table _ The new storage map
---@return number _ The number of items pulled
local function _pullSearchFromStorage(storage_map, search_term, requested_count)
    local first_character = string.sub(search_term, 1, 1)

    -- create the filter function
    local filter = function (item)
        if first_character == "!" then
            -- exact match
            return item.name == string.sub(search_term, 2)
        elseif first_character == "#" then
            -- tag match
            return item.tags[string.sub(search_term, 2)] ~= nil
        else
            -- This is an exact match, ignoring the namespace
            return string.find(item.name, "^.+:" .. search_term .. "$") ~= nil

            -- partial match
            -- return string.find(item.name, search_term) ~= nil
        end
    end

    -- pull the items
    local pulled_count = pullFilteredItems(storage_map, filter, _peripherals.chest_output.name, requested_count)

    local new_map = createStorageMap()

    return new_map, pulled_count
end


---Test the storage pulling
local function test_pullSearchFromStorage(storage_map)
    print("Starting test_pullSearchFromStorage")

    local pulled_count = 0
    
    -- test exact match
    print("Testing exact match")
    storage_map, pulled_count = _pullSearchFromStorage(storage_map, "!minecraft:stone", 127)
    assert(pulled_count == 127, "Incorrect number of items pulled (" .. pulled_count .. " instead of 127)")
    -- put the items back
    storage_map = _pushAllToStorage(storage_map)

    -- test partial match
    print("Testing partial match")
    storage_map, pulled_count = _pullSearchFromStorage(storage_map, "stone", 127)
    assert(pulled_count == 127, "Incorrect number of items pulled (" .. pulled_count .. " instead of 127)")
    -- put the items back
    storage_map = _pushAllToStorage(storage_map)

    -- test tag match
    print("Testing tag match")
    storage_map, pulled_count = _pullSearchFromStorage(storage_map, "#minecraft:sand", 127)
    assert(pulled_count == 127, "Incorrect number of items pulled (" .. pulled_count .. " instead of 127)")
    -- put the items back
    storage_map = _pushAllToStorage(storage_map)
end

---Get the storage map without the namespaces of items.
---Also flattens the maps to only contain the items, and no chest relations.
---@return table
local function getCleanStorageMap(storage_map)
    local clean_items = {}

    tableMap(storage_map, function (chest)
        tableMap(chest.items, function (item)
            local clean_name = string.gsub(item.name, "^.+:", "")
            local clean_item = item
            clean_item.name = clean_name

            if clean_items[clean_name] == nil then
                clean_items[clean_name] = clean_item
            else
                clean_items[clean_name].count = clean_items[clean_name].count + clean_item.count
            end

            return item
        end)
        return chest
    end)

    return clean_items
end


---Tests the getCleanStorageMap function
---Ensures that the same number of items are returned, but with the namespace removed
local function testGetCleanStorageMap(storage_map)
    print("Starting testGetCleanStorageMap")
    local clean_storage_map = getCleanStorageMap(storage_map)
    storage_map = createStorageMap()

    local total_items = 0
    local total_clean_items = 0

    tableMap(storage_map, function (chest)
        tableMap(chest.items, function (item)
            total_items = total_items + item.count
        end)
    end)

    tableMap(clean_storage_map, function (item)
        total_clean_items = total_clean_items + item.count
    end)

    assert(total_items == total_clean_items, "Incorrect number of items returned (" .. total_clean_items .. " instead of " .. total_items ..")")
end


---Calculate the percentage of the storage system that is full.
---@param storage_map any
local function calculateFullness(storage_map)
    local total_items = 0
    local total_slots = 0

    tableMap(storage_map, function (chest)
        tableMap(chest.items, function (item)
            total_items = total_items + 1
        end)
        total_slots = total_slots + chest.size
    end)

    return math.floor((total_items / (total_slots)) * 100)
end


local function runTests()
    testCreateStorageMap()

    local tests = {
        testFilterStorageMap,
        testGetTotalItems,
        testGetTotalFilteredItems,
        testPullFilteredItems,
        testPushItems,
        test_pushAllToStorage,
        test_pullSearchFromStorage,
        testGetCleanStorageMap
    }

    for _, test in pairs(tests) do
        local storage_map = createStorageMap()
        test(storage_map)
    end
end

-- TODO: link the gui with the new functions

-- END VERSION 2

return {
    pushAllToStorage = _pushAllToStorage,
    pullFromStorage = _pullSearchFromStorage,
    runTests = runTests,
    createStorageMap = createStorageMap,
    getCleanStorageMap = getCleanStorageMap,
    calculateFullness = calculateFullness,
}
