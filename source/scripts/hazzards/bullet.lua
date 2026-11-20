local gfx <const> = playdate.graphics
local imageBullet <const> = gfx.image.new("images/hazzards/bullets/bullet_1")

--- @class Bullet : playdate.graphics.sprite
---@overload fun(...): Bullet
Bullet = {}
class("Bullet").extends(gfx.sprite)

function Bullet:init()
    Bullet.super.init(self, imageBullet)

    self.velocityX = 0
    self.velocityY = 0

    self:setCollideRect(0, 0, self:getSize())
end


function Bullet:collisionResponse(other)
    return gfx.sprite.kCollisionTypeOverlap
end

function Bullet:spawn(posX, posY, velX, velY)
    local bullet = Bullet()

    bullet:add()
    bullet:moveTo(posX, posY)
    bullet.velocityX = velX
    bullet.velocityY = velY

    bullet.destroyTimer = playdate.timer.new(4000, bullet.destroy, bullet)
end

function Bulletr:update()
    local _, _, collisions = self:moveWithCollisions(self.x + self.velocityX, self.y + self.velocityY)

    for _, collision in pairs(collisions) do
        local other = collision.other

        if other.onBulletCollision then
            other:onBulletColliision()
        end

        self:destroy()

    end
end