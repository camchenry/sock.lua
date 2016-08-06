
--- A networking library for Lua games
-- @module sock
-- @usage local sock = require "sock"

local sock = {
    _VERSION     = 'sock.lua v0.1.0',
    _DESCRIPTION = 'A networking library for Lua games',
    _URL         = 'https://github.com/camchenry/sock.lua',
    _LICENSE     = [[
        MIT License

        Copyright (c) 2016 Cameron McHenry

        Permission is hereby granted, free of charge, to any person obtaining a copy
        of this software and associated documentation files (the "Software"), to deal
        in the Software without restriction, including without limitation the rights
        to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
        copies of the Software, and to permit persons to whom the Software is
        furnished to do so, subject to the following conditions:

        The above copyright notice and this permission notice shall be included in all
        copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
        IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
        FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
        AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
        LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
        OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
        SOFTWARE.
    ]]
}

local currentFolder = (...):match("(.-)[^%.]+$")
require "enet"
-- bitser is expected to be in the same directory as sock.lua
local bitser = require(currentFolder .. "bitser")

-- links variables to keys based on their order
-- note that it only works for boolean and number values, not strings
local function zipTable(items, keys)
    local data = {}

    -- convert variable at index 1 into the value for the key value at index 1, and so on
    for i, value in ipairs(items) do
        local key = keys[i]

        data[key] = value
    end

    return data
end

--- All of the possible connection statuses for a client connection.
-- @see Client:getState
local CONNECTION_STATES = {
    "disconnected",             -- Disconnected from the server.
    "connecting",               -- In the process of connecting to the server.
    "acknowledging_connect",    -- 
    "connection_pending",       --
    "connection_succeeded",     --
    "connected",                -- Successfully connected to the server.
    "disconnect_later",         -- Disconnecting, but only after sending all queued packets.
    "disconnecting",            -- In the process of disconnecting from the server.
    "acknowledging_disconnect", --
    "zombie",                   --
    "unknown",                  --
}

--- Valid modes for sending messages.
local SEND_MODES = {
    "reliable",     -- Message is guaranteed to arrive, and arrive in the order in which it is sent.
    "unsequenced",  -- Message has no guarantee on the order that it arrives.
    "unreliable",   -- Message is not guaranteed to arrive.
}

local function isValidSendMode(mode)
    for i, validMode in pairs(SEND_MODES) do
        if mode == validMode then
            return true
        end
    end
    return false
end

local Logger = {}
local Logger_mt = {__index = Logger}

function newLogger(source) 
    local logger = setmetatable({
        source          = source,
        messages        = {},
        
        -- Makes print info more concise, but should still log the full line
        shortenLines    = true,
        -- Print all incoming event data
        printEventData  = false,
        printErrors     = true,
        printWarnings   = true,
    }, Logger_mt)
    
    return logger
end

function Logger:log(event, data)
    local time = os.date("%X") -- something like 24:59:59
    local shortLine = ("[%s] %s"):format(event, data)
    local fullLine  = ("[%s][%s][%s] %s"):format(self.source, time, event, data)

    -- The printed message may or may not be the full message
    local line = fullLine
    if self.shortenLines then
        line = shortLine
    end

    if self.printEventData then
        print(line)
    elseif self.printErrors and event == "error" then
        print(line)
    elseif self.printWarnings and event == "warning" then
        print(line)
    end
    
    -- The logged message is always the full message
    table.insert(self.messages, fullLine)

    -- TODO: Dump to a log file
end

local Listener = {}
local Listener_mt = {__index = Listener}

function newListener()
    local listener = setmetatable({
        triggers        = {},                           
        formats         = {},
    }, Listener_mt)

    return listener
end

-- Adds a callback to a trigger
-- Returns: the callback function
function Listener:addCallback(event, callback)
    if not self.triggers[event] then
        self.triggers[event] = {}
    end

    table.insert(self.triggers[event], callback)

    return callback
end

-- Removes a callback on a given trigger
-- Returns a boolean indicating if the callback was removed
function Listener:removeCallback(callback)
    for event, triggers in pairs(self.triggers) do
        for i, trigger in pairs(triggers) do
            if trigger == callback then
                table.remove(triggers, i)
                return true
            end
        end
    end
    return false
end

-- Accepts: event (string), format (table)
-- Returns: nothing
function Listener:setDataFormat(event, format)
    self.formats[event] = format 
