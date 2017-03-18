-- Loading sock from root directory relative to this one
-- This is not required in your own projects
package.path = package.path .. ";../../?.lua"
local sock = require "sock"
local bitser = require "spec.bitser"

function love.load()
    client = sock.newClient("localhost", 22122)
    server = sock.newServer("*", 22122)
    client:setSerialization(bitser.dumps, bitser.loads)
    server:setSerialization(bitser.dumps, bitser.loads)
    client:enableCompression()
    server:enableCompression()

    client:connect()

    client:on("image", function(data)
        local file = love.filesystem.newFileData(data, "")
        receivedImage = love.image.newImageData(file)
        receivedImage = love.graphics.newImage(receivedImage)
    end)

    server:on("connect", function(data, client)
        local image = love.filesystem.newFileData("hello.png")
        server:sendToAll("image", image)
    end)

    lastModified = 0
end

function love.update(dt)
    server:update()
    client:update()

    if lastModified < love.filesystem.getLastModified("hello.png") then
        -- Sleep for some milliseconds for the image to write to disk
        love.timer.sleep(0.2)
        lastModified = love.filesystem.getLastModified("hello.png")
        local image = love.filesystem.newFileData("hello.png")
        server:sendToAll("image", image)
    end
end

function love.draw()
    if receivedImage then
        love.graphics.draw(receivedImage, 100, 100)
    end
end
