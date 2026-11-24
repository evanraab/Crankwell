local gfx <const> = playdate.graphics

--- @class BigHelmet : Boss
--- @overload fun(...): BigHelmet
BigHelmet = {}
class('BigHelmet').extends(Boss)

local SIZE <const> = 64

local CHARGE_RANGE <const> = 160   -- how far ahead the boss can see
local VERTICAL_TOLERANCE <const> = 24  -- player must be roughly on the boss's level
local CHARGE_COOLDOWN_TIME =  90

local CRASH_PAUSE_FRAMES <const> = 30   -- boss sits still after a charge (~1s at 30 fps)
local TURN_PAUSE_FRAMES <const> = 10    -- short beat after flipping before it walks off
local CRASH_SHAKE_MAGNITUDE <const> = 6
local CRASH_SHAKE_FRAMES <const> = 15
local SHEET <const> = "images/bosses/test/mm_wheelie/big-helmet-table-64-64"
local HURT_FRAMES <const> = 120  -- how long the boss stays stunned after a slam
local VULNERABLE_FRAMES <const> = 120  -- window to jump/slam for damage after the second slam
local FLICKER_FRAMES <const> = 40      -- warning flicker at the end of the window
local FLICKER_INTERVAL <const> = 3
local SLAM_HITSTOP_FRAMES <const> = 6  -- quick freeze when a slam lands
local HIT_COOLDOWN <const> = 12        -- min frames between hit points lost while vulnerable
local HIT_FLASH_FRAMES <const> = 8     -- inverted flash on each hit
local HIT_FLASH_INTERVAL <const> = 2
-- speed multiplier per phase; phases split the boss's hit points into thirds
local PHASE_SPEED <const> = { 1, 1.35, 1.7 }
local GUARD_FRAMES <const> = 60        -- can't be slammed into hurt right after returning to patrol
local GUARD_BLINK_INTERVAL <const> = 4
local ChargeState = {}
local CrashState = {}
local HurtState = {}
local VulnerableState = {}

function BigHelmet:init(x, y, entity)
    -- LDtk's entity box is smaller than the 64px sprite; line up the bottoms
    -- so the boss spawns standing on the floor instead of sunk into it
    y = y + (entity.size and entity.size.height or SIZE) - SIZE
    BigHelmet.super.init(self, x, y, entity, SHEET)
    self:setCollideRect(8, 16, 48, 48) -- offset the hit box for player to hit more easily
    self.fsm:add("charge", ChargeState) -- attack states that only this boss has
    self.fsm:add("crash", CrashState)
    self.fsm:add("hurt", HurtState)
    self.fsm:add("vulnerable", VulnerableState)

    -- hits while vulnerable keep it vulnerable (short cooldown between hits)
    -- instead of sending it to the base recover state
    local defaultOnDamaged = self.health.onDamaged
    self.health.onDamaged = function(current, max)
        self:updatePhase()
        if self:isVulnerable() then
            self.health.invulnerableTimer = HIT_COOLDOWN
        else
            defaultOnDamaged(current, max)
        end
    end

    self.flashTimer = 0
    self.guardTimer = 0

    local fields = entity.fields
    self.baseChargeSpeed = math.abs(fields.xVelocity) * 2
    self.chargeSpeed = self.baseChargeSpeed
    self.chargeCooldown = 0
    self.phase = 1
end

-- 1 = full health, 2 = two thirds or less, 3 = one third or less
function BigHelmet:currentPhase()
    local h = self.health
    if h.current > h.max * 2 / 3 then return 1 end
    if h.current > h.max / 3 then return 2 end
    return 3
end

-- Speeds up walking and charging when the boss drops into a new phase
function BigHelmet:updatePhase()
    local phase = self:currentPhase()
    if phase == self.phase then return end
    self.phase = phase
    local mult = PHASE_SPEED[phase]
    self.walkSpeed = self.baseSpeed * mult
    self.chargeSpeed = self.baseChargeSpeed * mult
end