end

-- Activates all callbacks for a trigger
-- Returns a boolean indicating if any callbacks were triggered
function Listener:trigger(event, data, client)
    if self.triggers[event] then
        for i, trigger in pairs(self.triggers[event]) do
            -- Event has a pre-existing format defined
            if self.formats[event] then
                data = zipTable(data, self.formats[event])
            end
            trigger(data, client)
        end
        return true
    else
        return false
    end
end

--- Manages all clients and receives network events.
local Server = {}
local Server_mt = {__index = Server}

--- Gets the Client object associated with an enet peer.
-- @tparam peer peer An enet peer.
-- @treturn Client Object associated with the peer.
function Server:getClient(peer)
    for i, client in pairs(self.clients) do
        if peer == client.connection then
            return client
        end
    end
end

--- Gets the Client object that has the given connection id.
-- @tparam number connectId The unique client connection id.
-- @treturn Client
function Server:getClientByConnectId(connectId)
    for i, client in pairs(self.clients) do
        if connectId == client.connectId then
            return client
        end
    end
end

--- Get the Client object that has the given peer index.
-- @treturn Client
function Server:getClientByIndex(index)
    for i, client in pairs(self.clients) do
        if index == client:getIndex() then
            return client
        end
    end
end

--- Get the enet_peer that has the given index.
-- @treturn enet_peer The underlying enet peer object.
function Server:getPeerByIndex(index)
    return self.host:get_peer(index)
end

--- Set the send mode for the next outgoing message. 
-- The mode will be reset after the next message is sent. The initial default 
-- is "reliable".
-- @tparam string mode A valid send mode.
-- @see SEND_MODES
function Server:setSendMode(mode)
    if not isValidSendMode(mode) then
        self:log("warning", "Tried to use invalid send mode: '" .. mode .. "'. Defaulting to reliable.")
        mode = "reliable"
    end

    self.sendMode = mode
end

--- Set the default send mode for all future outgoing messages. 
-- The initial default is "reliable".
-- @tparam string mode A valid send mode.
-- @see SEND_MODES
function Server:setDefaultSendMode(mode)
    if not isValidSendMode(mode) then
        self:log("error", "Tried to set default send mode to invalid mode: '" .. mode .. "'")
        error("Tried to set default send mode to invalid mode: '" .. mode .. "'")
    end

    self.defaultSendMode = mode
end

--- Set the send channel for the next outgoing message. 
-- The channel will be reset after the next message. Channels are zero-indexed
-- and cannot exceed the maximum number of channels allocated. The initial 
-- default is 0.
-- @tparam number channel Channel to send data on.
function Server:setSendChannel(channel)
    if channel > (self.maxChannels - 1) then
        self:log("warning", "Tried to use invalid channel: " .. channel .. " (max is " .. self.maxChannels - 1 .. "). Defaulting to 0.")
        channel = 0
    end

    self.sendChannel = channel
end

--- Set the default send channel for all future outgoing messages.
-- The initial default is 0.
-- @tparam number channel Channel to send data on.
function Server:setDefaultSendChannel(channel)
   self.defaultSendChannel = channel
end

--- Reset all send options to their default values.
function Server:resetSendSettings()
    self.sendMode = self.defaultSendMode
    self.sendChannel = self.defaultSendChannel
end

--- Check for network events and handle them.
function Server:update()
    local event = self.host:service(self.messageTimeout)
    
    while event do
        if event.type == "connect" then
            local eventClient = sock.newClient(event.peer)
            table.insert(self.peers, event.peer)
            table.insert(self.clients, eventClient)
            self:_activateTriggers("connect", event.data, eventClient)
            self:log(event.type, tostring(event.peer) .. " connected")

        elseif event.type == "receive" then
            local message = bitser.loads(event.data)
            local eventClient = self:getClient(event.peer)
            local event = message[1]
            local data = message[2]

            self:_activateTriggers(event, data, eventClient)
            self:log(event, data)

        elseif event.type == "disconnect" then
            -- remove from the active peer list
            for i, peer in pairs(self.peers) do
                if peer == event.peer then
                    table.remove(self.peers, i)
                end
            end
            local eventClient = self:getClient(event.peer)
            for i, client in pairs(self.clients) do
                if client == eventClient then
                    table.remove(self.clients, i)
                end
            end
            self:_activateTriggers("disconnect", event.data, eventClient)
            self:log(event.type, tostring(event.peer) .. " disconnected")
        
        end

        event = self.host:service()
    end
