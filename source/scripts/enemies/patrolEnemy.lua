local gfx <const> = playdate.graphics

--- @class PatrolEnemy : Enemy
--- @overload fun(...): PatrolEnemy
PatrolEnemy = {}
class("PatrolEnemy").extends(Enemy)

PatrolEnemy.PATROL_ENEMY_SHEET = "images/enemies/enemy-table-16-16"

PatrolEnemy.DEBUG = false
local debugProbes = {}

function PatrolEnemy:init(x, y, entity, sheetPath)
    PatrolEnemy.super.init(self, x, y, entity, sheetPath)
    -- the LDtk maxDistance field is in tiles; distanceTraveled is tracked in pixels
    if self.maxDistance then
        self.maxDistance *= Enemy.TILE_SIZE
    end
end

function PatrolEnemy:update()
    self:checkLedge()

    local prevX, prevY = self:getPosition()
    PatrolEnemy.super.update(self)
    -- check if enemy is a ledge check to control direction since having both breaks the patrol
    if not self.isLedgeEnemy then
        self:patrol(prevX, prevY)
    end
end

-- Returns true if there is solid ground just ahead of the leading foot
function PatrolEnemy:isGroundAhead()
    local x, y = self:getPosition() -- top-left, since center is (0, 0)
    -- probe from the collide rect (not the image size) so it tracks the enemy's actual feet
    local cx, cy, cw, ch = self:getCollideRect():unpack()
    local left, right, bottom = x + cx, x + cx + cw, y + cy + ch
    local probeX = (self.xVelocity > 0) and (right + 1) or (left - 2)
    local probeY = bottom + 2

    local sprites = gfx.sprite.querySpritesAtPoint(probeX, probeY)
    local found = false
    for i = 1, #sprites do
        local tag = sprites[i]:getTag()
        if tag ~= TAGS.Enemy and tag ~= TAGS.Player then
            found = true
            break
        end
    end

    if PatrolEnemy.DEBUG then
        debugProbes[#debugProbes + 1] = { x = probeX, y = probeY, found = found }
    end
    return found
end


function PatrolEnemy:checkLedge()
    -- only ground walkers that are currently standing on something
    if not self.affectedByGravity or not self.onGround or self.xVelocity == 0 then
        return
    end

    if not self:isGroundAhead() then
        self.xVelocity *= -1
        self:resetDistanceTraveled()
    end
   
end

function PatrolEnemy:patrol(prevX, prevY)
    local x, y = self:getPosition()
    local dx, dy = x - prevX, y - prevY

    if self.patrolAxis == "x" then
        self.distanceTraveled += math.abs(dx)
    elseif self.patrolAxis == "y" then
        self.distanceTraveled += math.abs(dy)
    else
        self.distanceTraveled += math.sqrt(dx * dx + dy * dy)
    end

    if self.maxDistance and self.maxDistance > 0
       and self.distanceTraveled >= self.maxDistance then
        self.distanceTraveled -= self.maxDistance  -- keep overshoot

        if self.patrolAxis ~= "y" then
            self.xVelocity = -self.xVelocity
        end
        if self.patrolAxis ~= "x" then
            self.yVelocity = -self.yVelocity
        end
    end
end

-- Call after gfx.sprite.update() while the camera draw offset is active.
-- Filled square = ground found, hollow square = no ground (enemy will turn around).
function PatrolEnemy.drawDebug()
    gfx.setColor(gfx.kColorXOR)
    for i = 1, #debugProbes do
        local p = debugProbes[i]
        if p.found then
            gfx.fillRect(p.x - 2, p.y - 2, 5, 5)
        else
            gfx.drawRect(p.x - 2, p.y - 2, 5, 5)
        end
    end
    debugProbes = {}
end