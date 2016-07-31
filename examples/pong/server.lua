-- libraries
sock = require "sock"

function love.load()
    -- how often an update is sent out
    tickRate = 1/30
    tick = 0

    server = sock.newServer("*", 22122, 2)

    server:on("connect", function(data, peer)
        -- tell the peer what their index is
        peer:emit("playerNum", peer.server:index())
    end)

    -- receive info on where a player is located
    server:on("mouseY", function(data, peer)
        local mouseY = data
        local index = peer.server:index()

        players[index].y = mouseY
    end)


    local xMargin = 50

    playerSize = {
        w = 20,
        h = 100
    }

    ballSize = {
        w = 15,
        h = 15
    }

    players = {
        {x = xMargin,
         y = love.graphics.getHeight()/2
        },

        {x = love.graphics.getWidth() - xMargin,
         y = love.graphics.getHeight()/2
        }
    }

    ball = {
        x = love.graphics.getWidth()/2,
        y = love.graphics.getHeight()/2,
        vx = 150,
        vy = 150
    }
end

function love.update(dt)
    server:update()

    ball.x = ball.x + ball.vx * dt
    ball.y = ball.y + ball.vy * dt

    for k, player in pairs(players) do
        if ball.x < player.x + playerSize.w and
            ball.x + ballSize.w > player.x and
            ball.y < player.y + playerSize.h and
            ball.y + ballSize.h > player.y then

            ball.vx = ball.vx * -1
            ball.vy = ball.vy * -1
        end
    end

    if ball.x < 0 then
        ball.x = love.graphics.getWidth()/2
        ball.y = love.graphics.getHeight()/2
    end

    if ball.x > love.graphics.getWidth() then
        ball.x = love.graphics.getWidth()/2
        ball.y = love.graphics.getHeight()/2
    end

    if ball.y < 0 then
        ball.y = 0
        ball.vy = ball.vy * -1
    end

    if ball.y > love.graphics.getHeight() then
        ball.y = love.graphics.getHeight()
        ball.vy = ball.vy * -1
    end

    tick = tick + dt

    if tick >= tickRate then
        tick = 0

        for k, player in pairs(players) do
            server:emitToAll("playerState", {index = k, player = player})
        end

        server:emitToAll("ballState", ball)
    end
end

function love.draw()
    for k, player in pairs(players) do
        local w, h = playerSize.w, playerSize.h
        love.graphics.rectangle('fill', player.x - w/2, player.y - h/2, w, h)
    end

    local w, h = ballSize.w, ballSize.h
    love.graphics.rectangle('fill', ball.x - w/2, ball.y - h/2, w, h)

    love.graphics.print("Hello", 5, 5)
end