end

--- Send a message to all peers, except one.
-- Useful for when the client does something locally, but other clients
-- need to be updated at the same time. This way avoids duplicating objects by
-- never sending its own event to itself in the first place.
-- @todo This function is bugged (I think.) It should accept clients, not peers.
-- @tparam enet_peer peer The peer to not receive the message.
-- @tparam string event The event to trigger with this message. 
-- @param data The data to send.
function Server:emitToAllBut(peer, event, data)
    local message = {event, data}
    local serializedMessage = nil

    -- 'Data' = binary data class in Love
    if type(data) == "userdata" and data.type and data:typeOf("Data") then
        message[2] = data:getString()
        serializedMessage = bitser.dumps(message)
    else
        serializedMessage = bitser.dumps(message)
    end

    for i, p in pairs(self.peers) do
        if p ~= peer then
            self.packetsSent = self.packetsSent + 1
            p:send(serializedMessage, self.sendChannel, self.sendMode)
        end
    end

    self:resetSendSettings()
end

--- Send a message to all peers.
-- @tparam string event The event to trigger with this message.
-- @param data The data to send.
function Server:emitToAll(event, data)
    local message = {event, data}
    local serializedMessage = nil

    -- 'Data' = binary data class in Love
    if type(data) == "userdata" and data.type and data:typeOf("Data") then
        message[2] = data:getString()
        serializedMessage = bitser.dumps(message)
    else
        serializedMessage = bitser.dumps(message)
    end
    
    self.packetsSent = self.packetsSent + #self.peers

    self.host:broadcast(serializedMessage, self.sendChannel, self.sendMode)

    self:resetSendSettings()
end

--- Add a callback to an event.
-- @tparam string event The event that will trigger the callback.
-- @tparam function callback The callback to be triggered.
-- @treturn function The callback that was passed in.
--@usage
--server:on("connect", function(data, client)
--    print("Client connected!")
--end)
function Server:on(event, callback)
    return self.listener:addCallback(event, callback)
end

--- Set the data format for an event.
-- @tparam string event The event to set the data format for. 
-- @tparam table format The data format.
function Server:setDataFormat(event, format)
    return self.listener:setDataFormat(event, format)
end

function Server:_activateTriggers(event, data, client)
    local result = self.listener:trigger(event, data, client)

    self.packetsReceived = self.packetsReceived + 1

    if not result then
        self:log("warning", "Tried to activate trigger: '" .. tostring(event) .. "' but it does not exist.")
    end
end

--- Remove a specific callback for an event.
-- @tparam function callback The callback to remove.
-- @treturn boolean Whether or not the callback was removed.
--@usage
--local callback = server:on("chatMessage", function(message)
--    print(message)
--end)
--server:removeCallback(callback)
function Server:removeCallback(callback)
    return self.listener:removeCallback(callback)    
end

--- Log an event.
-- Alias for Server.logger:log.
-- @tparam string event The type of event that happened.
-- @tparam string data The message to log.
--@usage
--if somethingBadHappened then
--    server:log("error", "Something bad happened!")
--end
function Server:log(event, data)
    return self.logger:log(event, data)
end

--- Get the total sent data since the server was created.
-- @treturn number The total sent data in bytes.
function Server:getTotalSentData()
    return self.host:total_sent_data()
end

--- Get the total received data since the server was created.
-- @treturn number The total received data in bytes.
function Server:getTotalReceivedData()
    return self.host:total_received_data()
end
--- Get the total number of packets (messages) sent since the server was created.
-- Everytime a message is sent or received, the corresponding figure is incremented.
-- Therefore, this is not necessarily an accurate indicator of how many packets were actually
-- exchanged over the network.
-- @treturn number The total number of sent packets.
function Server:getTotalSentPackets()
    return self.packetsSent
end

--- Get the total number of packets (messages) received since the server was created.
-- @treturn number The total number of received packets.
-- @see Server:getTotalSentPackets
function Server:getTotalReceivedPackets()
    return self.packetsReceived
end

--- Set the incoming and outgoing bandwidth limits.
-- @tparam number incoming The maximum incoming bandwidth in bytes.
-- @tparam number outgoing The maximum outgoing bandwidth in bytes.
function Server:setBandwidthLimit(incoming, outgoing)
    return self.host:bandwidth_limit(incoming, outgoing)
