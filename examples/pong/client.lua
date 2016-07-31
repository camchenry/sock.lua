-- libraries
sock = require "sock"

function love.load()
    -- how often an update is sent out
    tickRate = 1/30
    tick = 0

    client = sock.newClient("localhost", 22122)

    -- store the client's index
    -- playerNumber is nil otherwise
    client:on("playerNum", function(data)
        playerNumber = data
    end)

    -- receive info on where the players are located
    client:on("playerState", function(data)
        local index = data.index
        local player = data.player

        -- only accept updates for the other player
        if playerNumber and index ~= playerNumber then
            players[index] = player
        end
    end)

    client:on("ballState", function(data)
        ball = data
    end)

    client:connect()


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
        vx = 100,
        vy = 100
    }
end

function love.update(dt)
    client:update()

    tick = tick + dt

    if tick >= tickRate then
        tick = 0

        if playerNumber then
            local mouseY = love.mouse.getY()

            players[playerNumber].y = mouseY
            client:emit("mouseY", mouseY)
        end
    end
end

function love.draw()
    for k, player in pairs(players) do
        local w, h = playerSize.w, playerSize.h
        love.graphics.rectangle('fill', player.x - w/2, player.y - h/2, w, h)
    end

    local w, h = ballSize.w, ballSize.h
    love.graphics.rectangle('fill', ball.x - w/2, ball.y - h/2, w, h)

    love.graphics.print(client.server:state(), 5, 5)
    love.graphics.print(playerNumber or "No playerNumber assigned", 5, 25)
end
