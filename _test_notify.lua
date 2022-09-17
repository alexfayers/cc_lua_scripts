--- Send a test notification using Join

local notify = require("afscript.core.notify")
local logging = require("afscript.core.logging")

notify.logger.level = logging.LEVEL.DEBUG

notify.join("Test", "This is a test notification")
