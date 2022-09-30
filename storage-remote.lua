--- A chat program for the computer.

---Imports

local strings = require("cc.strings")
local remote = require("afscript.core.remote")
local logging = require("afscript.core.logging")
local logger = logging.new("storage-remote", logging.LEVEL.ERROR)

---Constants

local PROTOCOL = "alex_storage"

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

---Receive a message from a computer
---@return string|nil _ The message received
local function receive_message()
    if not _initialized then
        logger.error("Not initialised")
        return nil
    end

    local packet = remote.receive(PROTOCOL, {9})

    if not packet then
        logger.error("Failed to receive packet")
        return nil
    end

    if packet.type ~= "update" then
        logger.error("Received invalid packet type")
        return nil
    end

    logger.success("Received message from " .. packet.sender)
    return packet.sender .. ": " .. packet.data.items
end

---Main
local function main_receive()
    if not _initialized then
        logger.error("Not initialised")
        return false
    end

    local x_size, y_size = term.getSize()

    while true do
        local message = receive_message()

        if not message then
            logger.error("Failed to receive message")
            return
        end

        local lines = strings.wrap(message, x_size)
        -- reset the cursor position
        term.setCursorPos(1, y_size)

        for i = 1, #lines do
            -- write the line
            write(lines[i])

            -- reset the cursor position
            term.setCursorPos(1, y_size)

            -- scroll the terminal up
            term.scroll(1)
        end

        write("~: ")
    end
end

local function main_send()
    if not _initialized then
        logger.error("Not initialised")
        return false
    end

    local _, y_size = term.getSize()

    while true do
        write("~: ")
        local message = read()
        -- reset the cursor position
        term.setCursorPos(1, y_size)

        if message == "push" then
            local packet = remote.build_packet(PROTOCOL, "push", {})
            remote.send(PROTOCOL, packet, 9)
        elseif message == "pull" then
            local packet = remote.build_packet(PROTOCOL, "pull", {
                search = "dirt",
                count = 1
            })
            remote.send(PROTOCOL, packet, 9)
        elseif message == "update" then
            local packet = remote.build_packet(PROTOCOL, "update", {})
            remote.send(PROTOCOL, packet, 9)
        end
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
