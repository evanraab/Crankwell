local pd <const> = playdate
local gfx <const> = playdate.graphics

-- Burst tuning
local PARTICLE_COUNT <const> = 18
local MIN_SPEED <const> = 1.5
local MAX_SPEED <const> = 4.5
local UPWARD_BIAS <const> = -1.5   -- added to every particle's starting vy so the burst pops upward
local GRAVITY <const> = 0.25
local DRAG <const> = 0.97          -- per-frame velocity multiplier
local MIN_LIFE <const> = 14        -- frames; keep MAX_LIFE under Player's DEATH_RESPAWN_DELAY (~21 frames at 30fps)
local MAX_LIFE <const> = 22
local BLINK_FRAMES <const> = 8    -- particles flicker for their last few frames before vanishing
local RADII <const> = { 1, 2, 2, 3 }

-- Pre-render each particle size once: a white dot with a black rim so it reads on dark and light tiles.
local particleImages = {}
for _, r in ipairs(RADII) do
    if not particleImages[r] then
        local size = (r + 1) * 2
        local img = gfx.image.new(size, size)
        gfx.pushContext(img)
        gfx.setColor(gfx.kColorBlack)
        gfx.fillCircleAtPoint(r + 1, r + 1, r + 1)
        gfx.setColor(gfx.kColorWhite)
        gfx.fillCircleAtPoint(r + 1, r + 1, r)
        gfx.popContext()
        particleImages[r] = img
    end
end

--- @class DeathParticle : playdate.graphics.sprite
--- @overload fun(...): DeathParticle
DeathParticle = {}
class('DeathParticle').extends(gfx.sprite)

function DeathParticle:init(x, y)
    local r = RADII[math.random(#RADII)]
    DeathParticle.super.init(self, particleImages[r])

    local angle = math.random() * 2 * math.pi
    local speed = MIN_SPEED + math.random() * (MAX_SPEED - MIN_SPEED)
    self.vx = math.cos(angle) * speed
    self.vy = math.sin(angle) * speed + UPWARD_BIAS
    self.px = x
    self.py = y
    self.life = math.random(MIN_LIFE, MAX_LIFE)

    self:setZIndex(Z_INDEXES.Player + 1)
    self:moveTo(x, y)
    self:add()
end

function DeathParticle:update()
    self.life -= 1
    if self.life <= 0 then
        self:remove()
        return
    end

    self.vy += GRAVITY
    self.vx *= DRAG
    self.vy *= DRAG
    self.px += self.vx
    self.py += self.vy
    self:moveTo(self.px, self.py)

    if self.life <= BLINK_FRAMES then
        self:setVisible(self.life % 2 == 0)
    end
end

DeathParticles = {}

--- Spawns a burst of debris particles centred on (x, y) in world space.
function DeathParticles.burst(x, y)
    for _ = 1, PARTICLE_COUNT do
        DeathParticle(x, y)
    end
end