end

--- Get the last time when network events were serviced.
-- @treturn number Timestamp of the last time events were serviced.
function Server:getLastServiceTime()
    return self.host:service_time()
end

--- Get the number of allocated slots for peers.
-- @treturn number Number of allocated slots.
function Server:getMaxPeers()
    return self.maxPeers 
end

--- Get the number of allocated channels.
-- Channels are zero-indexed, e.g. 16 channels allocated means that the
-- maximum channel that can be used is 15.
-- @treturn number Number of allocated channels.
function Server:getMaxChannels()
    return self.maxChannels 
end

--- Set the maximum number of channels.
-- @tparam number limit The maximum number of channels allowed. If it is 0,
-- then the maximum number of channels available on the system will be used.
function Server:setMaxChannels(limit)
    self.host:channel_limit(limit)
end

--- Set the timeout to wait for packets.
-- @tparam number timeout Time to wait for incoming packets in milliseconds. The 
-- initial default is 0.
function Server:setMessageTimeout(timeout)
    self.messageTimeout = timeout
end

--- Get the timeout for packets.
-- @treturn number Time to wait for incoming packets in milliseconds.
-- initial default is 0.
function Server:getMessageTimeout()
    return self.messageTimeout
end

--- Get the socket address of the host.
-- @treturn string A description of the socket address, in the format 
-- "A.B.C.D:port" where A.B.C.D is the IP address of the used socket.
function Server:getSocketAddress()
    return self.host:get_socket_address()
end


--- Connects to servers.
local Client = {}
local Client_mt = {__index = Client}

--- Set the send mode for the next outgoing message. 
-- The mode will be reset after the next message is sent. The initial default 
-- is "reliable".
-- @tparam string mode A valid send mode.
-- @see SEND_MODES
function Client:setSendMode(mode)
    if not isValidSendMode(mode) then
        self:log("warning", "Tried to use invalid send mode: '" .. mode .. "'. Defaulting to reliable.")
        mode = "reliable"
    end

    self.sendMode = mode
end

--- Set the default send mode for all future outgoing messages. 
-- The initial default is "reliable".
-- @tparam string mode A valid send mode.
-- @see SEND_MODES
function Client:setDefaultSendMode(mode)
    if not isValidSendMode(mode) then
        self:log("error", "Tried to set default send mode to invalid mode: '" .. mode .. "'")
        error("Tried to set default send mode to invalid mode: '" .. mode .. "'")
    end

    self.defaultSendMode = mode
end

--- Set the send channel for the next outgoing message. 
-- The channel will be reset after the next message. Channels are zero-indexed
-- and cannot exceed the maximum number of channels allocated. The initial 
-- default is 0.
-- @tparam number channel Channel to send data on.
function Client:setSendChannel(channel)
    if channel > (self.maxChannels - 1) then
        self:log("warning", "Tried to use invalid channel: " .. channel .. " (max is " .. self.maxChannels - 1 .. "). Defaulting to 0.")
        channel = 0
    end

    self.sendChannel = channel
end

--- Set the default send channel for all future outgoing messages.
-- The initial default is 0.
-- @tparam number channel Channel to send data on.
function Client:setDefaultSendChannel(channel)
    self.defaultSendChannel = channel
end

--- Reset all send options to their default values.
function Client:resetSendSettings()
    self.sendMode = self.defaultSendMode
    self.sendChannel = self.defaultSendChannel
end

--- Connect to the chosen server.
-- @treturn boolean Status indicating whether or not the connection was successful.
-- @todo Actually return the status.
function Client:connect()
    -- number of channels for the client and server must match
    self.connection = self.host:connect(self.address .. ":" .. self.port, self.maxChannels)
    self.connectId = self.connection:connect_id()

    return true
end

--- Disconnect from the server, if connected. The client will disconnect the 
-- next time that network messages are sent.
-- @tparam ?number code A code to associate with this disconnect event.
-- @todo Pass the code into the disconnect callback on the server
function Client:disconnect(code)
    code = code or 0
    self.connection:disconnect(code)
end

--- Disconnect from the server, if connected. The client will disconnect after
-- sending all queued packets.
-- @tparam ?number code A code to associate with this disconnect event.
-- @todo Pass the code into the disconnect callback on the server
function Client:disconnectLater(code)
    code = code or 0
    self.connection:disconnect_later(code)
