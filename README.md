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

TODO
