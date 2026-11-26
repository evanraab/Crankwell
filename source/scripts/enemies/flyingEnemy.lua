local gfx <const> = playdate.graphics

--- @class FlyingEnemy : Enemy
--- @overload fun(...): FlyingEnemy
FlyingEnemy = {}
class("FlyingEnemy").extends(Enemy)

FlyingEnemy.FLYING_ENEMY_SHEET = "images/enemies/flyingEnemy/flying-enemy-table-32-32"

FlyingEnemy.COLLIDE_RECT = { 6, 12, 20, 18 }

FlyingEnemy.DEFAULT_AMPLITUDE = 20     -- pixels above/below the starting height
FlyingEnemy.DEFAULT_FREQUENCY = 0.05   -- radians of oscillation advanced per frame

FlyingEnemy.DEFAULT_AGGRO_RANGE = 10    -- tiles; player inside this triggers the enemy

-- Center point of any sprite, regardless of its setCenter() anchor
local function getSpriteCenter(sprite)
    local x, y, w, h = sprite:getBounds()
    return x + w / 2, y + h / 2
end

function FlyingEnemy:init(x, y, entity)
    FlyingEnemy.super.init(self, x, y, entity, FlyingEnemy.FLYING_ENEMY_SHEET)

    local fields = entity.fields
    self.affectedByGravity = false   -- flying enemies never fall
    self.fallSpeed = 0

    self.baseY = y
    self.oscillationAmplitude = fields.oscillationAmplitude or FlyingEnemy.DEFAULT_AMPLITUDE
    self.oscillationFrequency = fields.oscillationFrequency or FlyingEnemy.DEFAULT_FREQUENCY
    self.oscillationAngle = 0

    -- LDtk aggroRange is in tiles; stored in pixels
    self.aggroRange = (fields.aggroRange or FlyingEnemy.DEFAULT_AGGRO_RANGE) * Enemy.TILE_SIZE
    self.triggered = false

    -- hover in place until triggered; the LDtk xVelocity becomes the travel speed
    self.moveSpeed = math.abs(self.xVelocity)
    self.xVelocity = 0
end

-- Proximity trigger: once the player is within aggroRange, pick the
-- horizontal direction toward them and commit to it.
function FlyingEnemy:checkTrigger()
    if self.triggered then return end
    local player = self:getPlayer()
    if not player then return end

    local px, py = getSpriteCenter(player)
    local ex, ey = getSpriteCenter(self)
    local dx, dy = px - ex, py - ey
    if dx * dx + dy * dy <= self.aggroRange * self.aggroRange then
        self:onTriggered(dx < 0 and -1 or 1)
    end
end

function FlyingEnemy:onTriggered(dir)
    self.triggered = true
    self.xVelocity = dir * self.moveSpeed
end

-- Replaces falling with a smooth sine-wave bob. The derivative of
-- y = baseY + amplitude * sin(angle) is used as the velocity so the
-- motion stays smooth frame to frame.
function FlyingEnemy:applyGravity()
    if self:isStunned() then
        self.yVelocity = 0
        return
    end

    self:checkTrigger()

    self.oscillationAngle += self.oscillationFrequency
    self.yVelocity = self.oscillationAmplitude * self.oscillationFrequency
        * math.cos(self.oscillationAngle)
end

function FlyingEnemy:setupAnimations()
      self:addState("patrol", 1, 2, {tickStep = 4})
end