end

--- Disconnect from the server, if connected. The client will disconnect immediately.
-- @tparam ?number code A code to associate with this disconnect event.
-- @todo Pass the code into the disconnect callback on the server
function Client:disconnectNow(code)
    code = code or 0
    self.connection:disconnect_now(code)
end

--- Check for network events and handle them.
function Client:update()
    local event = self.host:service(self.messageTimeout)
    
    while event do
        if event.type == "connect" then
            self:_activateTriggers("connect", event.data)
            self:log(event.type, "Connected to " .. tostring(self.connection))
        elseif event.type == "receive" then
            local message = bitser.loads(event.data)
            local event = message[1]
            local data = message[2]

            self:_activateTriggers(event, data)
            self:log(event, data)

        elseif event.type == "disconnect" then
            self:_activateTriggers("disconnect", event.data)
            self:log(event.type, "Disconnected from " .. tostring(self.connection))
        end

        event = self.host:service()
    end
end

--- Send a message to the server.
-- @tparam string event The event to trigger with this message.
-- @param data The data to send.
function Client:emit(event, data)
    local message = {event, data}
    local serializedMessage = nil

    -- 'Data' = binary data class in Love
    if type(data) == "userdata" and data.type and data:typeOf("Data") then
        message[2] = data:getString()
        serializedMessage = bitser.dumps(message)
    else
        serializedMessage = bitser.dumps(message)
    end

    self.connection:send(serializedMessage, self.sendChannel, self.sendMode)

    self.packetsSent = self.packetsSent + 1

    self:resetSendSettings()
end

--- Add a callback to an event.
-- @tparam string event The event that will trigger the callback.
-- @tparam function callback The callback to be triggered.
-- @treturn function The callback that was passed in.
--@usage
--client:on("connect", function(data)
--    print("Connected to the server!")
--end)
function Client:on(event, callback)
    return self.listener:addCallback(event, callback)
end

--- Set the data format for an event.
-- @tparam string event The event to set the data format for. 
-- @tparam table format The data format.
function Client:setDataFormat(event, format)
    return self.listener:setDataFormat(event, format)
end

function Client:_activateTriggers(event, data)
    local result = self.listener:trigger(event, data, client)

    self.packetsReceived = self.packetsReceived + 1

    if not result then
        self:log("warning", "Tried to activate trigger: '" .. tostring(event) .. "' but it does not exist.")
    end
end

--- Remove a specific callback for an event.
-- @tparam function callback The callback to remove.
-- @treturn boolean Whether or not the callback was removed.
--@usage
--local callback = client:on("chatMessage", function(message)
--    print(message)
--end)
--client:removeCallback(callback)
function Client:removeCallback(callback)
    return self.listener:removeCallback(callback)
end

--- Log an event.
-- Alias for Client.logger:log.
-- @tparam string event The type of event that happened.
-- @tparam string data The message to log.
--@usage
--if somethingBadHappened then
--    client:log("error", "Something bad happened!")
--end
function Client:log(event, data)
    return self.logger:log(event, data)
end

--- Get the total sent data since the server was created.
-- @treturn number The total sent data in bytes.
function Client:getTotalSentData()
    return self.host:total_sent_data()
end

--- Get the total received data since the server was created.
-- @treturn number The total received data in bytes.
function Client:getTotalReceivedData()
    return self.host:total_received_data()
end

--- Get the total number of packets (messages) sent since the client was created.
-- Everytime a message is sent or received, the corresponding figure is incremented.
-- Therefore, this is not necessarily an accurate indicator of how many packets were actually
-- exchanged over the network.
-- @treturn number The total number of sent packets.
function Client:getTotalSentPackets()
    return self.packetsSent
end

--- Get the total number of packets (messages) received since the client was created.
-- @treturn number The total number of received packets.
-- @see Client:getTotalSentPackets
function Client:getTotalReceivedPackets()
    return self.packetsReceived
end

--- Set the incoming and outgoing bandwidth limits.
-- @tparam number incoming The maximum incoming bandwidth in bytes.
-- @tparam number outgoing The maximum outgoing bandwidth in bytes.
function Client:setBandwidthLimit(incoming, outgoing)
    return self.host:bandwidth_limit(incoming, outgoing)
end

