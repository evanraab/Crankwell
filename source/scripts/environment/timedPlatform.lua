local gfx <const> = playdate.graphics

local DEFAULT_ON_TIME <const> = 90   -- frames solid (~3s at 30fps)
local DEFAULT_OFF_TIME <const> = 60  -- frames gone (~2s)
local DEFAULT_WARN_TIME <const> = 30 -- frames of flashing before it vanishes
local FLASH_PERIOD <const> = 4       -- frames per flash half-cycle

-- Every live TimedPlatform, so a player respawn can restart them all in sync. Weak keys let
-- platforms from unloaded levels be garbage collected.
local instances = setmetatable({}, { __mode = "k" })

--- A MovingPlatform that blinks in and out on a loop: solid for `onTime` frames (flashing for
--- the last `warnTime` of them), then gone for `offTime` frames. If the player or an enemy is
--- standing inside its space when it's due to come back, it waits until they're clear so nobody
--- gets stuck in it. If it has an endPoint it moves while visible and pauses while hidden.
--- Restarts its cycle when the player respawns.
---
--- LDtk fields (all optional):
---   onTime      Int    frames the platform is solid
---   offTime     Int    frames the platform is gone
---   warnTime    Int    frames of flashing at the end of onTime (0 = no warning)
---   startOffset Int    frames to skip into the cycle, to stagger neighbouring platforms
---   startHidden Bool   begin the cycle in the "gone" phase
---   endPoint, speed, pauseFrames: as MovingPlatform
--- @class TimedPlatform : MovingPlatform
--- @overload fun(...): TimedPlatform
TimedPlatform = {}
class('TimedPlatform').extends(MovingPlatform)

function TimedPlatform:init(x, y, entity)
    TimedPlatform.super.init(self, x, y, entity)

    local fields = entity.fields or {}
    self.onTime = math.max(1, fields.onTime or DEFAULT_ON_TIME)
    self.offTime = math.max(1, fields.offTime or DEFAULT_OFF_TIME)
    self.warnTime = math.min(fields.warnTime or DEFAULT_WARN_TIME, self.onTime)
    self.startOffset = fields.startOffset or 0
    self.startHidden = fields.startHidden or false

    instances[self] = true
    self:restartCycle()
end

function TimedPlatform:setSolid(solid)
    self.solid = solid
    self:setVisible(solid)
    self:setCollisionsEnabled(solid)
    self:setImageDrawMode(gfx.kDrawModeCopy)
    self.riders = {}
end

-- Puts the platform at the start of its cycle (plus startOffset), wrapping through phases.
function TimedPlatform:restartCycle()
    local solid = not self.startHidden
    local timer = self.startOffset % (self.onTime + self.offTime)
    local phaseLength = solid and self.onTime or self.offTime
    if timer >= phaseLength then
        timer -= phaseLength
        solid = not solid
    end
    self.timer = timer
    self:setSolid(solid)
end

-- True if the player or a live enemy overlaps the space we'd occupy.
function TimedPlatform:isBlocked()
    local x, y, w, h = self:getBounds()
    for _, s in ipairs(gfx.sprite.querySpritesInRect(x, y, w, h)) do
        local tag = s:getTag()
        if (tag == TAGS.Player or tag == TAGS.Enemy) and not s.dead then
            return true
        end
    end
    return false
end

function TimedPlatform:update()
    self.timer += 1

    if self.solid then
        TimedPlatform.super.update(self) -- carries riders / follows the path

        local warnStart = self.onTime - self.warnTime
        if self.timer >= self.onTime then
            self.timer = 0
            self:setSolid(false)
        elseif self.warnTime > 0 and self.timer >= warnStart then
            local flashOn = ((self.timer - warnStart) // FLASH_PERIOD) % 2 == 0
            self:setImageDrawMode(flashOn and gfx.kDrawModeInverted or gfx.kDrawModeCopy)
        end
    else
        self.riders = {}
        -- hold off reappearing until nobody is standing where we'd be
        if self.timer >= self.offTime and not self:isBlocked() then
            self.timer = 0
            self:setSolid(true)
        end
    end
end

function TimedPlatform.resetAll()
    for platform in pairs(instances) do
        platform:restartCycle()
    end
end
