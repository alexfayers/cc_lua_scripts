-- Script to use the command api to tell a player something
local logging = require("afscript.core.logging")
local logger = logging.new("teller")
local remote = require("afscript.core.remote")

local PROTOCOL = "tell"
local _initialized = false


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


local function tell(player, message)
    if not _initialized then
        logger.error("Not initialised")
        return false
    end

    local packet = remote.build_packet(PROTOCOL, "tell", {
        player = player,
        message = message
    })

    remote.broadcast(PROTOCOL, packet)

    logger.success("Sent tell command")
    return true
end


local function host_tell(player, message)
    logger.info("Telling " .. player .. " " .. message)
    return commands.tell(player, message)
end


local function getCommands()
    while true do
        local packet = remote.receive(PROTOCOL)

        if packet then
            if packet.type == "tell" then
                host_tell(packet.data.player, packet.data.message)
            else
                logger.error("Received invalid packet type")
            end
        else
            logger.error("Failed to receive packet")
        end
    end
end

-- Main

local args = {...}

if args[1] == "host" then  -- not using as library
    if not _initialize() then
        logger.error("Failed to initialise")
        return
    end

    getCommands()
end
