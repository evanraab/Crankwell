local gfx <const> = playdate.graphics

local DEFAULT_BOUNCE_VELOCITY <const> = -6 -- same as an enemy stomp; a full jump is -7.9
local DEFAULT_RESPAWN_TIME <const> = 60    -- frames gone before it comes back (~2s at 30fps)
local POP_FRAMES <const> = 4               -- frames the flattened "used" sprite shows before vanishing

-- Placeholder art: solid white with black up-chevrons, so it reads differently from plain platforms.
local function makeBounceImage(w, h)
    local img = gfx.image.new(w, h, gfx.kColorWhite)
    gfx.pushContext(img)
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(2)
    local size = math.min(h // 2 - 2, 5)
    local mid = h // 2
    for cx = 10, w - 6, 14 do
        gfx.drawLine(cx - size, mid + size // 2, cx, mid - size // 2)
        gfx.drawLine(cx, mid - size // 2, cx + size, mid + size // 2)
    end
    gfx.setLineWidth(1)
    gfx.drawRect(0, 0, w, h)
    gfx.popContext()
    return img
end

-- Squashed version shown for a moment after a bounce: same footprint, bottom half only.
local function makePoppedImage(w, h)
    local img = gfx.image.new(w, h, gfx.kColorClear)
    gfx.pushContext(img)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(0, h // 2, w, h - h // 2)
    gfx.setColor(gfx.kColorBlack)
    gfx.setDitherPattern(0.5, gfx.image.kDitherTypeBayer2x2)
    gfx.fillRect(2, h // 2 + 2, w - 4, h - h // 2 - 4)
    gfx.popContext()
    return img
end

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
        local w, h = self:getSize()
        self.readyImage = makeBounceImage(w, h)
        self.poppedImage = makePoppedImage(w, h)
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
