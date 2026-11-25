local DEFAULT_RETURN_DELAY <const> = 90 -- frames the player must be off before we head home (~3s at 30fps)

-- Every live TriggeredPlatform, so a player respawn can send them all home. Weak keys let
-- platforms from unloaded levels be garbage collected.
local instances = setmetatable({}, { __mode = "k" })

--- A MovingPlatform that sits still at its LDtk position until the player lands on it, then
--- travels to `endPoint` and stops there. Once the player has been off it for `returnDelay`
--- frames it travels back to its origin. Landing on it again (even mid-return) sends it
--- back towards the end. Snaps back to the origin when the player respawns.
---
--- LDtk fields (all optional):
---   endPoint    Point  grid cell the platform's top-left travels to (no point = stays still)
---   speed       Float  px per frame
---   returnDelay Int    frames the player must be off before it returns to its origin
--- @class TriggeredPlatform : MovingPlatform
--- @overload fun(...): TriggeredPlatform
TriggeredPlatform = {}
class('TriggeredPlatform').extends(MovingPlatform)

TriggeredPlatform.movingImagePath = false -- keeps its own art even with an endPoint

function TriggeredPlatform:init(x, y, entity)
    TriggeredPlatform.super.init(self, x, y, entity)

    local fields = entity.fields or {}
    self.returnDelay = fields.returnDelay or DEFAULT_RETURN_DELAY
    self.offTimer = 0
    self.direction = 0 -- 0 = resting, 1 = heading to end, -1 = heading home

    instances[self] = true
end

local function hasPlayer(riders)
    for rider in pairs(riders) do
        if rider:getTag() == TAGS.Player and not rider.dead then
            return true
        end
    end
    return false
end

function TriggeredPlatform:update()
    local riders = self.riders
    self.riders = {}

    if self.pathLength == 0 then return end

    if hasPlayer(riders) then
        self.offTimer = 0
        self.direction = 1
    elseif self.progress > 0 then
        self.offTimer += 1
        if self.offTimer >= self.returnDelay then
            self.direction = -1
        end
    end

    if self.direction == 0 then return end

    self.progress += self.speed * self.direction
    if self.progress >= self.pathLength then
        self.progress = self.pathLength
        self.direction = 0
    elseif self.progress <= 0 then
        self.progress = 0
        self.direction = 0
        self.offTimer = 0
    end

    self:moveAlongPath(riders)
end

-- Snap straight back to the origin without carrying or shoving anything.
function TriggeredPlatform:reset()
    self.progress = 0
    self.direction = 0
    self.offTimer = 0
    self.riders = {}
    self:moveTo(self.startX, self.startY)
end

function TriggeredPlatform.resetAll()
    for platform in pairs(instances) do
        platform:reset()
    end
end
