--- Automatic furnace array control

local logging = require("afscript.core.logging")
local logger = logging.new("furnace")

local pretty = require("cc.pretty")

-- config

settings.define("furnace.fuel_input", {
    description = "The name of the fuel input chest",
    default = nil,
    type = "string"
})

settings.define("furnace.main_input", {
    description = "The name of the main input chest",
    default = nil,
    type = "string"
})

settings.define("furnace.main_output", {
    description = "The name of the main output chest",
    default = nil,
    type = "string"
})

local FUEL_INPUT_NAME = settings.get("furnace.fuel_input")
if not FUEL_INPUT_NAME then
    logger.error("No fuel input specified in settings. Please run 'set furnace.fuel_input {NAME}'.")
    error("No fuel input specified in settings.")
end
local FUEL_INPUT = peripheral.wrap(FUEL_INPUT_NAME)
if not FUEL_INPUT then
    logger.error("Fuel input (" .. FUEL_INPUT_NAME .. ") not connected to network.")
    error("Fuel input not found.")
end

local MAIN_INPUT_NAME = settings.get("furnace.main_input")
if not MAIN_INPUT_NAME then
    logger.error("No main input specified in settings. Please run 'set furnace.main_input {NAME}'.")
    error("No main input specified in settings.")
end
local MAIN_INPUT = peripheral.wrap(MAIN_INPUT_NAME)
if not MAIN_INPUT then
    logger.error("Main input (" .. MAIN_INPUT_NAME .. ") not connected to network.")
    error("Main input not found.")
end

local MAIN_OUTPUT_NAME = settings.get("furnace.main_output")
if not MAIN_OUTPUT_NAME then
    logger.error("No main output specified in settings. Please run 'set furnace.main_output {NAME}'.")
    error("No main output specified in settings.")
end
local MAIN_OUTPUT = peripheral.wrap(MAIN_OUTPUT_NAME)
if not MAIN_OUTPUT then
    logger.error("Main output (" .. MAIN_OUTPUT_NAME .. ") not connected to network.")
    error("Main output not found.")
end

local MODEM = peripheral.find("modem")

if not MODEM then
    logger.error("No modem connected to computer.")
    error("No modem connected to computer.")
end

-- constants

local ITEM_INPUT_SLOT = 1
local FUEL_INPUT_SLOT = 2
local ITEM_OUTPUT_SLOT = 3

-- variables

local did_fuel_warning = false

-- functions

---Get a list of all furnaces in the network
local function getFurnaceList()
    local furnaces = { }
    for _, name in pairs(MODEM.getNamesRemote()) do
        if string.find(name, "furnace") then
            local furnace = peripheral.wrap(name)
            table.insert(furnaces, furnace)
        end
    end
    return furnaces
end

local function calculateItemsPerFurnace(itemAmount, furnaceAmount)
    return math.max(1, math.floor(itemAmount / furnaceAmount))
end


local function pushFuel(furnaces)
    local transferred = 0
    while true do
        local transferred_run = 0
        local items = FUEL_INPUT.list()
        local have_fuel = false

        for slot, item in pairs(items) do
            have_fuel = true
            local itemsPerFurnace = calculateItemsPerFurnace(item.count, #furnaces)
            for _, furnace in pairs(furnaces) do
                transferred_run = transferred_run + furnace.pullItems(FUEL_INPUT_NAME, slot, itemsPerFurnace, FUEL_INPUT_SLOT)
            end
        end

        if not have_fuel then
            if not did_fuel_warning then
                logger.warn("Fuel input is empty - if you encounter slowness issues with smelting, try adding more fuel.")
                did_fuel_warning = true
            end
        else
            did_fuel_warning = false
        end

        if transferred_run <= 0 then
            break
        end

        transferred = transferred + transferred_run
    end

    if transferred > 0 then
        logger.info("Distributed " .. transferred .. " fuel to " .. #furnaces .. " furnaces.")
    end
end

local function pushItems(furnaces)
    local transferred = 0
    while true do
        local transferred_run = 0
        for slot, item in pairs(MAIN_INPUT.list()) do
            local itemsPerFurnace = calculateItemsPerFurnace(item.count, #furnaces)
            for _, furnace in pairs(furnaces) do
                transferred_run = transferred_run + furnace.pullItems(MAIN_INPUT_NAME, slot, itemsPerFurnace, ITEM_INPUT_SLOT)
            end
        end

        if transferred_run <= 0 then
            break
        end

        transferred = transferred + transferred_run
    end

    if transferred > 0 then
        logger.info("Distributed " .. transferred .. " items to " .. #furnaces .. " furnaces.")
    end
end

local smeltingCompleteNotice = false
local function pullItems(furnaces)
    local transferred = 0

    for _, furnace in pairs(furnaces) do
        transferred = transferred + furnace.pushItems(MAIN_OUTPUT_NAME, ITEM_OUTPUT_SLOT, 64)
    end

    if transferred > 0 then
        logger.info("Pulled " .. transferred .. " items from " .. #furnaces .. " furnaces.")
        smeltingCompleteNotice = false
    else
        if not smeltingCompleteNotice then
            logger.info("Smelting complete.")
            smeltingCompleteNotice = true
        end
    end
end

local function fullStateReset(furnaces)
    for _, furnace in pairs(furnaces) do
        furnace.pushItems(MAIN_OUTPUT_NAME, ITEM_OUTPUT_SLOT)
        furnace.pushItems(MAIN_INPUT_NAME, ITEM_INPUT_SLOT)
        furnace.pushItems(FUEL_INPUT_NAME, FUEL_INPUT_SLOT)
    end
end
    
-- main

local furnaces = getFurnaceList()

logger.info("Found " .. #furnaces .. " furnaces in your array!")

if #furnaces == 0 then
    logger.error("No furnaces found in network. Please connect at least one furnace to the network.")
    error("No furnaces found in network.")
end

logger.info("Clearing all furnaces for even distribution...")
fullStateReset(furnaces)

logger.info("UberFurnace is up! Place items in the main input chest to begin smelting.")

parallel.waitForAll(
    function()
        while true do
            pushFuel(furnaces)
            sleep(1)
        end
    end,
    function()
        while true do
            pushItems(furnaces)
            sleep(1)
        end
    end,
    function()
        while true do
            pullItems(furnaces)
            sleep(10)
        end
    end
)