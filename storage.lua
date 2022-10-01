-- download storage if it's not downloaded already
local update = require("afscript.meta.update")
update.update_library({
    submodules = {
        "storage"
    }
})

-- load storage
local storage = require("afscript.storage.storage")
local remote = require("afscript.core.remote")
local logging = require("afscript.core.logging")
local logger = logging.new("storage", logging.LEVEL.ERROR)
local gui_config = require("afscript.gui.config")
local gui = require("afscript.gui.gui")
local basalt = require("afscript.gui.basalt")
local helper = require("afscript.core.helper")

local screen_width, screen_height = term.getSize()
local items = { }
local fullness = 0

-- remote control stuff

settings.define("storage.network_name", {
    description = "Name of the protocol to use for networked control of the storage system. Must be the same for child and parent computers.",
    default=nil,
    type = "string"
})

---Constants

local PROTOCOL = settings.get("storage.network_name")

if not PROTOCOL then
    logger.error("No network name specified in settings. Please run 'set storage.network_name {NAME}'.")
    error("No network name specified in settings.")
end

---Variables

local _initialized = false

-- create a new gui

-- render everything
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
    
-- labels
local searchLabel = gui.newLabel(mainFrame, "searchBoxLabel", 3, 3, "Storage", 2)

local noticeLabel = gui.newLabel(mainFrame, "noticeLabel", 24, 14, "")
    :setForeground(gui_config.colors.label.notice)

local fullnessLabel = gui.newLabel(mainFrame, "fullnessLabel", 24, 17, "")
    :setForeground(gui_config.colors.bar.label)

local fullnessBar = mainFrame
    :addProgressbar("fullnessBar")
    :setPosition(24, 18)
    :setSize(26, 1)
    :setProgress(0)
    :setBackground(gui_config.colors.bar.bg)
    :setProgressBar(gui_config.colors.bar.fg_low)
    :show()

-- Search stuff

local readThread = mainFrame:addThread()
local storageThread = mainFrame:addThread()
local fullnessThread = mainFrame:addThread()
local controlThread = mainFrame:addThread()

local searchBox = mainFrame
    :addInput("searchBox")
    :setInputType("text")
    :setPosition(3, 6)
    :setSize(20, 1)
    :setDefaultText("Item pull search...", gui_config.colors.input.fg, gui_config.colors.input.bg)
    :onChange(function (self)
        local search = self:getValue()

        populateItemList(search)
        mainFrame:getObject("itemList"):setOffset(0)
    end)
    :show()

local amountLabel = gui.newLabel(mainFrame, "amountLabel", 24, 8, "Amount", 1)

local amountInput = mainFrame
    :addInput("amountInput")
    :setInputType("number")
    :setPosition(24, 10)
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
    :setPosition(3, 8)
    :setSize(20, 11)
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

            fullnessThread:start(function()
                local fullness = storage.calculateFullnessPercentage()
                fullnessLabel:setText("Fullness: " .. fullness .. "%")

                fullnessBar:setProgress(fullness)
                if fullness < 50 then
                    fullnessBar:setProgressBar(gui_config.colors.bar.fg_low)
                elseif fullness < 75 then
                    fullnessBar:setProgressBar(gui_config.colors.bar.fg_mid)
                else
                    fullnessBar:setProgressBar(gui_config.colors.bar.fg_high)
                end
                sleep(0.1)
            end)
        else
            pullButton:setBackground(gui_config.colors.button.bg_disabled)
            pullButton:disable()
        end
    end)
    :show()


local function sendRemoteUpdate()
    readThread:start(function()
        local packet = remote.build_packet(PROTOCOL, "update", {
            items = items,
            fullness = fullness
        })

        remote.broadcast(PROTOCOL, packet)
        sleep(0.1)
    end)
end
    
local function updateItems()
    items, fullness = storage.getInventoryClean()
    populateItemList(searchBox:getValue())
    sendRemoteUpdate()
end



-- pull stuff

local function pullAction()
    local search_index = itemList:getItemIndex()
    local search = itemList:getItem(search_index).text

    local amount = amountInput:getValue()

    -- basalt.debug("pull " .. search .. " " .. amount)
    noticeLabel:setText("Pulling " .. amount .. " " .. search)

    storageThread:start(function()
        storage.pullFromStorage(search, tonumber(amount))
        noticeLabel:setText("Pulled " .. amount .. " " .. search)
        readThread:start(function()
            updateItems()
            sleep(0.1)
        end)
        sleep(0.1)
    end)
end

-- Push stuff



local function pushAction()
    -- basalt.debug("push")
    noticeLabel:setText("Pushing all items")

    storageThread:start(function()
        storage.pushAllToStorage()
        noticeLabel:setText("Pushed all items")
        readThread:start(function()
            updateItems()
            sleep(0.1)
        end)
        sleep(0.1)
    end)
end

local pushButton = gui.newButton(mainFrame, "pushButton", screen_width - gui_config.sizes.button.width - 1, 10, "Push to storage", pushAction)

local pullButton = gui.newButton(mainFrame, "pullButton", screen_width - gui_config.sizes.button.width - 1, 6, "Pull from storage", pullAction)
    :disable()
    :setBackground(gui_config.colors.button.bg_disabled)


-- initial list population
updateItems()


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

local function _readMessages()
    if not _initialized then
        _initialize()
    end

    while true do
        local packet = remote.receive(PROTOCOL)

        if packet then
            if packet.type == "push" then
                -- basalt.debug("Received push packet")
                pushAction()
            elseif packet.type == "pull" then
                -- basalt.debug("Received pull packet")
                storageThread:start(function()
                    if storage.pullFromStorage(packet.data.search, tonumber(packet.data.count)) then
                        noticeLabel:setText("Pulled " .. packet.data.count .. " " .. packet.data.search)
                        readThread:start(function()
                            updateItems()
                            populateItemList(searchBox:getValue())
                            sendRemoteUpdate()
                            sleep(0.1)
                        end)
                    else
                        -- how can they even see this??? hax!!
                        noticeLabel:setText("Not enough " .. packet.data.search)
                    end
                    sleep(0.1)
                end)
            elseif packet.type == "update" then
                -- basalt.debug("Received update packet")
                sendRemoteUpdate()
            else
                basalt.debug("Received unknown packet")
            end

        else
            basalt.debug("No packet received")
        end
    end
end

-- end remote control stuff

controlThread:start(_readMessages)  -- Start the remote control thread

basalt.autoUpdate()