function BigHelmet:afterMove(prevX, prevY)
    local x = self:getPosition()
    self.distanceTraveled += math.abs(x - prevX)

    local atLimit = self.maxDistance and self.distanceTraveled >= self.maxDistance
    local ledge = self.isLedgeEnemy and not self:isGroundAhead()

    if atLimit or ledge then
        self.xVelocity = -self.xVelocity
        self:resetDistanceTraveled()
    end

     if self:canCharge() then
           self.fsm:change("charge")
       end
   end

   function BigHelmet:canCharge()
       return self.chargeCooldown <= 0 and self:playerInFront()
end

function BigHelmet:playerInFront()
    local player = self:getPlayer()

    if not player then return false end
    local px, py = player:getPosition()   -- your player sprite
    local bx, by = self:getPosition()

    -- both centers are (0,0), so these are top-left; compare centers instead
    local bossCenterX = bx + 24
    local bossCenterY = by + 16
    local dx = px - bossCenterX
    local dy = py - bossCenterY

    local inFront = (self:moveDir() == 1 and dx > 0) or (self:moveDir() == -1 and dx < 0)
    return inFront
        and math.abs(dx) <= CHARGE_RANGE
        and math.abs(dy) <= VERTICAL_TOLERANCE
end

-- Returns true if there is solid ground just ahead of the leading foot
function BigHelmet:isGroundAhead()
    local x, y = self:getPosition() -- top-left, since center is (0, 0)
    local probeX = (self.xVelocity > 0) and (x + SIZE + 1) or (x - 2)
    local probeY = y + SIZE + 2

    local sprites = gfx.sprite.querySpritesAtPoint(probeX, probeY)
    local found = false
    for i = 1, #sprites do
        local tag = sprites[i]:getTag()
        if tag ~= TAGS.Enemy and tag ~= TAGS.Player then
            found = true
            break
        end
    end
    return found
end

function BigHelmet:moveDir()
    if self.xVelocity ~= 0 then
        self.lastMoveDir = self.xVelocity < 0 and -1 or 1
    end
    return self.lastMoveDir or 1
end

function ChargeState:enter(boss)
    boss:changeState("charge") -- animation state
    boss.chargeDir = boss:moveDir()
    boss.xVelocity = boss.chargeDir * boss.chargeSpeed
end

-- Charges until the boss slams into a wall (the end of the room)
function ChargeState:update(boss)
    boss:updateAnimation()
    boss:updateFacing()
    local prevX, prevY = boss:getPosition()
    boss:applyGravity()
    local hitWall = boss:moveAndCollide(prevX, prevY)

    if hitWall then
        boss.fsm:change("crash")
    end
end

function CrashState:enter(boss)
    boss.xVelocity = 0
    boss.crashTimer = CRASH_PAUSE_FRAMES
    boss.turned = false
    -- after the pause it walks back the way it came
    boss.savedXVelocity = -boss.chargeDir * boss.walkSpeed

    local player = boss:getPlayer()
    local scene = player and player.gameManager
    if scene and scene.camera then
        scene.camera:shake(CRASH_SHAKE_MAGNITUDE, CRASH_SHAKE_FRAMES)
    end
end

function CrashState:update(boss)
    boss:applyGravity()
    boss:moveAndCollide(boss:getPosition())

    boss.crashTimer -= 1
    if boss.crashTimer > 0 then return end

    if not boss.turned then
        -- flip to face the way it will walk, then hold briefly before moving
        boss.turned = true
        boss.crashTimer = TURN_PAUSE_FRAMES
        boss:setFacing(boss.savedXVelocity < 0 and 1 or -1) -- same convention as Enemy:updateFacing
        return
    end

    boss.chargeCooldown = CHARGE_COOLDOWN_TIME
    boss.fsm:change("patrol")
    boss.xVelocity = boss.savedXVelocity
end

function HurtState:enter(boss)
    if boss.xVelocity ~= 0 then
        boss.savedXVelocity = boss.xVelocity
    end
    boss.xVelocity = 0
    boss.hurtTimer = HURT_FRAMES
    boss.canHurtPlayer = false
    boss:changeState("hurt") -- animation state
end

function HurtState:update(boss)
    boss:updateAnimation()
    boss:applyGravity()
    boss:moveAndCollide(boss:getPosition())

    boss.hurtTimer -= 1
    if boss.hurtTimer <= FLICKER_FRAMES then
        boss:setVisible(math.floor(boss.hurtTimer / FLICKER_INTERVAL) % 2 == 0)
    end

    if boss.hurtTimer <= 0 then
        boss:returnToPatrol()
    end
