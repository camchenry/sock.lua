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

local function isValidSendMode(mode)
    return mode == "reliable" or mode == "unsequenced" or mode == "unreliable"
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

    table.insert(self.triggers[event], {callback = callback})

    return callback
end

-- Removes a callback on a given trigger
-- Returns a boolean indicating if the callback was removed
function Listener:removeCallback(event, callback)
    if self.triggers[event] then
        for i, trigger in pairs(self.triggers[event]) do
            if trigger == callback then
                self.triggers[event][i] = nil
            end
        end
        return true
    else
        return false
    end
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
            trigger.callback(data, client)
        end
        return true
    else
        return false
    end
end

local Server = {}
local Server_mt = {__index = Server}

function Server:getClient(peer)
    for i, client in pairs(self.clients) do
        if peer == client.server then
            return client
        end
    end
end

function Server:getClientByConnectId(connectId)
    for i, client in pairs(self.clients) do
        if connectId == client.connectId then
            return client
        end
    end
end

function Server:setSendMode(mode)
    if not isValidSendMode(mode) then
        self:log("warning", "Tried to use invalid send mode: '" .. mode .. "'. Defaulting to reliable.")
        mode = "reliable"
    end

    self.sendMode = mode
end

function Server:setDefaultSendMode(mode)
    if not isValidSendMode(mode) then
        self:log("error", "Tried to set default send mode to invalid mode: '" .. mode .. "'")
        error("Tried to set default send mode to invalid mode: '" .. mode .. "'")
    end

    self.defaultSendMode = mode
end

function Server:setSendChannel(channel)
    if channel > (self.maxChannels - 1) then
        self:log("warning", "Tried to use invalid channel: " .. channel .. " (max is " .. self.maxChannels - 1 .. "). Defaulting to 0.")
        channel = 0
    end

    self.sendChannel = channel
end

function Server:setDefaultSendChannel(val)
   self.defaultSendChannel = val
end

function Server:resetSendSettings()
    self.sendMode = self.defaultSendMode
    self.sendChannel = self.defaultSendChannel
end

function Server:update(dt)
    local event = self.host:service(self.timeout)
    
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
            local name = message[1]
            local data = message[2]

            self:_activateTriggers(name, data, eventClient)
            self:log(event.type, message.data)

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

-- Useful for when the client does something locally, but other clients
-- need to be updated at the same time. This way avoids duplicating objects by
-- never sending its own event to itself in the first place.
function Server:emitToAllBut(peer, name, data)
    local message = {name, data}
    local serializedMessage = bitser.dumps(message)

    for i, p in pairs(self.peers) do
        if p ~= peer then
            self.packetsSent = self.packetsSent + 1
            p:send(serializedMessage, self.sendChannel, self.sendMode)
        end
    end

    self:resetSendSettings()
end

function Server:emitToAll(name, data)
    local message = {name, data}
    local serializedMessage = bitser.dumps(message)
    
    self.packetsSent = self.packetsSent + #self.peers

    self.host:broadcast(serializedMessage, self.sendChannel, self.sendMode)

    self:resetSendSettings()
end

function Server:on(name, callback)
    return self.listener:addCallback(name, callback)
end

function Server:setDataFormat(event, format)
    return self.listener:setDataFormat(event, format)
end

function Server:_activateTriggers(name, data, client)
    local result = self.listener:trigger(name, data, client)

    self.packetsReceived = self.packetsReceived + 1

    if not result then
        self:log("warning", "Tried to activate trigger: '" .. name .. "' but it does not exist.")
    end
end

function Server:removeCallbackOn(name, callback)
    self.listener:removeCallback(name, callback)    
end

-- Alias for Server.logger:log
function Server:log(event, data)
    return self.logger:log(event, data)
end

function Server:getTotalSentData()
    return self.host:total_sent_data()
end

function Server:getTotalReceivedData()
    return self.host:total_received_data()
end

function Server:setBandwidthLimit(incoming, outgoing)
    return self.host:bandwidth_limit(incoming, outgoing)
end

function Server:getLastServiceTime()
    return self.host:service_time()
end

local Client = {}
local Client_mt = {__index = Client}

function Client:setSendMode(mode)
    if not isValidSendMode(mode) then
        self:log("warning", "Tried to use invalid send mode: '" .. mode .. "'. Defaulting to reliable.")
        mode = "reliable"
    end

    self.sendMode = mode
