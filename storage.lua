-- download basalt if it's not downloaded already
local basaltPath = "basalt.lua"
if not(fs.exists(basaltPath))then
    shell.run("pastebin run ESs1mg7P packed true "..basaltPath:gsub(".lua", ""))
end

-- download storage if it's not downloaded already
local update = require("afscript.meta.update")
update.update_library({
    submodules = {
        "storage"
    }
})

-- load basalt
local basalt = require(basaltPath:gsub(".lua", ""))

-- load storage
local storage = require("afscript.storage.storage")

-- setup config
local config = {
    colors = {
        main = {
            bg = colors.lightBlue,
            fg = colors.white
        },
        button = {
            bg = colors.white,
            fg = colors.black,
            bg_press = colors.lightGray,
            fg_press = colors.gray,
            bg_disabled = colors.lightGray,
        },
        input = {
            bg = colors.white,
            fg = colors.black
        },
        label = {
            bg = colors.white,
            fg = colors.black,
            notice = colors.orange,
        },
        bar = {
            bg = colors.white,
            fg_low = colors.green,
            fg_med = colors.orange,
            fg_high = colors.red,
            label = colors.orange
        },
    },
    sizes = {
        button = {
            width = 19,
            height = 3
        }
    }
}

local screen_width, screen_height = term.getSize()
local items = { }

-- create a new gui
local function setupButtonColoring(self, event, button, x, y)
    self:setHorizontalAlign("center")
    self:setVerticalAlign("center")
    
    self:setBackground(config.colors.button.bg)
    self:setForeground(config.colors.button.fg)

    local text = self:getValue()
    local width

    if string.len(text) > config.sizes.button.width then
        width = string.len(text) + 2
    else
        width = config.sizes.button.width
    end

    self:setSize(width, config.sizes.button.height)

    self:onClick(function()
        self:setBackground(config.colors.button.bg_press) 
        self:setForeground(config.colors.button.fg_press)
    end)
    self:onClickUp(function() 
        self:setBackground(config.colors.button.bg)
        self:setForeground(config.colors.button.fg)
    end)
    self:onLoseFocus(function() 
        self:setBackground(config.colors.button.bg)
        self:setForeground(config.colors.button.fg)
    end)
end


-- render everything
local mainFrame = basalt.createFrame("mainFrame")
    :setBackground(config.colors.main.bg)
    :show()

local function updateItems()
    local raw_items = storage.getInventory()

    items = {}
    for k, v in pairs(raw_items) do
        local c = 0
        for match in string.gmatch(k, '([^:]+)') do
            if c == 1 then
                items[match] = v
            end
            c = c + 1
        end
    end
end

-- from https://stackoverflow.com/questions/15706270/sort-a-table-in-lua
local function spairs(t, order)
    -- collect the keys
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end

    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys 
    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end

    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

local function populateItemList(filter)
    local itemList = mainFrame:getObject("itemList")
    itemList:clear()
    
    for item_name, item_count in spairs(items) do
        if filter ~= "" then
            if string.find(item_name, filter) then
                itemList:addItem(item_name, nil, nil, item_count)
            end
        else
            itemList:addItem(item_name, nil, nil, item_count)
        end
    end
end
    
-- title label
local searchLabel = mainFrame
    :addLabel("searchBoxLabel")
    :setPosition(3, 3)
    :setText("Storage")
    :setFontSize(2)
    :setBackground(config.colors.main.bg)
    :setForeground(config.colors.main.fg)
    :show()


-- notice label
local noticeLabel = mainFrame
    :addLabel("noticeLabel")
    :setPosition(24, 14)
    :setText("")
    -- :setBackground(config.colors.main.bg)
    :setForeground(config.colors.label.notice)
    :show()

local fullnessLabel = mainFrame
    :addLabel("fullnessLabel")
    :setPosition(24, 17)
    :setText("")
    -- :setBackground(config.colors.main.bg)
    :setForeground(config.colors.bar.label)
    :show()

