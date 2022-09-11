-- Logging functions

local LEVEL = {
    DEBUG = 0,
    INFO = 1,
    WARN = 2,
    ERROR = 3
}

local LEVEL_STRINGS = {
    [0] = "DEBUG",
    [1] = "INFO",
    [2] = "WARN",
    [3] = "ERROR"
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

---Log a message to the console and to a file (at debug level)
---@param msg string The message to log
---@param log_filename string The file to log to
local function _debug(level_variable, msg, log_filename)
    if level_variable <= LEVEL.DEBUG then
        msg = _format_log(LEVEL.DEBUG, msg)
        print(msg)
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
        print(_format_log(LEVEL.INFO, msg))
        if log_filename ~= nil then
            local file = fs.open(log_filename, "a")
            file.writeLine(_format_log(LEVEL.INFO, msg))
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
        print(msg)
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
        print(msg)
        local file = fs.open(log_filename, "a")
        file.writeLine(msg)
        file.close()
    end
end

---Set the current log level
---@param level_variable number The variable that contains the log level
---@param new_level number The log level to set
local function _setLevel(level_variable, new_level)
    print(level_variable)
    print(new_level)
    if new_level >= LEVEL.DEBUG and new_level <= LEVEL.ERROR then
        level_variable = new_level
    else
        error("Invalid log level: " .. new_level)
    end
end


---Create a new logger, or return an existing one if it already exists
---@param logger_name string The name of the logger
---@return table _ The logger
local function _new(logger_name)
    local log_filename = _build_filename(logger_name)
    local logger = {}

    if ALL_LOGGERS[logger_name] == nil then
        logger.level = LEVEL.INFO

        --- Log a message at debug level
        ---@param msg string The message to log
        logger.debug = function(msg) _debug(logger.level, msg, log_filename) end

        --- Log a message at information level
        ---@param msg string The message to log
        logger.info = function(msg) _info(logger.level, msg, log_filename) end

        --- Log a message at warning level
        ---@param msg string The message to log
        logger.warn = function(msg) _warn(logger.level, msg, log_filename) end

        --- Log a message at error level
        ---@param msg string The message to log
        logger.error = function(msg) _error(logger.level, msg, log_filename) end

        --- Set the current log level
        ---@param new_level number The log level to set
        logger.setLevel = function(new_level) _setLevel(logger.level, new_level) end
        
        ALL_LOGGERS[logger_name] = logger
    else
        logger = ALL_LOGGERS[logger_name]
    end

    return logger
end

return {
    new = _new,
    LEVEL = LEVEL
}
