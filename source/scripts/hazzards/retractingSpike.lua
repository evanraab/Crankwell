local gfx <const> = playdate.graphics

local DEFAULT_UP_TIME <const> = 45     -- frames fully extended (~1.5s at 30fps)
local DEFAULT_DOWN_TIME <const> = 60   -- frames fully retracted, including the warning (~2s)
local DEFAULT_WARN_TIME <const> = 20   -- frames of rattling at the end of downTime (0 = no warning)
local FRAME_TICKS <const> = 3          -- game frames per animation frame while rising/lowering
local WARN_PERIOD <const> = 3          -- game frames per rattle step while warning
local DEADLY_FRACTION <const> = 0.5    -- hurts once the animation is at least this far up

-- Art: an imagetable whose FIRST frame is fully retracted and LAST frame is fully extended.
-- The rising animation plays it forwards, lowering plays it backwards, and the warning flicks
-- between frames 1 and 2 (so make frame 2 a small "peek" of the tips).
local TABLE_PATH <const> = "images/hazzards/retractingSpikes/retracting-spikes"
local FALLBACK_IMAGE_PATH <const> = "images/hazzards/spikes/spike"
local FALLBACK_FRAMES <const> = 6

-- Matches Spike's hitbox when fully extended (relative to the 32x32 image).
local COLLIDE_RECT <const> = { 5, 10, 12, 12 }

local PHASE_DOWN <const> = 1
local PHASE_RISING <const> = 2
local PHASE_UP <const> = 3
local PHASE_LOWERING <const> = 4

-- Until the real art exists, slide the static spike up out of the floor to fake the frames.
local function buildFallbackFrames()
    local base = gfx.image.new(FALLBACK_IMAGE_PATH)
    local w, h = base:getSize()
    local frames = {}
    for i = 1, FALLBACK_FRAMES do
        local img = gfx.image.new(w, h, gfx.kColorClear)
        local visible = h * (i - 1) / (FALLBACK_FRAMES - 1)
        gfx.pushContext(img)
        base:draw(0, h - visible)
        gfx.popContext()
        frames[i] = img
    end
    return frames
end

local frames -- loaded on first use, shared by every spike
local function getFrames()
    if not frames then
        local imageTable = gfx.imagetable.new(TABLE_PATH)
        if imageTable and #imageTable >= 2 then
            frames = {}
            for i = 1, #imageTable do frames[i] = imageTable:getImage(i) end
        else
            frames = buildFallbackFrames()
        end
    end
    return frames
end

-- Every live spike, so a player respawn can restart them all in sync. Weak keys let spikes
-- from unloaded levels be garbage collected.
local instances = setmetatable({}, { __mode = "k" })

--- Floor spikes that pop up and sink back down on a loop. Retracted for `downTime` frames
--- (rattling for the last `warnTime` of them), animate up, stay up for `upTime` frames, then
--- animate back down. Only deadly while mostly extended. Restarts its cycle on player respawn.
---
--- LDtk fields (all optional):
---   upTime      Int   frames fully extended
---   downTime    Int   frames fully retracted (includes warnTime)
---   warnTime    Int   frames of rattling before rising (0 = no warning)
---   startOffset Int   frames to skip into the cycle, to stagger a row of spikes
---   startUp     Bool  begin the cycle extended instead of retracted
--- @class RetractingSpike : playdate.graphics.sprite
--- @overload fun(...): RetractingSpike
RetractingSpike = {}
class('RetractingSpike').extends(gfx.sprite)

function RetractingSpike:init(x, y, entity)
    self.frames = getFrames()
    self.animLength = (#self.frames - 1) * FRAME_TICKS
    self.deadlyFrame = 1 + math.ceil((#self.frames - 1) * DEADLY_FRACTION)

    local fields = (entity and entity.fields) or {}
    self.upTime = math.max(1, fields.upTime or DEFAULT_UP_TIME)
    self.downTime = math.max(1, fields.downTime or DEFAULT_DOWN_TIME)
    self.warnTime = math.min(math.max(0, fields.warnTime or DEFAULT_WARN_TIME), self.downTime)
    self.startOffset = fields.startOffset or 0
    self.startUp = fields.startUp or false

    self:setZIndex(Z_INDEXES.Hazzard)
    self:setCenter(0, 0)
    self:moveTo(x, y)
    self:setTag(TAGS.Hazzard)
    self:setCollideRect(table.unpack(COLLIDE_RECT))
    self:add()

    instances[self] = true
    self:restartCycle()
end

function RetractingSpike:phaseLength(phase)
    if phase == PHASE_DOWN then return self.downTime end
    if phase == PHASE_UP then return self.upTime end
    return self.animLength
end

-- Puts the spike at the start of its cycle (plus startOffset), wrapping through phases.
function RetractingSpike:restartCycle()
    local cycle = self.downTime + self.upTime + self.animLength * 2
    local phase = self.startUp and PHASE_UP or PHASE_DOWN
    local timer = self.startOffset % cycle
    while timer >= self:phaseLength(phase) do
        timer -= self:phaseLength(phase)
        phase = phase % 4 + 1
    end
    self.phase = phase
    self.timer = timer
    self:refresh()
end

-- Picks the image for the current phase/timer and turns the hitbox on only when it's up enough.
function RetractingSpike:refresh()
    local count = #self.frames
    local frame
    if self.phase == PHASE_DOWN then
        frame = 1
        local warnStart = self.downTime - self.warnTime
        if self.warnTime > 0 and self.timer >= warnStart then
            frame = ((self.timer - warnStart) // WARN_PERIOD) % 2 == 0 and 2 or 1
        end
    elseif self.phase == PHASE_RISING then
        frame = math.min(count, 1 + self.timer // FRAME_TICKS)
    elseif self.phase == PHASE_UP then
        frame = count
    else -- lowering
        frame = math.max(1, count - self.timer // FRAME_TICKS)
    end

    if frame ~= self.frame then
        self.frame = frame
        self:setImage(self.frames[frame])
    end
    -- warning peeks never hurt, only the real rise does
    local deadly = self.phase ~= PHASE_DOWN and frame >= self.deadlyFrame
    self:setCollisionsEnabled(deadly)
end

function RetractingSpike:update()
    self.timer += 1
    if self.timer >= self:phaseLength(self.phase) then
        self.timer = 0
        self.phase = self.phase % 4 + 1
    end
    self:refresh()
end

function RetractingSpike.resetAll()
    for spike in pairs(instances) do
        spike:restartCycle()
    end
end