local fullnessBar = mainFrame
    :addProgressbar("fullnessBar")
    :setPosition(24, 18)
    :setSize(26, 1)
    :setProgress(0)
    :setBackground(config.colors.bar.bg)
    :setProgressBar(config.colors.bar.fg_low)
    :show()

-- Search stuff

local readThread = mainFrame:addThread()
local storageThread = mainFrame:addThread()
local fullnessThread = mainFrame:addThread()

local searchBox = mainFrame
    :addInput("searchBox")
    :setInputType("text")
    :setPosition(3, 6)
    :setSize(20, 1)
    :setDefaultText("Item pull search...", config.colors.input.fg, config.colors.input.bg)
    :onChange(function (self)
        local search = self:getValue()

        populateItemList(search)
        mainFrame:getObject("itemList"):setOffset(0)
    end)
    :show()


local amountLabel = mainFrame
    :addLabel("amountLabel")
    :setPosition(24, 8)
    :setText("Amount")
    :setFontSize(1)
    :setBackground(config.colors.main.bg)
    :setForeground(config.colors.main.fg)
    :show()

local amountInput = mainFrame
    :addInput("amountInput")
    :setInputType("number")
    :setPosition(24, 10)
    :setSize(6, 1)
    :setDefaultText("1", config.colors.input.fg, config.colors.input.bg)
    :setBackground(config.colors.input.bg)
    :setForeground(config.colors.input.fg)
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
    :setBackground(config.colors.input.bg)
    :setForeground(config.colors.input.fg)
    :onChange(function(self)
        local pullButton = mainFrame:getObject("pullButton")
        
        local item_index = self:getItemIndex()
        if item_index ~= nil then
            pullButton:setBackground(config.colors.button.bg)
            pullButton:enable()

            local item = self:getItem(item_index)

            amountInput:setValue(items[item.text])

            fullnessThread:start(function()
                local fullness = storage.calculateFullnessPercentage()
                fullnessLabel:setText("Fullness: " .. fullness .. "%")

                fullnessBar:setProgress(fullness)
                if fullness < 50 then
                    fullnessBar:setProgressBar(config.colors.bar.fg_low)
                elseif fullness < 75 then
                    fullnessBar:setProgressBar(config.colors.bar.fg_mid)
                else
                    fullnessBar:setProgressBar(config.colors.bar.fg_high)
                end
                os.sleep(0.1)
            end)
        else
            pullButton:setBackground(config.colors.button.bg_disabled)
            pullButton:disable()
        end
    end)
    :show()



local pullButton = mainFrame
    :addButton("pullButton")
    :setPosition(screen_width - config.sizes.button.width - 1, 6) 
    :setText("Pull from storage")
    :onClick(function()
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
                populateItemList(searchBox:getValue())
                os.sleep(0.1)
            end)
            os.sleep(0.1)
        end)
    end)
    :setBackground(config.colors.button.bg_disabled)
    :disable()
    :show()

-- Push stuff
local pushButton = mainFrame --> Basalt returns an instance of the object on most methods, to make use of "call-chaining"
    :addButton("pushButton") --> This is an example of call chaining
    :setPosition(screen_width - config.sizes.button.width - 1, 10)
    :setText("Push to storage")
    :onClick(function() 
        -- basalt.debug("push")
        noticeLabel:setText("Pushing all items")

        storageThread:start(function()
            storage.pushAllToStorage()
            noticeLabel:setText("Pushed all items")
            readThread:start(function()
                updateItems()
                populateItemList(searchBox:getValue())
                os.sleep(0.1)
            end)
            os.sleep(0.1)
        end)
    end)
    :show()


setupButtonColoring(pullButton)
pullButton:setBackground(config.colors.button.bg_disabled)

setupButtonColoring(pushButton)

-- initial list population
updateItems()
populateItemList("")

basalt.autoUpdate()

