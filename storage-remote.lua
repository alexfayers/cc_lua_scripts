--- A chat program for the computer.

---Imports

local strings = require("cc.strings")
local remote = require("afscript.core.remote")
local logging = require("afscript.core.logging")
local logger = logging.new("storage-remote", logging.LEVEL.ERROR)
local gui_config = require("afscript.gui.config")
local gui = require("afscript.gui.gui")
local helper = require("afscript.core.helper")


local basaltPath = "basalt.lua"
if not(fs.exists(basaltPath))then
    shell.run("pastebin run ESs1mg7P packed true "..basaltPath:gsub(".lua", ""))
end

-- load basalt
local basalt = require(basaltPath:gsub(".lua", ""))

settings.define("storage.parent_id", {
    description = "ID for the parent computer",
    default=nil,
    type = "number"
})

settings.define("storage.network_name", {
    description = "Name of the protocol to use for networked control of the storage system. Must be the same for child and parent computers.",
    default=nil,
    type = "number"
})

---Constants

local PROTOCOL = settings.get("storage.network_name")
local PARENT_PC = settings.get("storage.parent_id")

if not PROTOCOL then
    logger.error("No network name specified in settings. Please run 'set storage.network_name {NAME}'.")
    error("No network name specified in settings.")
end

if not PARENT_PC then
    logger.error("No parent ID specified in settings. Please run 'set storage.parent_id {ID}'.")
    error("No parent ID specified in settings.")
end


---Variables

local _initialized = false
local items = { }
local fullness = 0

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
    return true  -- TODO: check if the packet was sent successfully
end

-- Basalt stuff
local screen_width, screen_height = term.getSize()

local mainFrame = basalt.createFrame("mainFrame")
    :setBackground(gui_config.colors.main.bg)
    :show()

local function populateItemList(filter)
    local itemList = mainFrame:getObject("itemList")
    itemList:clear()
    
    for item_name, item_count in helper.spairs(items) do
        if filter ~= "" then
            if string.find(item_name, filter) then
                itemList:addItem(item_name, nil, nil, item_count)
            end
        else
            itemList:addItem(item_name, nil, nil, item_count)
        end
    end
end
    
    
local commandThread = mainFrame:addThread()
local receiveThead = mainFrame:addThread()

local noticeLabel = gui.newLabel(mainFrame, "noticeLabel", 3, 1, "")
    :setForeground(gui_config.colors.label.notice)

-- local fullnessLabel = gui.newLabel(mainFrame, "fullnessLabel", 3, 18, "")
--     :setForeground(gui_config.colors.bar.label)

local fullnessBar = mainFrame
    :addProgressbar("fullnessBar")
    :setPosition(3, 19)
    :setSize(21, 1)
    :setProgress(0)
    :setBackground(gui_config.colors.bar.bg)
    :setProgressBar(gui_config.colors.bar.fg_low)
    :show()


local searchBox = mainFrame
    :addInput("searchBox")
    :setInputType("text")
    :setPosition(3, 2)
    :setSize(21, 1)
    :setDefaultText("Item pull search...", gui_config.colors.input.fg, gui_config.colors.input.bg)
    :onChange(function (self)
        local search = self:getValue()

        populateItemList(search)
        mainFrame:getObject("itemList"):setOffset(0)
    end)
    :show()


local amountLabel = gui.newLabel(mainFrame, "amountLabel", 3, 13, "Amount", 1)

local amountInput = mainFrame
    :addInput("amountInput")
    :setInputType("number")
    :setPosition(10, 13)
    :setSize(6, 1)
    :setDefaultText("1", gui_config.colors.input.fg, gui_config.colors.input.bg)
    :setBackground(gui_config.colors.input.bg)
    :setForeground(gui_config.colors.input.fg)
    :onChange(function (self)
        local search = self:getValue()

        if search == "" then
            search = "1"
        end

        local amount = tonumber(search)

        local itemList = mainFrame:getObject("itemList")
        local item = itemList:getItemIndex()

        if item ~= nil then
            local item_name = itemList:getItem(item).text
            local item_count = items[item_name]

            if amount > item_count then
                self:setValue(item_count)
            elseif amount < 1 then
                self:setValue(1)
            end
        end
    end)
    :show()