end

function HurtState:exit(boss)
    boss:setVisible(true)
    boss.canHurtPlayer = true
    boss:changeState("patrol")
end

-- Second slam while hurt: stays stopped, open to a jump or slam for damage
function VulnerableState:enter(boss)
    if boss.xVelocity ~= 0 then
        boss.savedXVelocity = boss.xVelocity
    end
    boss.xVelocity = 0
    boss.vulnerableTimer = VULNERABLE_FRAMES
    boss.canHurtPlayer = false
    boss:changeState("vulnerable") -- animation state
end

function VulnerableState:update(boss)
    boss:updateAnimation()
    boss:applyGravity()
    boss:moveAndCollide(boss:getPosition())

    boss.vulnerableTimer -= 1
    if boss.vulnerableTimer <= FLICKER_FRAMES then
        boss:setVisible(math.floor(boss.vulnerableTimer / FLICKER_INTERVAL) % 2 == 0)
    end

    if boss.vulnerableTimer <= 0 then
        boss:returnToPatrol()
    end
end

function VulnerableState:exit(boss)
    boss:setVisible(true)
    boss.canHurtPlayer = true
    boss:changeState("patrol")
end

function BigHelmet:update()
    BigHelmet.super.update(self)
    self:updateHitFlash()
    self:updateGuard()
end

-- Back to patrol after hurt/vulnerable, with a short guard window where slams don't stun it
function BigHelmet:returnToPatrol()
    self.fsm:change("patrol")
    -- resume the way it was walking before the slam (patrol's enter picks its own direction)
    local dir = (self.savedXVelocity or 1) < 0 and -1 or 1
    self.xVelocity = dir * self.walkSpeed
    self.guardTimer = GUARD_FRAMES
end

function BigHelmet:isGuarded()
    return self.guardTimer > 0
end

-- Blinks while guarded so the player can tell slams won't work yet
function BigHelmet:updateGuard()
    if self.guardTimer <= 0 then return end
    self.guardTimer -= 1
    self:setVisible(self.guardTimer == 0 or math.floor(self.guardTimer / GUARD_BLINK_INTERVAL) % 2 == 0)
end

-- Briefly flash the sprite inverted to show a hit landed
function BigHelmet:hitFlash()
    self.flashTimer = HIT_FLASH_FRAMES
end

function BigHelmet:updateHitFlash()
    if self.flashTimer <= 0 then return end
    self.flashTimer -= 1
    local inverted = self.flashTimer > 0 and math.floor(self.flashTimer / HIT_FLASH_INTERVAL) % 2 == 0
    self:setImageDrawMode(inverted and gfx.kDrawModeInverted or gfx.kDrawModeCopy)
end

function BigHelmet:isHurt()
    return self.fsm.currentName == "hurt"
end

function BigHelmet:isVulnerable()
    return self.fsm.currentName == "vulnerable"
end

-- Costs a hit point; the boss stays vulnerable until its timer runs out (or it dies)
function BigHelmet:hitWhileVulnerable()
    if self.health:damage(1) then
        self:hitFlash()
    end
end

-- A normal jump only hurts while vulnerable; otherwise it's a plain bounce
function BigHelmet:onStomped()
    if self:isVulnerable() then
        self:hitWhileVulnerable()
    end
    return true
end

-- Slam: patrol/charge/crash -> hurt (unless guarded), hurt -> vulnerable, vulnerable -> damage
function BigHelmet:onSlammed()
    local state = self.fsm.currentName
    if state == "vulnerable" then
        self:hitWhileVulnerable()
    elseif state == "hurt" then
        self.fsm:change("vulnerable")
        HitStop.start(SLAM_HITSTOP_FRAMES)
    elseif not self:isGuarded() and (state == "patrol" or state == "charge" or state == "crash") then
        self.fsm:change("hurt")
        HitStop.start(SLAM_HITSTOP_FRAMES)
    end
    return {
        velocity = -8,
        xPush = 3,
    }
end


function BigHelmet:setupAnimations()
    BigHelmet.super.setupAnimations(self)
    self:addState("charge", 1,4, {tickStep = 2})
end

function BigHelmet:nonDamageOrStunHit()
    self.canHurtPlayer = false
end