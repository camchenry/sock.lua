# sock.lua

[![Build Status](https://travis-ci.org/camchenry/sock.lua.svg?branch=master)](https://travis-ci.org/camchenry/sock.lua)

sock.lua is a networking library for LÖVE games. Its goal is to make getting started with networking as easy as possible.

**sock requires [enet](https://github.com/leafo/lua-enet) (which comes with LÖVE 0.9 and up.)**

- [Source code](https://github.com/camchenry/sock.lua)
- [Documentation](http://camchenry.com/sock.lua/)

## Features

- Event trigger system makes it easy to add behavior to network events.
- Can send images and files over the network.
- Use any serialization library you want.
- Logs events, errors, and warnings that occur.

# Installation

1. Clone or download the repository. 
    * `git clone https://github.com/camchenry/sock.lua.git`
2. Install lua-enet, unless you are running with LÖVE in which case you already have it.
3. Download a serialization library.
    * Recommended: [bitser](https://github.com/gvx/bitser), or [binser](https://github.com/bakpakin/binser) if you don't have LuaJIT available.
4. Place it in the same directory as sock.lua (if you are using bitser or binser).
5. Require the library and start using it.
    * `sock = require 'sock'`

* (Optional) If you would like to use your own serialization function, look at [setSerialization](http://camchenry.com/sock.lua/index.html#Server:setSerialization).

# Example

```lua
local sock = require "sock"

-- client.lua
function love.load()
    -- Creating a new client on localhost:22122
    client = sock.newClient("localhost", 22122)
    
    -- Creating a client to connect to some ip address
    client = sock.newClient("198.51.100.0", 22122)

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
    
    --  You can send different types of data
    client:emit("greeting", "Hello, my name is Inigo Montoya.")
    client:emit("isShooting", true)
    client:emit("bulletsLeft", 1)
    client:emit("position", {
        x = 465.3,
        y = 50,
    })
end

function love.update(dt)
    client:update()
end
```

```lua
-- server.lua
function love.load()
    -- Creating a server on any IP, port 22122
    server = sock.newServer("*", 22122)
    
    -- Called when someone connects to the server
    server:on("connect", function(data, client)
        -- Send a message back to the connected client
        local msg = "Hello from the server!"
        client:emit("hello", msg)
    end)
end

function love.update(dt)
    server:update()
end

```
