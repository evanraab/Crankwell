local gfx <const> = playdate.graphics

--- @class DeathParticleStyle
--- @field count integer        particles per burst
--- @field minSpeed number      starting speed range, px/frame
--- @field maxSpeed number
--- @field upwardBias number    added to every particle's starting vy so the burst pops upward
--- @field gravity number       px/frame² pulled down each frame
--- @field drag number          per-frame velocity multiplier
--- @field minLife integer      lifetime range, frames
--- @field maxLife integer
--- @field blinkFrames integer  particles flicker for their last few frames before vanishing
--- @field radii integer[]      dot radii to pick from at random (1-3)

DeathParticles = {}

-- Player death: big, lively burst. Keep maxLife under Player's DEATH_RESPAWN_DELAY (~21 frames at 30fps).
--- @type DeathParticleStyle
DeathParticles.PLAYER = {
    count = 18,
    minSpeed = 1.5,
    maxSpeed = 4.5,
    upwardBias = -1.5,
    gravity = 0.25,
    drag = 0.97,
    minLife = 14,
    maxLife = 22,
    blinkFrames = 8,
    radii = { 1, 2, 2, 3 },
}

-- Regular enemy death: a small, quick pop so frequent kills don't get noisy.
--- @type DeathParticleStyle
DeathParticles.ENEMY = {
    count = 8,
    minSpeed = 1.0,
    maxSpeed = 2.5,
    upwardBias = -1.0,
    gravity = 0.2,
    drag = 0.92,
    minLife = 8,
    maxLife = 14,
    blinkFrames = 4,
    radii = { 1, 1, 2 },
}

-- Boss death: the player-sized burst, with more debris.
--- @type DeathParticleStyle
DeathParticles.BOSS = setmetatable({ count = 30 }, { __index = DeathParticles.PLAYER })

-- Pre-render each particle size once: a white dot with a black rim so it reads on dark and light tiles.
local particleImages = {}
for r = 1, 3 do
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

--- @class DeathParticle : playdate.graphics.sprite
--- @overload fun(...): DeathParticle
DeathParticle = {}
class('DeathParticle').extends(gfx.sprite)

--- @param style DeathParticleStyle
function DeathParticle:init(x, y, style)
    local r = style.radii[math.random(#style.radii)]
    DeathParticle.super.init(self, particleImages[r])

    local angle = math.random() * 2 * math.pi
    local speed = style.minSpeed + math.random() * (style.maxSpeed - style.minSpeed)
    self.style = style
    self.vx = math.cos(angle) * speed
    self.vy = math.sin(angle) * speed + style.upwardBias
    self.px = x
    self.py = y
    self.life = math.random(style.minLife, style.maxLife)

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

    local style = self.style
    self.vy += style.gravity
    self.vx *= style.drag
    self.vy *= style.drag
    self.px += self.vx
    self.py += self.vy
    self:moveTo(self.px, self.py)

    if self.life <= style.blinkFrames then
        self:setVisible(self.life % 2 == 0)
    end
end

--- Spawns a burst of debris particles centred on (x, y) in world space.
--- @param style? DeathParticleStyle defaults to DeathParticles.PLAYER
function DeathParticles.burst(x, y, style)
    style = style or DeathParticles.PLAYER
    for _ = 1, style.count do
        DeathParticle(x, y, style)
    end
end
