import "CoreLibs/object"
import "CoreLibs/sprites"

local gfx <const> = playdate.graphics


--- @class BreakableBlock : playdate.graphics.sprite
BreakableBlock = {}
class('BreakableBlock').extends(gfx.sprite)

function BreakableBlock:init(x, y, image)
    BreakableBlock.super.init(self)

    self:setImage(image)
    self:setCenter(0, 0)
    self:moveTo(x, y)
    self:setCollideRect(0, 0, self:getSize())
    self:setTag(TAGS.Breakable)
    self:add()
end


local FLASH_PERIOD_MS <const> = 120

function BreakableBlock:breakBlock()
    self:remove()
end

-- Call every frame while flashing; the phase comes from the clock so connected blocks stay in sync.
function BreakableBlock:setFlashing(flashing)
    local inverted = flashing and (playdate.getCurrentTimeMilliseconds() // FLASH_PERIOD_MS) % 2 == 0
    self:setImageDrawMode(inverted and gfx.kDrawModeInverted or gfx.kDrawModeCopy)
end

-- Returns this block plus every breakable block touching it (edge-adjacent, directly or transitively), as a set.
function BreakableBlock:getConnectedBlocks()
    local connected = { [self] = true }
    local queue = { self }
    local head = 1
    while head <= #queue do
        local block = queue[head]
        head += 1
        local x, y, w, h = block:getBounds()
        local neighbours = gfx.sprite.querySpritesInRect(x - 1, y, w + 2, h)
        local vertical = gfx.sprite.querySpritesInRect(x, y - 1, w, h + 2)
        for _, list in ipairs({ neighbours, vertical }) do
            for _, other in ipairs(list) do
                if not connected[other] and other:getTag() == TAGS.Breakable then
                    connected[other] = true
                    queue[#queue + 1] = other
                end
            end
        end
    end
    return connected
end