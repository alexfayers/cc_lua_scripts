---An autocrafter for computercraft
---Depends on having a networked storage system set up
---With the output chest next to the crafting table

local logging = require("afscript.core.logging")
local logger = logging.new("autocrafter", logging.LEVEL.DEBUG)

local recipes = require("afscript.craft.recipe")
local remote = require("afscript.core.remote")
local pretty = require("cc.pretty")

local PROTOCOL = "storage"  -- TODO: setting
local PARENT_PC = 4  -- TODO: setting

---Variables

local _initialized = false
local NON_CRAFTING_SLOTS = {4, 8, 12, 13, 14, 15, 16}


---Functions

---Initialise the chat system
---@return boolean _ Whether the initialisation was successful or not
local function _initialize()
    if _initialized then
        logger.error("Already initialised")
        return false
    end

    if not remote.initialize(PROTOCOL) then
        logger.error("Failed to initialise remote")
        return false
    end

    _initialized = true
    logger.success("Initialised")
    return true
end

---Main

---Send a command to the parent computer
---@param command string _ The command to send
---@param data table _ The data to send
---@return boolean _ Whether the command was sent successfully or not
local function send_command(command, data)
    local packet = remote.build_packet(PROTOCOL, command, data)
    remote.send(PROTOCOL, packet, PARENT_PC)
    local res = remote.receive(PROTOCOL, nil, 5)  -- once we receive this update, we know the parent has received the command

    if res then
        return true
    else
        return false
    end
end

---Check if the wrapped chest has a count of a specific item
---@param chest any The wrapped chest to check
---@param ingredient string The item to check for
---@param required_count number The required count of the item
---@return boolean _ Whether the chest has the required count of the item
local function checkIfChestContains(chest, ingredient, required_count)
    local chest_item_count = 0

    local chest_items = chest.list()


    for _, chest_item in pairs(chest_items) do
        local name = chest_item.name
        for match in string.gmatch(name, '([^:]+)') do
            name = match
        end
        if name == ingredient then
            chest_item_count = chest_item_count + chest_item.count
        end
    end

    return chest_item_count >= required_count
end

---Move the selected slot to any of the non-crafting slots
local function moveOutOfTheWay()
    -- bad solution but yolo
    for _, slot in pairs(NON_CRAFTING_SLOTS) do
        if turtle.transferTo(slot) then
            return true
        end
    end

    return false
end

---Craft an item by calculating the required ingredients
---and requesting them from the storage system
---then crafting the item
---@param item string the item to craft
---@param craft_count number number of items to craft
---@return boolean _ Whether the crafting was successful or not
local function craft(item, craft_count)
    local recipe = recipes.get(item)
    if not recipe then
        logger.error("No recipe found for item")
        return false
    end

    local requirements = recipes.requirements(recipe)

    local chest = peripheral.find("inventory")

    for slot=1,16 do
        if turtle.getItemDetail(slot) then
            turtle.select(slot)
            turtle.drop()
        end
    end
    turtle.select(1)

    -- ensure the chest is empty
    send_command("push", {})
    -- sleep(1)

    -- check if the chest has the required items, and request them if not
    for ingredient, required_count in pairs(requirements) do
        required_count = required_count * tonumber(craft_count)

        for match in string.gmatch(ingredient, '([^:]+)') do
            ingredient = match
        end

        logger.info("Checking " .. ingredient)

        local requirement_met = false

        requirement_met = checkIfChestContains(chest, ingredient, required_count)

        if not requirement_met then
            logger.info("Requesting " .. ingredient)
            requirement_met = send_command("pull", {
                search = ingredient,
                count = tonumber(required_count)
            })
        end

        if not requirement_met then
            logger.error("Not enough " .. ingredient .. " in storage")
            return false
        else
            logger.info("Got " .. ingredient)
            turtle.suck()
        end
    end

    logger.info("Got all ingredients")
    send_command("push", {})  -- push any extra items back to the storage system
    logger.info("Clearing crafting grid")

    -- clear the crafting grid
    for slot=1,16 do
        if turtle.getItemDetail(slot) then
            local skip = false
            for _, non_crafing_slot in pairs(NON_CRAFTING_SLOTS) do
                if slot == non_crafing_slot then
                    skip = true
                end
            end
            if not skip then
                turtle.select(slot)
                if not moveOutOfTheWay() then
                    logger.error("Failed to move item out of the way")
                    return false
                end
            end
        end
    end

    -- prepare the crafting grid

    logger.info("Populating crafting grid with recipe")

    local fetched_counts = {}

    for row=1,3 do
        for column=1,3 do
            local recipe_item = recipe[row][column]
            local recipe_slot = (row - 1) * 4 + column

            if recipe_item and recipe_item ~= "" then
                logger.info("Moving " .. recipe_item .. " to slot " .. recipe_slot)

                for _, slot in pairs(NON_CRAFTING_SLOTS) do
                    local item = turtle.getItemDetail(slot)
                    if item then
                        local name = item.name
                        if name == recipe_item then
                            turtle.select(slot)
                            local item_details = turtle.getItemDetail(slot)

                            if not fetched_counts[recipe_item] then
                                fetched_counts[recipe_item] = item_details.count
                            else
                                if fetched_counts[recipe_item] < item_details.count then
                                    fetched_counts[recipe_item] = item_details.count
                                end
                            end

                            local count_to_move = math.floor(fetched_counts[recipe_item] / requirements[recipe_item])

                            if not turtle.transferTo(recipe_slot, count_to_move) then
                                -- something's in the way
                                logger.error("Failed to move item - maybe you asked for too many items at once?")
                                return false
                            end
                            break
                        end
                    end
                end
            end

            -- turtle.select(slot)
            -- turtle.drop()
        end
    end
    turtle.select(1)

    -- clear non-crafting slots
    for _, slot in pairs(NON_CRAFTING_SLOTS) do
        if turtle.getItemDetail(slot) then
            turtle.select(slot)
            turtle.drop()
        end
    end
    send_command("push", {})  -- push any extra items back to the storage system


    logger.info("Crafting")

    if not turtle.craft() then
        logger.error("Failed to craft item")
        return false
    end

    logger.success("Crafted")

    logger.info("Pushing into storage")

    for slot=1,16 do
        if turtle.getItemDetail(slot) then
            turtle.select(slot)
            turtle.drop()
        end
    end
    send_command("push", {})  -- push any extra items back to the storage system

    return true
end

if _initialize() then
    local args = {...}

    if #args < 1 then
        logger.error("No item specified")
        return
    end
    if #args < 2 then
        logger.error("No count specified")
        return
    end
    if #args > 2 then
        logger.error("Too many arguments")
        return
    end

    craft(args[1], args[2])
end
