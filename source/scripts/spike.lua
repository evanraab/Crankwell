
local gfx <const> = playdate.graphics

local spikeImage <const> = gfx.image.new("images/hazzards/spikes/spike")

--- @class Spike : playdate.graphics.sprite
--- @overload fun(...): Spike
Spike = {}
class('Spike').extends(gfx.sprite)


function Spike:init(x, y)
    self:setZIndex(Z_INDEXES.Hazzard)
    self:setImage(spikeImage)
    self:setCenter(0, 0)
    self:moveTo(x, y)
    self:add()

    self:setTag(TAGS.Hazzard)
    self:setCollideRect(5, 10, 12, 12)
end


