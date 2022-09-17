-- Phone notification functions

local logging = require("afscript.core.logging")

local logger = logging.new("afscript.core.notify")


-- Define the phone notification settings
settings.define("afscript.notify.join_api_key", {
    description = "API key for join notifications",
    default=nil,
    type = "string"
})

settings.define("afscript.notify.join_device_id", {
    description = "Device ID for join notifications",
    default=nil,
    type = "string"
})


---Send a notification over http (using joinjoaomgcd Join)
---@param title string The title of the notification
---@param message string The message of the notification
---@return boolean _ True if the notification was sent, false otherwise
local function _join(title, message)
    assert(type(title) == "string", "title must be a string")
    assert(type(message) == "string", "message must be a string")

    local api_key = settings.get("afscript.notify.join_api_key")

    if api_key == nil then
        logger.warn("JOIN: No API key set!")
        return false
    end

    local device_id = settings.get("afscript.notify.join_device_id")

    if device_id == nil then
        logger.warn("JOIN: No device ID set!")
        return false
    end

    local res = http.get(
        "https://joinjoaomgcd.appspot.com/_ah/api/messaging/v1/sendPush?apikey=" .. textutils.urlEncode(api_key) ..
        "&deviceId=" .. textutils.urlEncode(device_id) ..
        "&title=" .. textutils.urlEncode(title) ..
        "&text=" .. textutils.urlEncode(message)
    )
    if res.getResponseCode() == 200 then
        logger.debug("JOIN: Sent notification: '" .. title .. "' - '" .. message .. "'")
        return true
    else
        logger.error("JOIN: Failed to send notification: '" .. title .. "' - '" .. message .. "'")
        return false
    end
end
 

return {
    join = _join,
    logger = logger,
}