--- Get the last time when network events were serviced.
-- @treturn number Timestamp of the last time events were serviced.
function Client:getLastServiceTime()
    return self.host:service_time()
end

--- Get the number of allocated channels.
-- Channels are zero-indexed, e.g. 16 channels allocated means that the
-- maximum channel that can be used is 15.
-- @treturn number Number of allocated channels.
function Client:getMaxChannels()
    return self.maxChannels 
end

--- Set the maximum number of channels.
-- @tparam number limit The maximum number of channels allowed. If it is 0,
-- then the maximum number of channels available on the system will be used.
function Client:setMaxChannels(limit)
    self.host:channel_limit(limit)
end

--- Set the timeout to wait for packets.
-- @tparam number timeout Time to wait for incoming packets in milliseconds. The initial
-- default is 0.
function Client:setMessageTimeout(timeout)
    self.messageTimeout = timeout
end

--- Get the timeout for packets.
-- @treturn number Time to wait for incoming packets in milliseconds.
-- initial default is 0.
function Client:getMessageTimeout()
    return self.messageTimeout
end

--- Return the round trip time (RTT, or ping) to the server, if connected.
-- It can take a few seconds for the time to approach an accurate value.
-- @treturn number The round trip time.
function Client:getRoundTripTime()
    if self.connection then
        return self.connection:round_trip_time()
    end
end

--- Set how frequently to ping the server.
-- The round trip time is updated each time a ping is sent. The initial
-- default is 500ms.
-- @tparam number interval The interval, in milliseconds.
function Client:setPingInterval(interval)
    if self.connection then
        self.connection:ping_interval(interval)
    end
end

--- Get the unique connection id, if connected.
-- @treturn number The connection id.
function Client:getConnectId()
    if self.connection then
        return self.connection:connect_id()
    end
end

--- Get the current connection state, if connected.
-- @treturn string The connection state.
-- @see CONNECTION_STATES
function Client:getState()
    if self.connection then
        return self.connection:state()
    end
end

--- Get the index of the enet peer. All peers of an ENet host are kept in an array. This function finds and returns the index of the peer of its host structure. 
-- @treturn number The index of the peer.
function Client:getIndex()
    if self.connection then
        return self.connection:index()
    end
end

--- Change the probability at which unreliable packets should not be dropped.
-- @tparam number interval Interval, in milliseconds, over which to measure lowest mean RTT. (default: 5000ms)
-- @tparam number acceleration Rate at which to increase the throttle probability as mean RTT declines. (default: 2)
-- @tparam number deceleration Rate at which to decrease the throttle probability as mean RTT increases.
function Client:setThrottle(interval, acceleration, deceleration)
    interval = interval or 5000
    acceleration = acceleration or 2
    deceleration = deceleration or 2
    if self.connection then
        self.connection:throttle_configure(interval, acceleration, deceleration)
    end
end

--- Set the parameters for attempting to reconnect if a timeout is detected.
-- @tparam ?number limit A factor that is multiplied with a value that based on the average round trip time to compute the timeout limit. (default: 32)
-- @tparam ?number minimum Timeout value in milliseconds that a reliable packet has to be acknowledged if the variable timeout limit was exceeded. (default: 5000)
-- @tparam ?number maximum Fixed timeout in milliseconds for which any packet has to be acknowledged.
function Client:setTimeout(limit, minimum, maximum)
    limit = limit or 32
    minimum = minimum or 5000
    maximum = maximum or 30000
    if self.connection then
        self.connection:timeout(limit, minimum, maximum)
    end
end

--- Get the socket address of the host.
-- @treturn string A description of the socket address, in the format "A.B.C.D:port" where A.B.C.D is the IP address of the used socket.
function Client:getSocketAddress()
    return self.host:get_socket_address()
end

--- Get the enet_peer that has the given index.
-- @treturn enet_peer The underlying enet peer object.
function Client:getPeerByIndex(index)
    return self.host:get_peer(index)
end

