local gfx <const> = playdate.graphics
local fireballShooterImage <const> = gfx.image.new("images/hazzards/fireballShooter/fireballShooter")

-- Unit vector for each facing; also the flip/rotation used to draw the shooter that way.
-- The art is assumed to face RIGHT by default.
local DIRECTIONS <const> = {
    Right = { x = 1,  y = 0,  angle = 0 },
    Down  = { x = 0,  y = 1,  angle = 90 },
    Left  = { x = -1, y = 0,  angle = 180 },
    Up    = { x = 0,  y = -1, angle = 270 },
}

local DEFAULT_FIRE_INTERVAL <const> = 1500 -- ms between shots
local DEFAULT_BULLET_SPEED <const> = 3     -- pixels per frame

---@class ProjectileShooter : playdate.graphics.sprite
---@overload fun(...): ProjectileShooter
ProjectileShooter = {}
class('ProjectileShooter').extends(gfx.sprite)

function ProjectileShooter:init(x, y, entity)
    ProjectileShooter.super.init(self)

    local fields = (entity and entity.fields) or {}
    self.facing = DIRECTIONS[fields.direction] or DIRECTIONS.Right
    self.bulletSpeed = fields.bulletSpeed or DEFAULT_BULLET_SPEED

    self:setZIndex(Z_INDEXES.Hazzard)
    self:setImage(fireballShooterImage:rotatedImage(self.facing.angle))
    self:setCenter(0, 0)
    self:moveTo(x, y)
    self:add()

    self:setTag(TAGS.Hazzard)

    self.fireTimer = playdate.timer.new(fields.fireInterval or DEFAULT_FIRE_INTERVAL, function()
        self:shootProjectile()
    end)
    self.fireTimer.repeats = true
end

function ProjectileShooter:shootProjectile()
    local w, h = self:getSize()
    -- Spawn at the edge of the shooter on the side it faces (center is 0,0 = top-left)
    local spawnX = self.x + w / 2 + self.facing.x * w / 2
    local spawnY = self.y + h / 2 + self.facing.y * h / 2

    Bullet.spawn(spawnX, spawnY, self.facing.x * self.bulletSpeed, self.facing.y * self.bulletSpeed)
end

-- Stop firing when the level unloads this sprite, otherwise the timer keeps spawning bullets
function ProjectileShooter:remove()
    if self.fireTimer then
        self.fireTimer:remove()
        self.fireTimer = nil
    end
    ProjectileShooter.super.remove(self)
end