end

function Client:setDefaultSendMode(mode)
    if not isValidSendMode(mode) then
        self:log("error", "Tried to set default send mode to invalid mode: '" .. mode .. "'")
        error("Tried to set default send mode to invalid mode: '" .. mode .. "'")
    end

    self.defaultSendMode = mode
end

function Client:setSendChannel(channel)
    if channel > (self.maxChannels - 1) then
        self:log("warning", "Tried to use invalid channel: " .. channel .. " (max is " .. self.maxChannels - 1 .. "). Defaulting to 0.")
        channel = 0
    end

    self.sendChannel = channel
end

function Client:setDefaultSendChannel(val)
    self.defaultSendChannel = val
end

function Client:resetSendSettings()
    self.sendMode = self.defaultSendMode
    self.sendChannel = self.defaultSendChannel
end

function Client:connect()
    -- number of channels for the client and server must match
    self.server = self.host:connect(self.address .. ":" .. self.port, self.maxChannels)
    self.connectId = self.server:connect_id()
end

function Client:disconnect(code)
    code = code or 0
    self.server:disconnect_later(code)
    if self.host then
        self.host:flush()
    end
end

function Client:update(dt)
    local event = self.host:service(self.timeout)
    
    while event do
        if event.type == "connect" then
            self:_activateTriggers("connect", event.data)
            self:log(event.type, "Connected to " .. tostring(self.server))
        elseif event.type == "receive" then
            local message = bitser.loads(event.data)
            local name = message[1]
            local data = message[2]

            self:_activateTriggers(name, data)
            self:log(event.type, message.data)

        elseif event.type == "disconnect" then
            self:_activateTriggers("disconnect", event.data)
            self:log(event.type, "Disconnected from " .. tostring(self.server))
        end

        event = self.host:service()
    end
end

function Client:emit(name, data)
    local message = {name, data}
    local serializedMessage = nil

    -- 'Data' = binary data class in Love
    if type(message.data) == "userdata" then
        serializedMessage = message.data
    else
        serializedMessage = bitser.dumps(message)
    end

    self.server:send(serializedMessage, self.sendChannel, self.sendMode)

    self.packetsSent = self.packetsSent + 1

    self:resetSendSettings()
end

function Client:on(name, callback)
    return self.listener:addCallback(name, callback)
end

function Client:setDataFormat(event, format)
    return self.listener:setDataFormat(event, format)
end

function Client:_activateTriggers(name, data)
    local result = self.listener:trigger(name, data, client)

    self.packetsReceived = self.packetsReceived + 1

    if not result then
        self:log("warning", "Tried to activate trigger: '" .. name .. "' but it does not exist.")
    end
end

function Client:removeCallbackOn(name, callback)
    return self.listener:removeCallback(name, callback)
end

function Client:log(event, data)
    return self.logger:log(event, data)
end

function Client:getTotalSentData()
    return self.host:total_sent_data()
end

function Client:getTotalReceivedData()
    return self.host:total_received_data()
end

function Client:setBandwidthLimit(incoming, outgoing)
    return self.host:bandwidth_limit(incoming, outgoing)
end

function Client:getLastServiceTime()
    return self.host:service_time()
end

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
        
        timeout         = 0,
        maxChannels     = maxChannels,
        maxPeers        = maxPeers,
        -- sendMode is one of "reliable", "unsequenced", or "unreliable". 
        -- Reliable packets are guaranteed to arrive, and arrive in the order 
        -- in which they are sent. Unsequenced packets are unreliable and 
        -- have no guarantee on the order they arrive.
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

sock.newClient = function(serverOrAddress, port, maxChannels)
    serverOrAddress = serverOrAddress or "localhost"
    port            = port or 22122
    maxChannels     = maxChannels or 1

    local client = setmetatable({
        address         = nil,
        port            = nil,
        host            = nil,

        server          = nil,
        connectId       = nil,

        timeout         = 0,
        maxChannels     = maxChannels,
        -- sendMode is one of "reliable", "unsequenced", or "unreliable". Reliable 
        -- packets are guaranteed to arrive, and arrive in the order in which they 
        -- are sent. Unsequenced packets are unreliable and have no guarantee on 
        -- the order they arrive.
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
        client.server = serverOrAddress
        client.connectId = client.server:connect_id()
    end

    return client
end

return sock
