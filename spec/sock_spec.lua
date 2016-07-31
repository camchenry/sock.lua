package.path = package.path .. ";../../?.lua"
local sock = require "sock"

describe('sock', function()
    it('does tests', function()
        assert.equal(1 == 1)
    end)
end)
