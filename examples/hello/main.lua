-- Loading sock from root directory relative to this one
-- This is not required in your own projects
package.path = package.path .. ";../?.lua"
local sock = require "sock"
local binser = require "spec.binser"

function love.load()
    client = sock.newClient("localhost", 22122)
    server = sock.newServer("localhost", 22122)

    -- If the connect/disconnect callbacks aren't defined some warnings will
    -- be thrown, but nothing bad will happen.
    
    -- Called when someone connects to the server
    server:on("connect", function(data, peer)
        local msg = "Hello from server!"
        peer:send("hello", msg)
    end)

    
    -- Called when a connection is made to the server
    client:on("connect", function(data)
        print("Client connected to the server.")
    end)
    
    -- Custom callback, called whenever you send the event from the server
    client:on("hello", function(msg)
        print(msg)
    end)

    client:connect()
end

function love.update(dt)
    server:update()
    client:update()

    if love.math.random() > 0.95 then
        server:sendToAll("hello", "This is an update message")
    end
end

function love.keypressed(key)
    if key == "q" then
        client:reset()
    end
end
