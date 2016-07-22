# sock.lua

sock.lua is a networking library for Lua/LÖVE games. It wraps around lua-enet
and uses bitser to make getting started with networking as easy as possible.

*sock requires [bitser](https://github.com/gvx/bitser).*

## Features

- Event trigger system lets you add callbacks to events
- Uses bitser to minimize data usage and maximize speed.
- Logs events, errors, and warnings that occur.
- It does not make assumptions about your game, so it to be used for
any type of game.
- Fast enough to be suitable for real-time games like FPSs and RTSs.

## Notes

sock.lua is meant to ease the complexity of transporting data for games. It 
does not provide any abstractions like lobbies, matchmaking, or players 
(only peers and clients).

# Example

TODO
