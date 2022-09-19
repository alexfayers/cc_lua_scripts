--- Enable remote control of a computer via rednet

---imports

local logging = require("afscript.core.logging")
local logger = logging.new("remote")


---Initialise the remote control system by opening a rednet connection
---and hosting the protocol
---@param protocol_name string The name of the protocol to host
---@return boolean _ Whether the initialisation was successful or not
local function _initialize(protocol_name)
    local hostname = protocol_name .. "_" .. os.getComputerID()

    local modem = {
        peripheral.find(
        "modem",
        function(name, modem)
            if modem.isWireless() then
                rednet.open(name)

                rednet.host(protocol_name, hostname)
                return true
            end
        end
    )}
    
    if not modem then
        logger.error("No wireless modem found")
        error("No wireless modem found")
        return false
    end

    logger.success("Remote service initialised")
    return true
end


---Build a packet to send to the remote computer
---@param protocol string The protocol to the packet uses
---@param packet_type string The packet type
---@param data table The data to send
---@return string _ The generated packet
local function _build_packet(protocol, packet_type, data)
    return textutils.serialize({
        protocol = protocol,
        type = packet_type,
        data = data,
        sender = os.getComputerID()
    })
end


---Generate an "ok" response packet
---@param protocol string The protocol to the packet uses
---@param data any The data to send
---@return string _ The generated packet
local function _build_response_ok(protocol, data)
    return _build_packet(protocol, "response", {
        status = "ok",
        data = data,
    })
end


---Generate an "error" response packet
---@param protocol string The protocol to the packet uses
---@param message string The error message to send
---@return string _ The generated packet
local function _build_response_error(protocol, message)
    return _build_packet(protocol, "response", {
        status = "error",
        message = message,
    })
end


---Send a packet to a remote computer
---@param protocol string The protocol to the packet uses
---@param packet string The packet to send
---@param endpoint string|number The hostname (or id) of the computer to send the packet to
local function _send(protocol, packet, endpoint)
    local host_id
    if type(endpoint) == "string" then
        host_id = rednet.lookup(protocol, endpoint)
        if host_id == nil then
            logger.error("No computer found hosting '" .. protocol .. "' with a name of  '" .. endpoint .. "'")
            return
        end
    else
        host_id = endpoint
    end

    rednet.send(host_id, packet, protocol)
end


---Broadcast a packet to all remote computers
---@param protocol string The protocol to the packet uses
---@param packet string The packet to send
local function _broadcast(protocol, packet)
    rednet.broadcast(packet, protocol)
end


---Handle a packet received from a remote computer
---This is where you would add your own packet handlers
---@param raw_packet string The raw packet to process
---@param handlers table The handlers to use. This should be a table of functions, with the key being the packet type.
local function _handle_packet(raw_packet, handlers)
    local packet = textutils.unserialize(raw_packet)
    local data = packet.data

    logger.debug("Received " .. packet.type .. " packet from #" .. packet.sender)

    -- Run through user handlers
    if handlers[packet.type] then
        local success, response = handlers[packet.type](data)
        if success then
            _send(packet.protocol, _build_response_ok(packet.protocol, response), packet.sender)
        else
            _send(packet.protocol, _build_response_error(packet.protocol, response), packet.sender)
        end
    else
        logger.debug("No user handler for packet type '" .. packet.type .. "', checking default handlers")
    end

    -- Default handlers. These are used to handle the default packet types.
    -- You can override these by adding your own handlers if you want.
    if packet.type == "response" then
        if data.status == "ok" then
            logger.debug("Received ok response")
        elseif data.status == "error" then
            logger.debug("Received error response: " .. data.message)
        end
    else
        logger.error("No handler available for packet of type '" .. packet.type .. "'")
    end
end


---Validate the a packet received is from a trusted source
---@param source string The source of the packet
---@param allowlist table|nil The list of trusted sources
---@return boolean _ Whether the source is trusted or not
local function _validate_source(source, allowlist)
    if allowlist then
        for _, allowed_source in ipairs(allowlist) do
            if source == allowed_source then
                return true
            end
        end
        return false
    else
        return true
    end
end


---Listen for packets from remote computers
---@param protocol string The protocol to listen for
---@param allowlist table|nil The list of trusted sources
---@param timeout number|nil The timeout for the listen
---@return table|nil _ The received packet
local function _receive(protocol, allowlist, timeout)
    local sender_id, raw_packet, received_protocol = rednet.receive(protocol, timeout)

    -- check if the message is from an allowed source
    if not _validate_source(sender_id, allowlist) then
        logger.warn("Received message from unallowed source: " .. sender_id)
        return
    end

    if received_protocol ~= nil and received_protocol == protocol then
        return textutils.unserialize(raw_packet)
    end

    return nil
end


---Stop listening for packets from remote computers
local function _close(protocol_name)
    local hostname = protocol_name .. "_" .. os.getComputerID()

    rednet.unhost(protocol_name, hostname)
    rednet.close()
end


return {
    initialize = _initialize,
    close = _close,
    send = _send,
    broadcast = _broadcast,
    receive = _receive,
    handle_packet = _handle_packet,
    build_packet = _build_packet,
    build_response_ok = _build_response_ok,
    build_response_error = _build_response_error,
}
