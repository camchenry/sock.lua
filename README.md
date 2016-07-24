# sock.lua

sock.lua is a networking library for Lua/LÖVE games. It wraps around lua-enet
and uses bitser to make getting started with networking as easy as possible.

**sock requires [bitser](https://github.com/gvx/bitser) and [enet](https://github.com/leafo/lua-enet) (which comes with LÖVE 0.9.x and up.)**

## Features

- No assumptions about your game, able to adapt to any type of game.
- Fast enough to be used for a real-time game like a FPS or RTS.
- Event trigger system lets you add callbacks to events
- Uses bitser to minimize data usage and maximize speed.
- Logs events, errors, and warnings that occur.

## Notes

sock.lua is meant to simplify transporting data over the internet for games. It
does not provide any abstractions like lobbies, matchmaking, or players 
(only peers and clients).

# Example

TODO
