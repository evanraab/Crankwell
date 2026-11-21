local gfx <const> = playdate.graphics

local DEFAULT_CRUMBLE_TIME <const> = 30 -- frames from landing to vanishing (~1s at 30fps)
local DEFAULT_RESPAWN_TIME <const> = 60 -- frames gone before it comes back (~2s)
local CRACK_STAGES <const> = 3          -- intact image + this many progressively cracked images
local SHAKE_PERIOD <const> = 2          -- frames per shake step while crumbling

-- Small deterministic RNG so every platform of a given size cracks the same way.
local function makeRng(seed)
    local state = seed
    return function(lo, hi)
        state = (state * 1103515245 + 12345) % 2147483648
        return lo + state % (hi - lo + 1)
    end
end

-- Jagged crack running down from the top edge.
local function drawCrack(rand, x, h)
    local y = 0
    while y < h do
        local nx = x + rand(-3, 3)
        local ny = y + rand(3, 6)
        gfx.drawLine(x, y, nx, ny)
        x, y = nx, ny
    end
end

-- Stage 1..CRACK_STAGES: more cracks each stage, then chunks broken off the corners and edges.
local function makeCrackedImage(base, stage)
    local w, h = base:getSize()
    local img = base:copy()
    local rand = makeRng(w * 31 + h)
    gfx.pushContext(img)
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(2)
    local cracks = math.max(1, w // 20) * stage
    for i = 1, cracks do
        drawCrack(rand, (w * i) // (cracks + 1), h)
    end
    if stage >= 2 then
        gfx.setColor(gfx.kColorClear)
        local chunk = math.min(h // 2, 6) * (stage - 1)
        gfx.fillTriangle(0, 0, chunk, 0, 0, chunk)
        gfx.fillTriangle(w, h, w - chunk, h, w, h - chunk)
        if stage >= 3 then
            gfx.fillTriangle(w, 0, w - chunk, 0, w, chunk)
            gfx.fillTriangle(0, h, chunk, h, 0, h - chunk)
            gfx.fillRect(w // 2 - 2, h - chunk // 2, 4, chunk // 2)
        end
    end
    gfx.popContext()
    return img
end

-- Images are cached per platform size, since every platform of a size looks the same.
local imageCache = {}
local function getStageImages(base)
    local w, h = base:getSize()
    local key = w .. "x" .. h
    local images = imageCache[key]
    if not images then
        images = { [0] = base }
        for stage = 1, CRACK_STAGES do
            images[stage] = makeCrackedImage(base, stage)
        end
        imageCache[key] = images
    end
    return images
end

local function hasPlayer(riders)
    for rider in pairs(riders) do
        if rider:getTag() == TAGS.Player and not rider.dead then
            return true
        end
    end
    return false
end

--- A platform that starts crumbling once the player lands on it: it shakes and cracks up over
--- `crumbleTime` frames, then vanishes. After `respawnTime` frames it comes back intact (waiting
--- if someone is standing in its space). Leaving it mid-crumble doesn't save it. Restores
--- instantly when the player respawns.
---
--- LDtk fields (all optional):
---   crumbleTime Int  frames from landing to vanishing
---   respawnTime Int  frames gone before it reappears
--- @class CrumblingPlatform : TimedPlatform
--- @overload fun(...): CrumblingPlatform
CrumblingPlatform = {}
class('CrumblingPlatform').extends(TimedPlatform)

function CrumblingPlatform:init(x, y, entity)
    local fields = entity.fields or {}
    self.crumbleTime = math.max(1, fields.crumbleTime or DEFAULT_CRUMBLE_TIME)
    self.respawnTime = math.max(1, fields.respawnTime or DEFAULT_RESPAWN_TIME)

    -- Also registers us with TimedPlatform.resetAll, which calls our restartCycle on respawn.
    CrumblingPlatform.super.init(self, x, y, entity)
end

-- Overrides TimedPlatform's cycle: back to solid, intact and waiting for the player.
function CrumblingPlatform:restartCycle()
    if not self.stageImages then
        self.stageImages = getStageImages(self:getImage())
    end
    self.crumbling = false
    self.timer = 0
    self:setImage(self.stageImages[0])
    self:setCenter(0, 0)
    self:moveTo(self.startX, self.startY)
    self:setSolid(true)
end

function CrumblingPlatform:update()
    if not self.solid then
        self.riders = {}
        self.timer += 1
        if self.timer >= self.respawnTime and not self:isBlocked() then
            self:restartCycle()
        end
        return
    end

    if not self.crumbling and hasPlayer(self.riders) then
        self.crumbling = true
        self.timer = 0
    end
    MovingPlatform.update(self) -- carries riders, clears them for next frame

    if not self.crumbling then return end

    self.timer += 1
    if self.timer >= self.crumbleTime then
        self.timer = 0
        self.crumbling = false
        self:setImage(self.stageImages[0])
        self:moveTo(self.startX, self.startY)
        self:setSolid(false)
        return
    end

    -- Crack up in even steps across the crumble time, and shake harder near the end.
    local stage = 1 + (self.timer * CRACK_STAGES) // self.crumbleTime
    self:setImage(self.stageImages[math.min(stage, CRACK_STAGES)])
    local shake = (self.timer // SHAKE_PERIOD) % 2 == 0 and 1 or -1
    if stage < CRACK_STAGES then shake = 0 end
    self:moveTo(self.startX + shake, self.startY)
end
