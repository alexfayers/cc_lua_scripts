--- Enable remote control of a computer via rednet

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
    error("No wireless modem found")
end

function getCommand()
    while true do
        local event, sender, message, protocol = os.pullEvent("rednet_message")

        print(event, sender, message, protocol)

        if protocol ~= nil and protocol == PROTOCOL_NAME then
            print("Received message from " .. sender .. " with protocol " .. protocol .. " and message " .. tostring(message))
        else
            print("Received message from " .. sender .. " with message " .. tostring(message))
        end
    end
end


function sendCommand(command, target)
    rednet.send(target, command, PROTOCOL_NAME)
end
