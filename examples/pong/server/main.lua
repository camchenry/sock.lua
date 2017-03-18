package.path = package.path .. ";../../?.lua"
sock = require "sock"
bitser = require "spec.bitser"

-- Utility functions
function isColliding(this, other)
    return  this.x < other.x + other.w and
            this.y < other.y + other.h and
            this.x + this.w > other.x and
            this.y + this.h > other.y
end

function love.load()
    -- how often an update is sent out
    tickRate = 1/60
    tick = 0

    server = sock.newServer("*", 22122, 2)
    server:setSerialization(bitser.dumps, bitser.loads)

    -- Players are being indexed by peer index here, definitely not a good idea
    -- for a larger game, but it's good enough for this application.
    server:on("connect", function(data, client)
        -- tell the peer what their index is
        client:send("playerNum", client:getIndex())
    end)

    -- receive info on where a player is located
    server:on("mouseY", function(y, client)
        local index = client:getIndex()
        players[index].y = y
    end)


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
    server:update()

    -- wait until 2 players connect to start playing
    local enoughPlayers = #server.clients >= 2
    if not enoughPlayers then return end

    for i, player in pairs(players) do
        -- This is a naive solution, if the ball is inside the paddle it might bug out
        -- But hey, it's low stakes pong
        if isColliding(ball, player) then
            ball.vx = ball.vx * -1
            ball.vy = ball.vy * -1
        end
    end

    -- Left/Right bounds
    if ball.x < 0 or ball.x > love.graphics.getWidth() then
        if ball.x < 0 then
            scores[2] = scores[2] + 1
        else
            scores[1] = scores[1] + 1
        end

        server:sendToAll("scores", scores)

        ball.x = love.graphics.getWidth()/2
        ball.y = love.graphics.getHeight()/2
        ball.vx = ball.vx * -1
        ball.vy = ball.vy * -1
    end
    
    -- Top/Bottom bounds
    if ball.y < 0 or ball.y > love.graphics.getHeight() - ball.h then
        ball.vy = ball.vy * -1

        if ball.y < 0 then
            ball.y = 0
        end

        if ball.y > love.graphics.getHeight() - ball.h then
            ball.y = love.graphics.getHeight() - ball.h
        end
    end

    ball.x = ball.x + ball.vx * dt
    ball.y = ball.y + ball.vy * dt

    tick = tick + dt

    if tick >= tickRate then
        tick = 0

        for i, player in pairs(players) do
            server:sendToAll("playerState", {i, player})
        end

        server:sendToAll("ballState", ball)
    end
end

function love.draw()
    for i, player in pairs(players) do
        love.graphics.rectangle('fill', player.x, player.y, player.w, player.h)
    end

    love.graphics.rectangle('fill', ball.x, ball.y, ball.w, ball.h)
    local score = ("%d - %d"):format(scores[1], scores[2])
    love.graphics.print(score, 5, 5)
end
