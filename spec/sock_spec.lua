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
        server:update()

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

    it('can send a message with a schema', function()
        local client = sock.newClient("localhost", 22122)
        local server = sock.newServer("0.0.0.0", 22122)

        client:connect()

        client:update()
        server:update()
        client:update()

        local received = false

        server:setSchema('test', {
            'first',
            'second',
            'third',
        })
        client:setSchema('test', {
            'first',
            'second',
            'third',
        })
        server:on('test', function(data, client)
            assert.are.same(data, {
                first = 'this is the first message',
                second = 'this is the second message',
                third = 'this is the third message',
            })
            received = true
        end)

        client:send('test', {
            'this is the first message',
            'this is the second message',
            'this is the third message',
        })
        client:update()
        server:update()

        assert.True(received)

        server:destroy()
    end)

    insulate('can send', function()
        before_each(function()
            _G.client = sock.newClient("localhost", 22122)
            _G.server = sock.newServer("0.0.0.0", 22122)

            client:connect()

            client:update()
            server:update()
            client:update()
        end)

        after_each(function()
            server:destroy()
        end)

        it('a string', function()
            local received = false

            server:on('test', function(data, client)
                assert.equal(data, 'this is the test string')
                received = true
            end)

            client:send('test', 'this is the test string')
            client:update()
            server:update()

            assert.True(received)
        end)

        it('an integer', function()
            local received = false

            server:on('test', function(data, client)
                assert.equal(data, 12345678)
                received = true
            end)

            client:send('test', 12345678)
            client:update()
            server:update()

            assert.True(received)
        end)

        it('a floating point number', function()
            local received = false

            server:on('test', function(data, client)
                assert.equal(data, 0.123456789)
                received = true
            end)

            client:send('test', 0.123456789)
            client:update()
            server:update()

            assert.True(received)
        end)

        it('a huge number', function()
            local received = false

            server:on('test', function(data, client)
                assert.equal(data, math.huge)
                received = true
            end)

            client:send('test', math.huge)
            client:update()
            server:update()

            assert.True(received)
        end)

        it('a negative huge number', function()
            local received = false

            server:on('test', function(data, client)
                assert.equal(data, -math.huge)
                received = true
            end)

            client:send('test', -math.huge)
            client:update()
            server:update()

            assert.True(received)
        end)

        it('a boolean', function()
            local received = false

            server:on('test', function(data, client)
                assert.equal(data, false)
                received = true
            end)

            client:send('test', false)
            client:update()
            server:update()

            assert.True(received)
        end)

        it('nil', function()
            local received = false

            server:on('test', function(data, client)
                assert.equal(data, nil)
                received = true
            end)

            client:send('test', nil)
            client:update()
            server:update()

            assert.True(received)
        end)

        it('a table', function()
            local received = false

            server:on('test', function(data, client)
                assert.are.same(data, {
                    a = 0.12,
                    b = -987345,
                    c = "test",
                    d = true,
                    e = {},
                })
                received = true
            end)

            client:send('test', {
                a = 0.12,
                b = -987345,
                c = "test",
                d = true,
                e = {},
            })
            client:update()
            server:update()

            assert.True(received)
        end)

        it('a table array', function()
            local received = false

            server:on('test', function(data, client)
                assert.are.same(data, {
                    0.12,
                    -987345,
                    "test",
                    true,
                    {},
                })
                received = true
            end)

            client:send('test', {
                0.12,
                -987345,
                "test",
                true,
                {},
            })
            client:update()
            server:update()

            assert.True(received)
        end)
    end)
end)

describe('the server', function()
    insulate('can send', function()
        before_each(function()
            _G.client = sock.newClient("localhost", 22122)
            _G.server = sock.newServer("0.0.0.0", 22122)

            client:connect()

            client:update()
            server:update()
            client:update()
            server:update()
        end)

        after_each(function()
            server:destroy()
        end)

        it('a string', function()
            local received = false

            client:on('test', function(data, client)
                assert.equal(data, 'this is the test string')
                received = true
            end)

            server:sendToAll('test', 'this is the test string')
            server:update()
            client:update()
            server:update()
            client:update()

            assert.True(received)
        end)

        it('an integer', function()
            local received = false

            client:on('test', function(data, client)
                assert.equal(data, 12345678)
                received = true
            end)

            server:sendToAll('test', 12345678)
            client:update()
            server:update()
            client:update()
            server:update()

            assert.True(received)
        end)

        it('a floating point number', function()
            local received = false

            client:on('test', function(data, client)
                assert.equal(data, 0.123456789)
                received = true
            end)

            server:sendToAll('test', 0.123456789)
            server:update()
            client:update()
            server:update()
            client:update()

            assert.True(received)
        end)

        it('a huge number', function()
            local received = false

            client:on('test', function(data, client)
                assert.equal(data, math.huge)
                received = true
            end)

            server:sendToAll('test', math.huge)
            server:update()
            client:update()
            server:update()
            client:update()

            assert.True(received)
        end)

        it('a negative huge number', function()
            local received = false

            client:on('test', function(data, client)
                assert.equal(data, -math.huge)
                received = true
            end)

            server:sendToAll('test', -math.huge)
            server:update()
            client:update()
            server:update()
            client:update()

            assert.True(received)
        end)

        it('a boolean', function()
            local received = false

            client:on('test', function(data, client)
                assert.equal(data, false)
                received = true
            end)

            server:sendToAll('test', false)
            server:update()
            client:update()
            server:update()
            client:update()

            assert.True(received)
        end)

        it('nil', function()
            local received = false

            client:on('test', function(data, client)
                assert.equal(data, nil)
                received = true
            end)

            server:sendToAll('test', nil)
            server:update()
            client:update()
            server:update()
            client:update()

            assert.True(received)
        end)

        it('a table', function()
            local received = false

            client:on('test', function(data, client)
                assert.are.same(data, {
                    a = 0.12,
                    b = -987345,
                    c = "test",
                    d = true,
                    e = {},
                })
                received = true
            end)

            server:sendToAll('test', {
                a = 0.12,
                b = -987345,
                c = "test",
                d = true,
                e = {},
            })
            server:update()
            client:update()
            server:update()
            client:update()

            assert.True(received)
        end)

        it('a table array', function()
            local received = false

            client:on('test', function(data, client)
                assert.are.same(data, {
                    0.12,
                    -987345,
                    "test",
                    true,
                    {},
                })
                received = true
            end)

            server:sendToAll('test', {
                0.12,
                -987345,
                "test",
                true,
                {},
            })
            server:update()
            client:update()

            assert.True(received)
        end)
    end)
end)
