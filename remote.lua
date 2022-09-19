--- Enable remote control of a computer via rednet

---imports

local logging = require("afscript.core.logging")
local logger = logging.logger("remote")

---Config

-- A list of computers that are allowed to control this computer
local allowed_sources = {
    10,
}

local PROTOCOL_NAME = "remote"

-- setup globals

-- get the wireless modem
local modem = {
    peripheral.find(
    "modem",
    function(name, modem)
        if modem.isWireless() then
            rednet.open(name)
            return true
        end
    end
)}

if not modem then
    logger.error("No wireless modem found")
    error("No wireless modem found")
end

function buildPacket(command, args)
    return textutils.serialize({
        type = command,
        args = args,
    })
end

function handlePacket(packet)
    local data = textutils.unserialize(packet)
    local args = data.args
    if data.type == "run" then
        local result = shell.run(args.command)
        if not result then
            logger.error("Error running command")
        else
            logger.success("Command ran successfully")
        end
    end
end

function getCommand()
    while true do
        local _, sender, packet, protocol = os.pullEvent("rednet_message")

        -- check if the message is from an allowed source

        local allowed = false
        for _, id in ipairs(allowed_sources) do
            if id == sender then
                allowed = true
                break
            end
        end

        if not allowed then
            logger.warn("Received message from unallowed source: " .. sender)
            return
        end

        if protocol ~= nil and protocol == PROTOCOL_NAME then
            logger.info("Received message from " .. sender ": " .. tostring(command))
            
            handlePacket(packet)
        end
    end
end


function sendCommand(command, target)
    local payload = buildPacket(
        "run",
        {
            command = command,
        }
    )

    rednet.send(target, payload, PROTOCOL_NAME)
end
