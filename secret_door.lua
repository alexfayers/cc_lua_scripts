local logging = require("afscript.core.logging")
local logger = logging.new("secret_door")
local remote = require("afscript.core.remote")

local PROTOCOL = "secret_door"
local _initialized = false

local function open()
    if turtle.getItemCount() >= 2 then
        logger.error("Door is already open.")
        return
    end
    
    logger.info("Opening door...")
    turtle.turnRight()
    turtle.forward()
    turtle.turnLeft()
    turtle.dig()
    
    turtle.up()
    turtle.dig()
    
    turtle.turnLeft()
    turtle.forward()
    turtle.down()
    turtle.turnRight()
    
    logger.info("Door opened.")
end

local function close()
    if turtle.getItemCount() < 2 then
        logger.error("Door is already closed.")
        return
    end
    
    logger.info("Closing door...")
    turtle.turnRight()
    turtle.forward()
    turtle.turnLeft()
    turtle.place()
    
    turtle.up()
    turtle.place()
    
    turtle.turnLeft()
    turtle.forward()
    turtle.down()
    turtle.turnRight()
    
    logger.info("Door closed.")
end

---Initialise the network system
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


local function main()
    if not _initialize() then
        logger.error("Failed to initialise modem")
        return
    end

    while true do
        local packet = remote.receive(PROTOCOL)

        if not packet then
            logger.error("Failed to receive packet")
            return nil
        end
    
        if packet.type == "open" then
            open()
        elseif packet.type == "close" then
            close()
        else
            logger.error("Unknown packet type: " .. packet.type)
        end
    end
end

main()
