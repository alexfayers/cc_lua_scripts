-- Turtle movement functions

local state = require("afscript.core.state")
local logging = require("afscript.core.logging")

local logger = logging.new("turtle")

local STATEFILE = ".turtle.position.state"

local _current_position = state.load(STATEFILE) or {
    x = 0,
    y = 0,
    z = 0,
    direction = "north"
}

local function _currentPositionString()
    return "x=" .. _current_position.x .. ", y=" .. _current_position.y .. ", z=" .. _current_position.z .. ", direction=" .. _current_position.direction
end


---Turn the turtle left, updating the position state
---@return boolean _ True if the turtle turned left
local function _turnLeft()
    local success = turtle.turnLeft()
    if success then
        if _current_position.direction == "north" then
            _current_position.direction = "west"
        elseif _current_position.direction == "west" then
            _current_position.direction = "south"
        elseif _current_position.direction == "south" then
            _current_position.direction = "east"
        elseif _current_position.direction == "east" then
            _current_position.direction = "north"
        end

        logger.debug("Turned LEFT to " .. _currentPositionString())

        state.save(_current_position, STATEFILE)
    end

    return success
end

---Turn the turtle right, updating the position state
---@return boolean _ True if the turtle turned right
local function _turnRight()
    local success = turtle.turnRight()
    if success then
        if _current_position.direction == "north" then
            _current_position.direction = "east"
        elseif _current_position.direction == "east" then
            _current_position.direction = "south"
        elseif _current_position.direction == "south" then
            _current_position.direction = "west"
        elseif _current_position.direction == "west" then
            _current_position.direction = "north"
        end

        logger.debug("Turned RIGHT to " .. _currentPositionString())

        state.save(_current_position, STATEFILE)
    end

    return success
end

---Turn the turtle around, updating the position state
---@return boolean _ True if the turtle turned around
local function _turnAround()
    if _turnLeft() and _turnLeft() then
        return true
    else
        return false
    end
end

---Move the turtle forward one space, updating the position state
---@return boolean _ True if the turtle moved forward
local function _forward()
    local success = turtle.forward()
    if success then
        if _current_position.direction == "north" then
            _current_position.z = _current_position.z - 1
        elseif _current_position.direction == "east" then
            _current_position.x = _current_position.x + 1
        elseif _current_position.direction == "south" then
            _current_position.z = _current_position.z + 1
        elseif _current_position.direction == "west" then
            _current_position.x = _current_position.x - 1
        end
        logger.debug("Moved FORWARD to " .. _currentPositionString())
        state.save(_current_position, STATEFILE)
    end

    return success
end

---Move the turtle up one space, updating the position state
---@return boolean _ True if the turtle moved up
local function _up()
    local success = turtle.up()
    if success then
        _current_position.y = _current_position.y + 1
        logger.debug("Moved UP to " .. _currentPositionString())
        state.save(_current_position, STATEFILE)
    end

    return success
end

---Move the turtle down one space, updating the position state
---@return boolean _ True if the turtle moved down
local function _down()
    local success = turtle.down()
    if success then
        _current_position.y = _current_position.y - 1
        logger.debug("Moved DOWN to " .. _currentPositionString())
        state.save(_current_position, STATEFILE)
    end

    return success
end

---Turn the turtle to face a specific direction, updating the position state
---@param direction string The direction to face
---@return boolean _ True if the turtle turned to face the direction
local function _face(direction)
    if _current_position.direction == direction then
        return true
    end

    local success = false

    if _current_position.direction == "north" then
        if direction == "east" then
            success = _turnRight()
        elseif direction == "south" then
            success = _turnAround()
        elseif direction == "west" then
            success = _turnLeft()
        end
    elseif _current_position.direction == "east" then
        if direction == "south" then
            success = _turnRight()
        elseif direction == "west" then
            success = _turnAround()
        elseif direction == "north" then
            success = _turnLeft()
        end
    elseif _current_position.direction == "south" then
        if direction == "west" then
            success = _turnRight()
        elseif direction == "north" then
            success = _turnAround()
        elseif direction == "east" then
            success = _turnLeft()
        end
    elseif _current_position.direction == "west" then
        if direction == "north" then
            success = _turnRight()
        elseif direction == "east" then
            success = _turnAround()
        elseif direction == "south" then
            success = _turnLeft()
        end
    else
        logger.error("Invalid direction: " .. direction)
        success = false
    end

    return success
end

---Move the turtle to a specific position, updating the position state
---@param x number The x coordinate to move to
---@param y number The y coordinate to move to
---@param z number The z coordinate to move to
---@return boolean _ True if the turtle moved to the position
local function _moveTo(x, y, z)
    while _current_position.x ~= x do
        local did_turn = false
        if _current_position.x < x then
            did_turn = _face("east")
        elseif _current_position.x > x then
            did_turn = _face("west")
        end
        if not did_turn or not _forward() then
            -- TODO: move around?
            logger.error("Failed to move to x=" .. x, "y=" .. y, "z=" .. z)
            return false
        end
    end
    while _current_position.z ~= z do
        local did_turn = false
        if _current_position.z < z then
            did_turn = _face("south")
        elseif _current_position.z > z then
            did_turn = _face("north")
        end
        if not did_turn or not _forward() then
            logger.error("Failed to move to x=" .. x, "y=" .. y, "z=" .. z)
            return false
        end
    end
    while _current_position.y ~= y do
        if _current_position.y < y then
            if not _up() then
                logger.error("Failed to move to x=" .. x, "y=" .. y, "z=" .. z)
                return false
            end
        elseif _current_position.y > y then
            if not _down() then
                logger.error("Failed to move to x=" .. x, "y=" .. y, "z=" .. z)
                return false
            end
        end
    end

    return true
end

return {
    turnLeft = _turnLeft,
    turnRight = _turnRight,
    turnAround = _turnAround,
    forward = _forward,
    up = _up,
    down = _down,
    face = _face,
    moveTo = _moveTo,
    current_position = _current_position,
    logger = logger,
}
