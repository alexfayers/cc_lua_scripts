local logging = require("afscript.core.logging")
local logger = logging.new("secret_door")


local function open()
    if turtle.getItemCount() >= 2 then
        logger.error("Door is already open.")
    end
    
    logger.info("Opening door...")
    turtle.turnRight()
    turtle.forward()
    turtle.turnLeft()
    turtle.dig()
    
    turtle.up()
    turtle.dig()
    
    turtle.turnLeft()
    turtle.forward()
    turtle.down()
    turtle.turnRight()
    
    logger.info("Door opened.")
end

local function close()
    if turtle.getItemCount() < 2 then
        logger.error("Door is already closed.")
    end
    
    logger.info("Closing door...")
    turtle.turnRight()
    turtle.forward()
    turtle.turnLeft()
    turtle.place()
    
    turtle.up()
    turtle.place()
    
    turtle.turnLeft()
    turtle.forward()
    turtle.down()
    turtle.turnRight()
    
    logger.info("Door closed.")
end

local function main()
    while true do
        local event = {os.pullEvent("computer_command")}
        if event[2] == "open" then
            open()
        elseif event[2] == "close" then
            close()
        end
    end
end
