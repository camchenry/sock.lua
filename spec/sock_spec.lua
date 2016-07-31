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
