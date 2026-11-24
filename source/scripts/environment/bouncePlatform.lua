local gfx <const> = playdate.graphics

local DEFAULT_BOUNCE_VELOCITY <const> = -6 -- same as an enemy stomp; a full jump is -7.9
local DEFAULT_RESPAWN_TIME <const> = 60    -- frames gone before it comes back (~2s at 30fps)
local POP_FRAMES <const> = 4               -- frames the flattened "used" sprite shows before vanishing

--- A platform that launches the player upward when they land on it, then vanishes. It comes
--- back after `respawnTime` frames (waiting if someone is standing in its space). Restores
--- instantly when the player respawns. The bounce itself is applied by PlayerCollision,
--- which calls onBounced() when the player lands on top.
---
--- LDtk fields (all optional):
---   bounceVelocity Float  upward launch speed (positive number; bigger = higher)
---   respawnTime    Int    frames gone before it reappears
--- @class BouncePlatform : TimedPlatform
--- @overload fun(...): BouncePlatform
BouncePlatform = {}
class('BouncePlatform').extends(TimedPlatform)

BouncePlatform.imagePath = "images/platforms/bouncePlatform/bounce-platform"

-- Squashed version shown for a moment after a bounce: the ready image at half height, sitting
-- on the bottom edge. Cached per ready image.
local poppedCache = setmetatable({}, { __mode = "k" })
local function getPoppedImage(ready)
    local popped = poppedCache[ready]
    if not popped then
        local w, h = ready:getSize()
        popped = gfx.image.new(w, h, gfx.kColorClear)
        gfx.pushContext(popped)
        ready:drawScaled(0, h - h // 2, 1, (h // 2) / h)
        gfx.popContext()
        poppedCache[ready] = popped
    end
    return popped
end

function BouncePlatform:init(x, y, entity)
    local fields = entity.fields or {}
    local strength = fields.bounceVelocity and -math.abs(fields.bounceVelocity) or DEFAULT_BOUNCE_VELOCITY
    self.respawnTime = math.max(1, fields.respawnTime or DEFAULT_RESPAWN_TIME)
    self.bounceProfile = {
        velocity = strength,
        -- Behave like an enemy stomp: stay airborne so the landing/jump-cut logic doesn't eat the bounce.
        onBounce = function(player) player.touchingGround = false end,
    }

    -- Also registers us with TimedPlatform.resetAll, which calls our restartCycle on respawn.
    BouncePlatform.super.init(self, x, y, entity)
end

-- Overrides TimedPlatform's cycle: back to solid and ready to bounce.
function BouncePlatform:restartCycle()
    if not self.readyImage then
        -- MovingPlatform's init already set the image from BouncePlatform.imagePath
        self.readyImage = self:getImage()
        self.poppedImage = getPoppedImage(self.readyImage)
    end
    self.timer = 0
    self:setImage(self.readyImage)
    self:setSolid(true)
end

-- Called by PlayerCollision when the player lands on top. Returns the bounce profile to apply.
function BouncePlatform:onBounced()
    self.timer = 0
    self:setSolid(false)
    -- keep the squashed sprite on screen briefly so the bounce reads, but it's no longer solid
    self:setImage(self.poppedImage)
    self:setVisible(true)
    return self.bounceProfile
end

function BouncePlatform:update()
    self.riders = {}
    if self.solid then return end

    self.timer += 1
    if self.timer == POP_FRAMES then
        self:setVisible(false)
    end
    if self.timer >= self.respawnTime and not self:isBlocked() then
        self:restartCycle()
    end
end
