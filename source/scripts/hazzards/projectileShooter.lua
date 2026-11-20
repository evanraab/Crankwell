local gfx <const> = playdate.graphics
local fireballShooterImage <const> = gfx.image.new("images/hazzards/fireballShooter/fireballShooter")


---@class ProjectileShooter : playdate.graphics.sprite
---@overload fun(...): ProjectileShooter
ProjectileShooter = {}
class('ProjectileShooter').extends(gfx.sprite)

function ProjectileShooter:init(x, y, entity)
    {
        self:setZIndex(Z_INDEXES.Hazzard)
        self:setImage(fireballShooterImage)
    }

function ProjectileShooter:ShootProjectile()
    local _ = Bullet.spawn(self.x, self.y, velX, velY)



end