local itemList = mainFrame
    :addList("itemList")
    :setPosition(3, 4)
    :setSize(21, 8)
    :setScrollable(true)
    :setBackground(gui_config.colors.input.bg)
    :setForeground(gui_config.colors.input.fg)
    :onChange(function(self)
        local pullButton = mainFrame:getObject("pullButton")
        
        local item_index = self:getItemIndex()
        if item_index ~= nil then
            pullButton:setBackground(gui_config.colors.button.bg)
            pullButton:enable()

            local item = self:getItem(item_index)

            amountInput:setValue(items[item.text])

            -- fullnessLabel:setText("Fullness: " .. fullness .. "%")

            fullnessBar:setProgress(fullness)
            if fullness < 50 then
                fullnessBar:setProgressBar(gui_config.colors.bar.fg_low)
            elseif fullness < 75 then
                fullnessBar:setProgressBar(gui_config.colors.bar.fg_mid)
            else
                fullnessBar:setProgressBar(gui_config.colors.bar.fg_high)
            end
        else
            pullButton:setBackground(gui_config.colors.button.bg_disabled)
            pullButton:disable()
        end
    end)
    :show()

local function disableButtons()
    local pullButton = mainFrame:getObject("pullButton")
    pullButton:setBackground(gui_config.colors.button.bg_disabled)
    pullButton:disable()

    local pushButton = mainFrame:getObject("pushButton")
    pushButton:setBackground(gui_config.colors.button.bg_disabled)
    pushButton:disable()
end

local function enableButtons()
    local pullButton = mainFrame:getObject("pullButton")
    pullButton:setBackground(gui_config.colors.button.bg)
    pullButton:enable()

    local pushButton = mainFrame:getObject("pushButton")
    pushButton:setBackground(gui_config.colors.button.bg)
    pushButton:enable()
end

local function main_receive()
    if not _initialized then
        logger.error("Not initialised")
        return false
    end

    while true do
        local packet = remote.receive(PROTOCOL, {PARENT_PC})

        if not packet then
            basalt.debug("Failed to receive packet")
            return
        end

        if packet.type ~= "update" then
            basalt.debug("Received invalid packet type")
            return
        end

        -- basalt.debug("Received message from " .. packet.sender)

        if not packet.data.items or not packet.data.fullness then
            basalt.debug("Failed to receive valid update")
            return
        end

        items = packet.data.items
        fullness = packet.data.fullness
        
        populateItemList(searchBox:getValue())
        noticeLabel:setText("Updated items")
        enableButtons()
    end
end 

local function updateAction()
    -- return 
    noticeLabel:setText("Updating items")
    send_command("update", {})
end

local function pushAction()
    -- basalt.debug("push")
    noticeLabel:setText("Pushing all items")

    commandThread:start(function()
        send_command("push", {})

        noticeLabel:setText("Requested push")
        disableButtons()
        -- updateAction()
        sleep(0.1)
    end)
end

local function pullAction()
    local search_index = itemList:getItemIndex()
    local search = itemList:getItem(search_index).text

    local amount = amountInput:getValue()

    -- basalt.debug("pull " .. search .. " " .. amount)
    noticeLabel:setText("Pulling " .. amount .. " " .. search)

    commandThread:start(function()
        send_command("pull", {
            search = search,
            count = tonumber(amount)
        })
        noticeLabel:setText("Requested " .. amount .. " " .. search)
        disableButtons()
        -- updateAction()
        sleep(0.1)
    end)
end

local pushButton = gui.newButton(mainFrame, "pushButton", 15, 15, "Push", pushAction)
    :setSize(9, gui_config.sizes.button.height)


local pullButton = gui.newButton(mainFrame, "pullButton", 3, 15, "Pull", pullAction)
    :setSize(9, gui_config.sizes.button.height)


if not _initialize() then
    logger.error("Failed to initialise")
    return
end

receiveThead:start(main_receive)

disableButtons()
updateAction()

basalt.autoUpdate()
