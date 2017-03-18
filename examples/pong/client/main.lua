package.path = package.path .. ";../../?.lua"
sock = require "sock"
bitser = require "spec.bitser"

function love.load()
    -- how often an update is sent out
    tickRate = 1/60
    tick = 0

    client = sock.newClient("localhost", 22122)
    client:setSerialization(bitser.dumps, bitser.loads)
    client:setSchema("playerState", {
        "index",
        "player",
    })

    -- store the client's index
    -- playerNumber is nil otherwise
    client:on("playerNum", function(num)
        playerNumber = num
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

    client:on("scores", function(data)
        scores = data
    end)

    client:connect()

    function newPlayer(x, y)
        return {
            x = x,
            y = y,
            w = 20,
            h = 100,
        }
    end

    function newBall(x, y)
        return {
            x = x,
            y = y,
            vx = 150,
            vy = 150,
            w = 15,
            h = 15,
        }
    end

    local marginX = 50

    players = {
        newPlayer(marginX, love.graphics.getHeight()/2),
        newPlayer(love.graphics.getWidth() - marginX, love.graphics.getHeight()/2)
    }

    scores = {0, 0}

    ball = newBall(love.graphics.getWidth()/2, love.graphics.getHeight()/2)
end

function love.update(dt)
    client:update()
    
    if client:getState() == "connected" then
        tick = tick + dt

        -- simulate the ball locally, and receive corrections from the server
        ball.x = ball.x + ball.vx * dt
        ball.y = ball.y + ball.vy * dt
    end

    if tick >= tickRate then
        tick = 0

        if playerNumber then
            local mouseY = love.mouse.getY()
            local playerY = mouseY - players[playerNumber].h/2

            -- Update our own player position and send it to the server
            players[playerNumber].y = playerY
            client:send("mouseY", playerY)
        end
    end
end

function love.draw()
    for _, player in pairs(players) do
        love.graphics.rectangle('fill', player.x, player.y, player.w, player.h)
    end

    love.graphics.rectangle('fill', ball.x, ball.y, ball.w, ball.h)

    love.graphics.print(client:getState(), 5, 5)
    if playerNumber then
        love.graphics.print("Player " .. playerNumber, 5, 25)
    else
        love.graphics.print("No player number assigned", 5, 25)
    end
    local score = ("%d - %d"):format(scores[1], scores[2])
    love.graphics.print(score, 5, 45)
end
