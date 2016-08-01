package.path = package.path .. ";../?.lua"
local sock = require "sock"

describe('sock.lua core', function()
    it("should create clients", function()
        local client = sock.newClient()
        assert.are_not.equal(client, nil)

        assert.equal(client.address, "localhost")
        assert.equal(client.port, 22122)
        assert.equal(client.maxChannels, 1)
    end)

    it("should create clients on localhost", function()
        local client = sock.newClient("localhost")
        assert.truthy(client)

        local client = sock.newClient("localhost", 22122)
        assert.truthy(client)

        local client = sock.newClient("127.0.0.1")
        assert.truthy(client)

        local client = sock.newClient("127.0.0.1", 22122)
        assert.truthy(client)
    end)

    it("should create servers", function()
        local server = sock.newServer()
        assert.are_not.equal(server, nil)

        assert.equal(server.address, "localhost")
        assert.equal(server.port, 22122)
        assert.equal(server.maxPeers, 64)
        assert.equal(server.maxChannels, 1)
    end)
end)

describe("clients", function()
    it("should add callbacks", function()
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

    it("should remove callbacks", function()
        local client = sock.newClient()

        local helloCallback = function()
            print("hello")
        end

        local callback = client:on("helloMessage", helloCallback)

        assert.True(client:removeCallback(callback))
    end)

    it("should trigger callbacks", function()
        local client = sock.newClient()

        local handled = false
        local handleConnect = function()
            handled = true
        end

        client:on("connect", handleConnect)
        client:_activateTriggers("connect", "connection event test")

        assert.True(handled)
    end)
end)
