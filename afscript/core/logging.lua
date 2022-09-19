-- Logging functions

-- imports

local strings = require("cc.strings")

-- constants

local LEVEL = {
    DEBUG = 0,
    INFO = 1,
    SUCCESS = 2,
    WARN = 3,
    ERROR = 4
}

local LEVEL_STRINGS = {
    [0] = "D",
    [1] = "I",
    [2] = "S",
    [3] = "W",
    [4] = "E"
}

local ALL_LOGGERS = {}

---Format a log message
---@param level number The log level
---@param msg string The message to log
---@return string _ The formatted log message
local function _format_log(level, msg)
    return "[" .. os.date("%H:%M:%S") .. "] " .. LEVEL_STRINGS[level] .. ": " .. msg
end

---Build a filename from a logger name
---@param logger_name string The name of the logger
---@return string _ The filename
local function _build_filename(logger_name)
    return "logs/" .. logger_name .. ".log"
end

---Write a line of text to the console in a specified color
---@param text string The text to write
---@param color number The color to write the text in
local function _write_line_color(text, color)
    term.setTextColor(color)
    term.write(text)
    term.setTextColor(colors.white)
end

---Write a long amount of text across multiple lines in a specified color
---@param text string The text to write
---@param color number The color to write the text in
local function _print_color(text, color)
    local x_size, y_size = term.getSize()
    local lines = strings.wrap(text, x_size)
    -- reset the cursor position
    term.setCursorPos(1, y_size)

    for i = 1, #lines do
        -- write the line
        _write_line_color(lines[i], color)

        -- reset the cursor position
        term.setCursorPos(1, y_size)

        -- scroll the terminal up
        term.scroll(1)
    end
end

---Log a message to the console and to a file (at debug level)
---@param msg string The message to log
---@param log_filename string The file to log to
local function _debug(level_variable, msg, log_filename)
    if level_variable <= LEVEL.DEBUG then
        msg = _format_log(LEVEL.DEBUG, msg)
        _print_color(msg, colors.gray)
        local file = fs.open(log_filename, "a")
        file.writeLine(msg)
        file.close()
    end
end

---Log a message to the console and to a file (at information level)
---@param msg string The message to log
---@param log_filename string The file to log to
local function _info(level_variable, msg, log_filename)
    if level_variable <= LEVEL.INFO then
        msg = _format_log(LEVEL.INFO, msg)
        _print_color(msg, colors.white)
        if log_filename ~= nil then
            local file = fs.open(log_filename, "a")
            file.writeLine(msg)
            file.close()
        end
    end
end


---Log a message to the console and to a file (at success level)
---@param msg string The message to log
---@param log_filename string The file to log to
local function _success(level_variable, msg, log_filename)
    if level_variable <= LEVEL.SUCCESS then
        msg = _format_log(LEVEL.SUCCESS, msg)
        _print_color(msg, colors.green)
        if log_filename ~= nil then
            local file = fs.open(log_filename, "a")
            file.writeLine(msg)
            file.close()
        end
    end
end


---Log a message to the console and to a file (at warning level)
---@param msg string The message to log
---@param log_filename string The file to log to
local function _warn(level_variable, msg, log_filename)
    if level_variable <= LEVEL.WARN then
        msg = _format_log(LEVEL.WARN, msg)
        _print_color(msg, colors.yellow)
        local file = fs.open(log_filename, "a")
        file.writeLine(msg)
        file.close()
    end
end

---Log a message to the console and to a file (at error level)
---@param msg string The message to log
---@param log_filename string The file to log to
local function _error(level_variable, msg, log_filename)
    if level_variable <= LEVEL.ERROR then
        msg = _format_log(LEVEL.ERROR, msg)
        _print_color(msg, colors.red)
        local file = fs.open(log_filename, "a")
        file.writeLine(msg)
        file.close()
    end
end


---Create a new logger, or return an existing one if it already exists
---@param logger_name string The name of the logger
---@param logger_level number|nil The level to log at, or nil to use the default level
---@return table _ The logger
local function _new(logger_name, logger_level)
    local log_filename = _build_filename(logger_name)
    local logger = {}

    if ALL_LOGGERS[logger_name] == nil then
        logger.level = logger_level or LEVEL.INFO

        --- Log a message at debug level
        ---@param msg string The message to log
        logger.debug = function(msg) _debug(logger.level, msg, log_filename) end

        --- Log a message at information level
        ---@param msg string The message to log
        logger.info = function(msg) _info(logger.level, msg, log_filename) end

        --- Log a message at success level
        ---@param msg string The message to log
        logger.success = function(msg) _success(logger.level, msg, log_filename) end

        --- Log a message at warning level
        ---@param msg string The message to log
        logger.warn = function(msg) _warn(logger.level, msg, log_filename) end

        --- Log a message at error level
        ---@param msg string The message to log
        logger.error = function(msg) _error(logger.level, msg, log_filename) end
        
        ALL_LOGGERS[logger_name] = logger
    else
        logger = ALL_LOGGERS[logger_name]
    end

    return logger
end

return {
    new = _new,
    print_color = _print_color,
    LEVEL = LEVEL
}
