# sock.lua

[![Build Status](https://travis-ci.org/camchenry/sock.lua.svg?branch=master)](https://travis-ci.org/camchenry/sock.lua)

sock.lua is a networking library for LÖVE games. It wraps around lua-enet
and uses bitser to make getting started with networking as easy as possible.

**sock requires [bitser](https://github.com/gvx/bitser) and [enet](https://github.com/leafo/lua-enet) (which comes with LÖVE 0.9 and up.)**

## Features

- Fast enough to be used for a real-time games like FPSes and RTSes.
- Event trigger system makes it easy to add behavior to network events.
- Uses bitser to minimize data usage and maximize speed.
- Logs events, errors, and warnings that occur.

## Notes

sock.lua is meant to simplify transporting data over the internet for games. It
does not provide any abstractions like lobbies, matchmaking, or players 
(only peers and clients). Your game will probably not look smooth initially, because multiplayer games require
a careful mix of interpolation and extrapolation to look good. But, that sort of work is outside the scope of sock.lua.

# Example

```lua
local sock = require "sock"

function love.load()
    -- Creating a new client on localhost:22122
    client = sock.newClient("localhost", 22122)
    
    -- Creating a server on any IP, port 22122
    server = sock.newServer("*", 22122)
    
    -- Called when someone connects to the server
    server:on("connect", function(data, peer)
        local msg = "Hello from the server!"
        peer:emit("hello", msg)
    end)

    -- Called when a connection is made to the server
    client:on("connect", function(data)
        print("Client connected to the server.")
    end)
    
    -- Called when the client disconnects from the server
    client:on("disconnect", function(data)
        print("Client disconnected from the server.")
    end)

    -- Custom callback, called whenever you send the event from the server
    client:on("hello", function(msg)
        print("The server replied: " .. msg)
    end)

    client:connect()

    -- Sending a message
    client:emit("hello", "Hello to the server!")
    
    --  You can send different types of data
    client:emit("isShooting", true)
    client:emit("bulletsLeft", 1)
    client:emit("position", {
        x = 465.3,
        y = 50,
    })
end

function love.update(dt)
    server:update()
    client:update()
end

```
