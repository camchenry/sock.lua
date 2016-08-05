-- Loading sock from root directory relative to this one
-- This is not required in your own projects
package.path = package.path .. ";../../?.lua"
local sock = require "sock"

function love.load()
    client = sock.newClient("localhost", 22122)
    server = sock.newServer("*", 22122)

    client:connect()

    client:on("image", function(data)
        local file = love.filesystem.newFileData(data, "")
        receivedImage = love.image.newImageData(file)
        receivedImage = love.graphics.newImage(receivedImage)
    end)

    server:on("connect", function(data, client)
        local image = love.filesystem.newFileData("hello.png")
        server:emitToAll("image", image)
    end)
end

function love.update(dt)
    server:update()
    client:update()
end

function love.draw()
    if receivedImage then
        love.graphics.draw(receivedImage, 100, 100)
    end
end
