package.path = package.path .. ";../?.lua"
local bitser = require "spec.bitser"
-- this is a hack :)
package.loaded['bitser'] = bitser
local sock = require "sock"

describe('sock.lua core', function()
    it("creates clients", function()
        local client = sock.newClient()
        assert.are_not.equal(client, nil)

        assert.equal(client.address, "localhost")
        assert.equal(client.port, 22122)
        assert.equal(client.maxChannels, 1)
    end)

    it("creates clients on localhost", function()
        local client = sock.newClient("localhost")
        assert.truthy(client)

        local client = sock.newClient("localhost", 22122)
        assert.truthy(client)

        local client = sock.newClient("127.0.0.1")
        assert.truthy(client)

        local client = sock.newClient("127.0.0.1", 22122)
        assert.truthy(client)
    end)

    it("creates servers", function()
        local server = sock.newServer()
        assert.are_not.equal(server, nil)

        assert.equal(server.address, "localhost")
        assert.equal(server.port, 22122)
        assert.equal(server.maxPeers, 64)
        assert.equal(server.maxChannels, 1)

        server:destroy()
    end)
end)

describe("the client", function()
    it("connects to a server", function()
        local client = sock.newClient("localhost", 22122)
        local server = sock.newServer("0.0.0.0", 22122)

        local connected = false
        client:on("connect", function(data)
            connected = true 
        end)

        client:connect()

        client:update()
        server:update()
        client:update()

        assert.True(client:isConnected())
        assert.True(connected)

        server:destroy()
    end)

    it("adds callbacks", function()
        local client = sock.newClient()

        local helloCallback = function()
            print("hello")
        end

        local callback = client:on("helloMessage", helloCallback)
        assert.equal(helloCallback, callback)
        
        local found = false
        for i, callbacks in pairs(client.listener.triggers) do
            for j, callback in pairs(callbacks) do
                if callback == helloCallback then
                    found = true
                end
            end
        end
        assert.True(found)
    end)

    it("removes callbacks", function()
        local client = sock.newClient()

        local helloCallback = function()
            print("hello")
        end

        local callback = client:on("helloMessage", helloCallback)

        assert.True(client:removeCallback(callback))
    end)

    it("does not remove non-existent callbacks", function()
        local client = sock.newClient()

        local nonsense = function() end

        assert.False(client:removeCallback(nonsense))
    end)

    it("triggers callbacks", function()
        local client = sock.newClient()

        local handled = false
        local handleConnect = function()
            handled = true
        end

        client:on("connect", handleConnect)
        client:_activateTriggers("connect", "connection event test")

        assert.True(handled)
    end)

    it("sets send channel", function()
        local client = sock.newClient(nil, nil, 8)

        client:setSendChannel(7)
        assert.equal(client.sendChannel, 7)
    end)
end)
