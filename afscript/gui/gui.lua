-- load gui config
local config = require("afscript.gui.config")
local basalt = require("afscript.gui.basalt")

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

---Create a new themed label
---@param mainFrame any The main frame to add the button to
---@param name string The name of the button
---@param positionX number The x position of the button
---@param positionY number The y position of the button
---@param text string The text of the button
---@param fontSize number|nil The font size of the button
---@return unknown _ The label
local function newLabel(mainFrame, name, positionX, positionY, text, fontSize)
    if not fontSize then
        fontSize = 1
    end

    return mainFrame
        :addLabel(name)
        :setPosition(positionX, positionY)
        :setText(text)
        :setFontSize(fontSize)
        :setBackground(config.colors.main.bg)
        :setForeground(config.colors.main.fg)
        :show()
end


---Create a new themed button
---@param mainFrame any The main frame to add the button to
---@param name string The name of the button
---@param positionX number The x position of the button
---@param positionY number The y position of the button
---@param text string The text of the button
---@param onClick function The onclick function of the button
---@return unknown _ The button
local function newButton(mainFrame, name, positionX, positionY, text, onClick)
    local button = mainFrame
        :addButton(name)
        :setPosition(positionX, positionY)
        :setText(text)
        :onClick(onClick)
        :show()
    
    setupButtonColoring(button)

    return button
end



return {
    setupButtonColoring = setupButtonColoring,
    newLabel = newLabel,
    newButton = newButton,
}