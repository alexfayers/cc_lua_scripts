local logging = require("afscript.core.logging")
local logger = logging.new("secret_door_control")
local remote = require("afscript.core.remote")

local PROTOCOL = "secret_door"
local DOOR_ID = 20
local _initialized = false


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


local function open()
    if not _initialized then
        logger.error("Not initialised")
        return false
    end

    local packet = remote.build_packet(PROTOCOL, "open", {})

    remote.send(PROTOCOL, packet, DOOR_ID)

    logger.success("Sent open command")
    return true
end


local function close()
    if not _initialized then
        logger.error("Not initialised")
        return false
    end

    local packet = remote.build_packet(PROTOCOL, "close", {})

    remote.send(PROTOCOL, packet, DOOR_ID)

    logger.success("Sent close command")
    return true
end


---Main
if not _initialize() then
    logger.error("Failed to initialise")
    return
end

local args = {...}
if #args == 0 then
    logger.error("No arguments provided")
    return
end

if args[1] == "open" then
    open()
elseif args[1] == "close" then
    close()
else
    logger.error("Invalid argument")
end
