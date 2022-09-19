--- A chat program for the computer.

---Imports

local remote = require("afscript.core.remote")
local logging = require("afscript.core.logging")
local logger = logging.new("chat", logging.LEVEL.ERROR)

---Constants

local PROTOCOL = "afscript_chat"

---Variables

local _initialized = false

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

---Send a message to a computer
---@param message string The message to send
---@return boolean _ Whether the message was sent successfully or not
local function send_message(message)
    if not _initialized then
        logger.error("Not initialised")
        return false
    end

    local packet = remote.build_packet(PROTOCOL, "message", {
        message = message
    })

    remote.broadcast(PROTOCOL, packet)

    logger.success("Sent message")
    return true
end


---Receive a message from a computer
---@return string|nil _ The message received
local function receive_message()
    if not _initialized then
        logger.error("Not initialised")
        return nil
    end

    local packet = remote.receive(PROTOCOL)

    if not packet then
        logger.error("Failed to receive packet")
        return nil
    end

    if packet.type ~= "message" then
        logger.error("Received invalid packet type")
        return nil
    end

    logger.success("Received message from " .. packet.sender)
    return packet.sender .. ": " .. packet.data.message
end

-- ---Close the chat system
-- ---@return boolean _ Whether the system was closed successfully or not
-- local function close()
--     if not _initialized then
--         logger.error("Not initialised")
--         return false
--     end

--     if not remote.close(PROTOCOL) then
--         logger.error("Failed to close remote")
--         return false
--     end

--     _initialized = false
--     logger.success("Closed")
--     return true
-- end

---Main
local function main_receive()
    if not _initialized then
        logger.error("Not initialised")
        return false
    end

    while true do
        local message = receive_message()

        if not message then
            logger.error("Failed to receive message")
            return
        end

        print(message)
    end
end

local function main_send()
    if not _initialized then
        logger.error("Not initialised")
        return false
    end

    while true do
        write("~: ")
        local message = read()

        send_message(message)
    end
end

local function main()
    if not _initialize() then
        logger.error("Failed to initialise")
        return
    end

    parallel.waitForAny(main_receive, main_send)
end

main()
