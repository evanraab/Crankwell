local gfx <const> = playdate.graphics

local TILE_SIZE <const> = 20
local DEFAULT_SPEED <const> = 1         -- px per frame
local DEFAULT_PAUSE_FRAMES <const> = 30 -- wait at each end of the path

-- Loaded images, keyed by path, shared by every platform that uses them.
local imageCache = {}
local function loadImage(path)
    local img = imageCache[path]
    if img == nil then
        img = gfx.image.new(path) or false -- false = known missing, don't retry
        imageCache[path] = img
    end
    return img or nil
end

-- Picks the art for a platform `tiles` wide: "<base>-<N>-tiles" if that file exists
-- (e.g. default-platform-3-tiles), otherwise the base image.
local function getPlatformImage(basePath, tiles)
    return loadImage(basePath .. "-" .. tiles .. "-tiles")
        or assert(loadImage(basePath), "Missing platform image: " .. basePath)
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

-- The platform's art; its size is the platform's size. Subclasses override this with their own.
-- Size variants live next to it as "<imagePath>-<N>-tiles" and are chosen by the LDtk entity width.
MovingPlatform.imagePath = "images/platforms/defaultPlatform/default-platform"

function MovingPlatform:init(x, y, entity)
    MovingPlatform.super.init(self)

    -- Width comes from how wide the entity is drawn in LDtk; pick the art made for that size.
    local tiles = entity.size and math.floor(entity.size.width / TILE_SIZE + 0.5) or 2
    self:setImage(getPlatformImage(self.imagePath, tiles))
    local w, h = self:getSize()
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

    self:moveAlongPath(riders)
end

-- Moves to the point `self.progress` px along the path, carrying `riders` and shoving anything we run into.
function MovingPlatform:moveAlongPath(riders)
    local t = self.progress / self.pathLength
    local newX = self.startX + (self.endX - self.startX) * t
    local newY = self.startY + (self.endY - self.startY) * t
    local dx, dy = newX - self.x, newY - self.y
    if dx == 0 and dy == 0 then return end

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
