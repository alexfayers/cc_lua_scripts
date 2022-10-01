--- A chat program for the computer.

---Imports

local strings = require("cc.strings")
local remote = require("afscript.core.remote")
local logging = require("afscript.core.logging")
local logger = logging.new("storage-remote", logging.LEVEL.ERROR)

---Constants

local PROTOCOL = "alex_storage"
local PARENT_PC = 9

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
local function receive_packet()
    if not _initialized then
        logger.error("Not initialised")
        return nil
    end

    local packet = remote.receive(PROTOCOL, {PARENT_PC})

    if not packet then
        logger.error("Failed to receive packet")
        return nil
    end

    if packet.type ~= "update" then
        logger.error("Received invalid packet type")
        return nil
    end

    logger.success("Received message from " .. packet.sender)
    return textutils.serialize(packet.data.items)
end

---Main
local function main_receive()
    if not _initialized then
        logger.error("Not initialised")
        return false
    end

    local x_size, y_size = term.getSize()

    while true do
        local message = receive_packet()

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

---Send a command to the parent computer
---@param command string _ The command to send
---@param data table _ The data to send
---@return boolean _ Whether the command was sent successfully or not
local function send_command(command, data)
    local packet = remote.build_packet(PROTOCOL, command, data)
    remote.send(PROTOCOL, packet, PARENT_PC)
    return true  -- TODO: check if the packet was sent successfully
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
            send_command("push", {})
        elseif message == "pull" then
            send_command("pull", {
                search = "dirt",
                count = 1
            })
        elseif message == "update" then
            send_command("update", {})
        end
    end
end

-- Basalt stuff

local basaltPath = "basalt.lua"
if not(fs.exists(basaltPath))then
    shell.run("pastebin run ESs1mg7P packed true "..basaltPath:gsub(".lua", ""))
end

-- load basalt
local basalt = require(basaltPath:gsub(".lua", ""))

local mainFrame = basalt.createFrame("mainFrame")
    :setBackground(config.colors.main.bg)
    :show()

local pushButton = mainFrame --> Basalt returns an instance of the object on most methods, to make use of "call-chaining"
    :addButton("pushButton") --> This is an example of call chaining
    :setPosition(2, 10)
    :setText("Push to storage")
    :onClick(pushAction)
    :show()


local function main()
    if not _initialize() then
        logger.error("Failed to initialise")
        return
    end

    parallel.waitForAny(main_receive, main_send)
end

main()
