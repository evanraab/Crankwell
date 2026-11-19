local gfx <const> = playdate.graphics

local TILE_SIZE <const> = 20
local DEFAULT_SPEED <const> = 1         -- px per frame
local DEFAULT_PAUSE_FRAMES <const> = 30 -- wait at each end of the path

-- Placeholder art, drawn to whatever size the platform was given in LDtk:
-- a white frame with a dithered fill so it reads against the black background.
local function makePlatformImage(w, h)
    local img = gfx.image.new(w, h, gfx.kColorClear)
    gfx.pushContext(img)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(0, 0, w, h)
    gfx.setColor(gfx.kColorBlack)
    gfx.setDitherPattern(0.5, gfx.image.kDitherTypeBayer2x2)
    gfx.fillRect(2, 2, w - 4, h - 4)
    gfx.popContext()
    return img
end

local function rectsOverlap(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and bx < ax + aw and ay < by + bh and by < ay + ah
end

--- A solid platform that travels back and forth between its LDtk position and `endPoint`,
--- carrying the player and any enemies standing on it.
---
--- LDtk fields (all optional):
---   endPoint    Point  grid cell the platform's top-left travels to (no point = stays still)
---   speed       Float  px per frame
---   pauseFrames Int    frames to wait at each end
--- @class MovingPlatform : playdate.graphics.sprite
--- @overload fun(...): MovingPlatform
MovingPlatform = {}
class('MovingPlatform').extends(gfx.sprite)

function MovingPlatform:init(x, y, entity)
    MovingPlatform.super.init(self)

    local w = entity.size and entity.size.width or 3 * TILE_SIZE
    local h = entity.size and entity.size.height or TILE_SIZE
    self:setImage(makePlatformImage(w, h))
    self:setCenter(0, 0)
    self:moveTo(x, y)
    self:setCollideRect(0, 0, w, h)
    self:setTag(TAGS.Platform)
    self:setZIndex(Z_INDEXES.Platform)

    local fields = entity.fields or {}
    self.speed = fields.speed or DEFAULT_SPEED
    self.pauseFrames = fields.pauseFrames or DEFAULT_PAUSE_FRAMES

    -- endPoint is in the level's grid cells; x, y are world pixels, so rebase via the level origin
    self.startX, self.startY = x, y
    local endPoint = fields.endPoint
    if endPoint then
        local levelX = x - entity.position.x
        local levelY = y - entity.position.y
        self.endX = levelX + endPoint.cx * TILE_SIZE
        self.endY = levelY + endPoint.cy * TILE_SIZE
    else
        self.endX, self.endY = x, y
    end

    self.pathLength = math.sqrt((self.endX - x) ^ 2 + (self.endY - y) ^ 2)
    self.progress = 0      -- px travelled along the path from start
    self.direction = 1     -- 1 = towards end, -1 = back to start
    self.pauseTimer = self.pauseFrames
    self.riders = {}       -- sprites standing on us this frame; they re-register every frame via addRider

    self:add()
end

-- Called by the player and enemies when they land on (or keep standing on) this platform.
function MovingPlatform:addRider(sprite)
    self.riders[sprite] = true
end

local function isCrushable(s)
    local tag = s:getTag()
    return (tag == TAGS.Player or tag == TAGS.Enemy) and not s.dead
end

function MovingPlatform:update()
    local riders = self.riders
    self.riders = {}

    if self.pathLength == 0 then return end

    if self.pauseTimer > 0 then
        self.pauseTimer -= 1
        return
    end

    self.progress += self.speed * self.direction
    if self.progress >= self.pathLength then
        self.progress = self.pathLength
        self.direction = -1
        self.pauseTimer = self.pauseFrames
    elseif self.progress <= 0 then
        self.progress = 0
        self.direction = 1
        self.pauseTimer = self.pauseFrames
    end

    local t = self.progress / self.pathLength
    local newX = self.startX + (self.endX - self.startX) * t
    local newY = self.startY + (self.endY - self.startY) * t
    local dx, dy = newX - self.x, newY - self.y

    -- Move with our own collisions off so riders aren't blocked by us while being carried
    -- or shoved; walls still stop them.
    self:setCollisionsEnabled(false)

    for rider in pairs(riders) do
        if not rider.dead then
            rider:moveWithCollisions(rider.x + dx, rider.y + dy)
        end
    end

    self:moveTo(newX, newY)
    self:pushOverlapping(dx, dy)

    self:setCollisionsEnabled(true)
end

-- If we moved into the player or an enemy (from the side or below), shove them along with us.
-- If a wall stops them, they're crushed.
function MovingPlatform:pushOverlapping(dx, dy)
    local px, py, pw, ph = self:getBounds()
    for _, s in ipairs(gfx.sprite.querySpritesInRect(px, py, pw, ph)) do
        if isCrushable(s) then
            s:moveWithCollisions(s.x + dx, s.y + dy)
            local sx, sy, sw, sh = s:getCollideBounds()
            local bx, by = s:getBounds()
            if rectsOverlap(bx + sx, by + sy, sw, sh, px, py, pw, ph) then
                if s:getTag() == TAGS.Player then
                    s:die()
                else
                    s:damageEnemy()
                end
            end
        end
    end
end
