local gfx <const> = playdate.graphics
local fireballShooterImage <const> = gfx.image.new("images/hazzards/fireballShooter/fireballShooter")

-- Unit vector the bullet travels along for each direction (doesn't change the shooter's art)
local DIRECTIONS <const> = {
    Right = { x = 1,  y = 0 },
    Down  = { x = 0,  y = 1 },
    Left  = { x = -1, y = 0 },
    Up    = { x = 0,  y = -1 },
}

local DEFAULT_FIRE_INTERVAL <const> = 1.5 -- seconds between shots
local DEFAULT_BULLET_SPEED <const> = 3     -- pixels per frame

local SCREEN_WIDTH <const> = playdate.display.getWidth()
local SCREEN_HEIGHT <const> = playdate.display.getHeight()

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
    if fields.hidden then
        -- No art (e.g. fire coming out of the ground): keep the LDtk entity's size so the
        -- bullet spawn point and on-screen check still work, but draw nothing
        local w, h = fireballShooterImage:getSize()
        if entity and entity.size then
            w, h = entity.size.width, entity.size.height
        end
        self:setSize(w, h)
        self:setVisible(false)
    else
        self:setImage(fireballShooterImage)
    end
    self:setCenter(0, 0)
    self:moveTo(x, y)
    self:add()

    self:setTag(TAGS.Hazzard)

    -- fireInterval in LDtk is in SECONDS; playdate timers use milliseconds
    local intervalMs = (fields.fireInterval or DEFAULT_FIRE_INTERVAL) * 1000
    self.fireTimer = playdate.timer.new(intervalMs, function()
        self:shootProjectile()
    end)
    self.fireTimer.repeats = true
end

-- True when any part of the shooter is inside the camera's view.
-- The camera scrolls via gfx.setDrawOffset(-camX, -camY), so the offset gives the view's world position.
function ProjectileShooter:isOnScreen()
    local offsetX, offsetY = gfx.getDrawOffset()
    local viewX, viewY = -offsetX, -offsetY
    local w, h = self:getSize()
    -- sprite center is (0,0), so self.x/self.y is the top-left corner
    return self.x + w > viewX and self.x < viewX + SCREEN_WIDTH
       and self.y + h > viewY and self.y < viewY + SCREEN_HEIGHT
end

function ProjectileShooter:shootProjectile()
    if not self:isOnScreen() then
        return
    end

    local w, h = self:getSize()
    -- Spawn at the edge of the shooter on the side it fires from (sprite center is 0,0 = top-left)
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