--- Creates a new Server object.
-- @tparam ?string address Hostname or IP address to bind to. (default: "localhost")
-- @tparam ?number port Port to listen to for data. (default: 22122) 
-- @tparam ?number maxPeers Maximum peers that can connect to the server. (default: 64)
-- @tparam ?number maxChannels Maximum channels available to send and receive data. (default: 1)
-- @tparam ?number inBandwidth Maximum incoming bandwidth (default: 0)
-- @tparam ?number outBandwidth Maximum outgoing bandwidth (default: 0)
-- @return A new Server object.
-- @see Server
-- @usage 
--local sock = require "sock"
--
-- -- Local server hosted on localhost:22122 (by default)
--server = sock.newServer()
--
-- -- Local server only, on port 1234
--server = sock.newServer("localhost", 1234)
--
-- -- Server hosted on static IP 123.45.67.89, on port 22122
--server = sock.newServer("123.45.67.89", 22122)
--
-- -- Server hosted on any IP, on port 22122
--server = sock.newServer("*", 22122)
--
-- -- Limit peers to 10, channels to 2
--server = sock.newServer("*", 22122, 10, 2)
--
-- -- Limit incoming/outgoing bandwidth to 1kB/s (1000 bytes/s)
--server = sock.newServer("*", 22122, 10, 2, 1000, 1000)
sock.newServer = function(address, port, maxPeers, maxChannels, inBandwidth, outBandwidth)
    address         = address or "localhost" 
    port            = port or 22122
    maxPeers        = maxPeers or 64
    maxChannels     = maxChannels or 1
    inBandwidth     = inBandwidth or 0
    outBandwidth    = outBandwidth or 0

    local server = setmetatable({
        address         = address,
        port            = port,
        host            = nil,
        
        messageTimeout  = 0,
        maxChannels     = maxChannels,
        maxPeers        = maxPeers,
        sendMode        = "reliable",
        defaultSendMode = "reliable",
        sendChannel     = 0,
        defaultSendChannel = 0,

        peers           = {},
        clients         = {}, 

        listener        = newListener(),
        logger          = newLogger("SERVER"),

        packetsSent     = 0,
        packetsReceived = 0,
    }, Server_mt)

    -- ip, max peers, max channels, in bandwidth, out bandwidth
    -- number of channels for the client and server must match
    server.host = enet.host_create(server.address .. ":" .. server.port, server.maxPeers, server.maxChannels)

    if not server.host then
        error("Failed to create the host. Is there another server running on :"..server.port.."?")
    end

    server:setBandwidthLimit(inBandwidth, outBandwidth)

    return server
end

--- Creates a new Client instance.
-- @tparam ?string/peer serverOrAddress Usually the IP address or hostname to connect to. It can also be an enet peer. (default: "localhost")
-- @tparam ?number port port number of the server to connect to. (default: 22122)
-- @tparam ?number maxChannels maximum channels available to send and receive data. (default: 1)
-- @return A new Client object.
-- @see Client
-- @usage
--local sock = require "sock"
--
-- -- Client that will connect to localhost:22122 (by default)
--client = sock.newClient()
--
-- -- Client that will connect to localhost:1234
--client = sock.newClient("localhost", 1234)
--
-- -- Client that will connect to 123.45.67.89:1234, using two channels
-- -- NOTE: Server must also allocate two channels!
--client = sock.newClient("123.45.67.89", 1234, 2)
sock.newClient = function(serverOrAddress, port, maxChannels)
    serverOrAddress = serverOrAddress or "localhost"
    port            = port or 22122
    maxChannels     = maxChannels or 1

    local client = setmetatable({
        address         = nil,
        port            = nil,
        host            = nil,

        connection      = nil,
        connectId       = nil,

        messageTimeout  = 0,
        maxChannels     = maxChannels,
        sendMode        = "reliable",
        defaultSendMode = "reliable",
        sendChannel     = 0,
        defaultSendChannel = 0,

        listener        = newListener(),
        logger          = newLogger("CLIENT"),

        packetsReceived = 0,
        packetsSent     = 0,
    }, Client_mt)
    
    -- Two different forms for client creation:
    -- 1. Pass in (address, port) and connect to that.
    -- 2. Pass in (enet peer) and set that as the existing connection.
    -- The first would be the common usage for regular client code, while the
    -- latter is mostly used for creating clients in the server-side code.

    -- First form: (address, port)
    if port ~= nil and type(port) == "number" and serverOrAddress ~= nil and type(serverOrAddress) == "string" then
        client.address = serverOrAddress 
        client.port = port
        client.host = enet.host_create()

    -- Second form: (enet peer)
    elseif type(serverOrAddress) == "userdata" then
        client.connection = serverOrAddress
        client.connectId = client.connection:connect_id()
    end

    return client
end

return sock
