local gfx <const> = playdate.graphics
local spikeBallImage <const> = gfx.image.new("images/hazzards/spikeball/spikeball")

--- @class Spikeball : playdate.graphics.sprite
--- @overload fun(...): Spikeball
Spikeball = {}
class('Spikeball').extends(gfx.sprite)


function Spikeball:init(x, y, entity)
    self:setZIndex(Z_INDEXES.Hazzard)
    self:setImage(spikeBallImage)
    self:setCenter(0, 0)
    self:moveTo(x, y)
    self:add()

    self:setTag(TAGS.Hazzard)
    self:setCollideRect(0, 0, self:getSize()) -- matches the image (18x18)

    local fields = entity.fields
    self.xVelocity = fields.xVelocity
    self.yVelocity = fields.yVelocity
end

function Spikeball:collisionResponse(other)
    if other:getTag() == TAGS.Player then
        return gfx.sprite.kCollisionTypeOverlap
    end
    return gfx.sprite.kCollisionTypeBounce
end

-- True if the ball's collide rect already sits inside something solid (e.g. placed into a wall in LDtk).
function Spikeball:isEmbedded()
    for _, other in ipairs(self:overlappingSprites()) do
        if other:getTag() ~= TAGS.Player and self:collisionResponse(other) == gfx.sprite.kCollisionTypeBounce then
            return true
        end
    end
    return false
end

function Spikeball:update()
    -- moveWithCollisions with a bounce response can loop forever when the sprite starts
    -- inside a wall, freezing the game. Stay put instead and say where the bad placement is.
    if self:isEmbedded() then
        if not self.warnedEmbedded then
            self.warnedEmbedded = true
            print(("Spikeball at (%d, %d) is stuck inside a wall; move it in LDtk"):format(self.x, self.y))
        end
        return
    end

    local _, _, collisions, length = self:moveWithCollisions(self.x + self.xVelocity, self.y + self.yVelocity)
    local hitWall = false
    for i = 1, length do
        local collision = collisions[i]
        if collision.other:getTag() ~= TAGS.Player then
            hitWall = true
        end
    end

    if hitWall then
        self.xVelocity *= -1
        self.yVelocity *= -1
    end
end