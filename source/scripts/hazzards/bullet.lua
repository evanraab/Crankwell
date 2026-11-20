local gfx <const> = playdate.graphics
local imageBullet <const> = gfx.image.new("images/hazzards/bullets/bullet_1")

local BULLET_LIFETIME <const> = 4000 -- ms

--- @class Bullet : playdate.graphics.sprite
---@overload fun(...): Bullet
Bullet = {}
class("Bullet").extends(gfx.sprite)

function Bullet:init()
    Bullet.super.init(self, imageBullet)

    self.velocityX = 0
    self.velocityY = 0

    self:setZIndex(Z_INDEXES.Hazzard)
    self:setTag(TAGS.Hazzard)
    self:setCollideRect(0, 0, self:getSize())
end

function Bullet:collisionResponse(other)
    return gfx.sprite.kCollisionTypeOverlap
end

-- Called with a dot: Bullet.spawn(x, y, velX, velY)
function Bullet.spawn(posX, posY, velX, velY)
    local bullet = Bullet()

    bullet:moveTo(posX, posY)
    bullet.velocityX = velX
    bullet.velocityY = velY
    bullet:add()

    bullet.destroyTimer = playdate.timer.new(BULLET_LIFETIME, function()
        bullet:destroy()
    end)
    return bullet
end

function Bullet:destroy()
    if self.destroyTimer then
        self.destroyTimer:remove()
        self.destroyTimer = nil
    end
    self:remove()
end

function Bullet:update()
    local _, _, collisions, length = self:moveWithCollisions(self.x + self.velocityX, self.y + self.velocityY)

    if length > 0 then
        local other = collisions[1].other
        if other:getTag() == TAGS.Player then
            other:die()
        elseif other.onBulletCollision then
            other:onBulletCollision(self)
        end
        self:destroy()
    end
end
