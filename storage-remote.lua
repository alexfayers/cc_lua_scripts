--- A chat program for the computer.

---Imports

local strings = require("cc.strings")
local remote = require("afscript.core.remote")
local logging = require("afscript.core.logging")
local logger = logging.new("storage-remote", logging.LEVEL.ERROR)
local gui_config = require("afscript.gui.config")
local gui = require("afscript.gui.gui")


local basaltPath = "basalt.lua"
if not(fs.exists(basaltPath))then
    shell.run("pastebin run ESs1mg7P packed true "..basaltPath:gsub(".lua", ""))
end

-- load basalt
local basalt = require(basaltPath:gsub(".lua", ""))


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

---Main
local function main_receive()
    if not _initialized then
        logger.error("Not initialised")
        return false
    end

    while true do
        local packet = remote.receive(PROTOCOL, {PARENT_PC})

        if not packet then
            logger.error("Failed to receive packet")
            return
        end

        if packet.type ~= "update" then
            basalt.debug("Received invalid packet type")
            return
        end

        basalt.debug("Received message from " .. packet.sender)
        local message = textutils.serialize(packet.data.items)

        if not message then
            basalt.debug("Failed to receive message")
            return
        end

        -- message has been validated

        basalt.debug(message)
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
local screen_width, screen_height = term.getSize()

local mainFrame = basalt.createFrame("mainFrame")
    :setBackground(gui_config.colors.main.bg)
    :show()

local commandThread = mainFrame:addThread()
local updateThread = mainFrame:addThread()
local receiveThead = mainFrame:addThread()

local noticeLabel = gui.newLabel(mainFrame, "noticeLabel", 1, 14, "")
    :setForeground(gui_config.colors.label.notice)

local function updateAction()
    updateThread:start(function()
        noticeLabel:setText("Updating items")
        send_command("update", {})
        noticeLabel:setText("Updated items")
        sleep(0.1)
    end)
end

local function pushAction()
    -- basalt.debug("push")
    noticeLabel:setText("Pushing all items")

    commandThread:start(function()
        send_command("push", {})

        noticeLabel:setText("Pushed all items")
        -- updateAction()
        sleep(0.1)
    end)
end
    
    

local pushButton = gui.newButton(mainFrame, "pushButton", screen_width - gui_config.sizes.button.width - 1, 10, "Push to storage", pushAction)


if not _initialize() then
    logger.error("Failed to initialise")
    return
end

receiveThead:start(main_receive)

-- updateAction()

basalt.autoUpdate()
