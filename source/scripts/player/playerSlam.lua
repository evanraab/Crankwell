-- slam properties
local SLAM_CRANK_THRESHOLD = 12 -- degrees per frame, backwards
local SLAM_CRANK_THRESHOLD_WHILE_IN_OTHER_STATE = 20;
-- Slowing/stopping the crank often produces a brief backswing, so require the reverse to be
-- sustained and keep the stricter threshold for a short while after fluttering stops.
local SLAM_REVERSE_FRAMES = 2
local SLAM_FLUTTER_GRACE_FRAMES = 10
local SLAM_SPEED = 16

local TILE_SIZE = LevelConfig.TILE_SIZE
local SLAM_MIN_DISTANCE = 3 * TILE_SIZE
local SLAM_PROBE_LENGTH = 240

local SLAM_FREEZE_FRAMES = 16  -- a bit longer so the flip reads; tune by feel

local gfx <const> = playdate.graphics


--- @class PlayerSlam
PlayerSlam = {}
class('PlayerSlam').extends()

function PlayerSlam:init(player)
    self.player = player

    -- slam state: nil, "freeze" or "drop"
    self.slamPhase = nil
    self.slamFreezeTimer = 0
    self.slamReverseFrames = 0
    self.slamFlutterGraceTimer = 0
    self.slamming = true
    self.powered = false
    self.spinDir = 1

end

-- 0..1 across the somersault, nil when not in freeze
function PlayerSlam:getSpinProgress()
    if self.slamPhase ~= "freeze" then return nil end
    return 1 - (self.slamFreezeTimer / SLAM_FREEZE_FRAMES)
end

function PlayerSlam:isPowerSlamming()
    return self.slamPhase == "drop" and self.powered
end

-- Runs after handleState so it overrides any input/drag/gravity velocity changes.
function PlayerSlam:updateSlam(player, flutter)
    self:updateBreakableHint()

    if not self.slamPhase then
        -- self.fluttering still holds last frame's value here (updateFlutterState runs later)
        if flutter.fluttering then
            self.slamFlutterGraceTimer = SLAM_FLUTTER_GRACE_FRAMES
        elseif self.slamFlutterGraceTimer > 0 then
            self.slamFlutterGraceTimer -= 1
        end

        local threshold = self.slamFlutterGraceTimer > 0 and SLAM_CRANK_THRESHOLD_WHILE_IN_OTHER_STATE or SLAM_CRANK_THRESHOLD
        local airborne = (not player.grounded) and (not player.touchingGround)
        if airborne and IsCrankingBackFast(threshold) then
            self.slamReverseFrames += 1
        else
            self.slamReverseFrames = 0
        end

        if self.slamReverseFrames >= SLAM_REVERSE_FRAMES then
            self.slamReverseFrames = 0
            self.slamPhase = "freeze"
            self.slamFreezeTimer = SLAM_FREEZE_FRAMES
            self.spinDir = (player.globalFlip == 1) and -1 or 1  -- lock direction for the whole spin

            flutter:cancelFlutterAndGlide()
            if player.currentState ~= "fall" then
                player:changeToFallState() -- change to fall/slam animation
            end
        else
            return
        end
    end

    if self.slamPhase == "freeze" then
        -- check if distance between ground and player is enough for full slam effects
        self.powered = self:distanceToGround() >= SLAM_MIN_DISTANCE
        player.xVelocity = 0
        player.yVelocity = 0
        self.slamFreezeTimer -= 1
        if self.slamFreezeTimer <= 0 then
            self.slamPhase = "drop"
        end
    else
        player.xVelocity = 0
        player.yVelocity = SLAM_SPEED
    end
end

function PlayerSlam:updateSlammingFlag(value)
    self.slamming = value
end

local function isGround(sprite)
    local tag = sprite:getTag()
    return tag ~= TAGS.Hazzard and tag ~= TAGS.Enemy and tag ~= TAGS.Pickup
end

function PlayerSlam:distanceToGround()
    return (self:probeGround())
end

-- Returns the distance to the nearest ground below the feet and the breakable blocks
-- that are the first ground hit under either foot.
function PlayerSlam:probeGround()
    local player = self.player
    -- getCollideBounds is relative to the sprite, so convert to world coordinates
    local rx, ry, bw, bh = player:getCollideBounds()
    local spriteX, spriteY = player:getBounds()
    local bx, by = spriteX + rx, spriteY + ry
    local bottom = by + bh
    local best = math.huge
    local breakables = {}

    -- probe both feet so a ledge under one edge still counts
    for _, x in ipairs({ bx + 1, bx + bw - 1 }) do
        local hits = gfx.sprite.querySpriteInfoAlongLine(x, bottom, x, bottom + SLAM_PROBE_LENGTH)
        for _, info in ipairs(hits) do
            if info.sprite ~= player and isGround(info.sprite) then
                best = math.min(best, math.max(0, info.entryPoint.y - bottom))
                if info.sprite:getTag() == TAGS.Breakable then
                    breakables[#breakables + 1] = info.sprite
                end
                break -- results are sorted by distance, first ground hit is enough
            end
        end
    end
    return best, breakables
end

-- Flashes the breakable blocks below (and everything connected to them) while the player
-- is high enough for a power slam to break them.
function PlayerSlam:updateBreakableHint()
    local player = self.player
    local targets = nil

    local airborne = (not player.grounded) and (not player.touchingGround)
    if airborne and self.slamPhase ~= "drop" then
        local distance, breakables = self:probeGround()
        if distance >= SLAM_MIN_DISTANCE and #breakables > 0 then
            targets = self:getHintTargets(breakables)
        end
    end

    if self.hintTargets and self.hintTargets ~= targets then
        for block in pairs(self.hintTargets) do
            block:setFlashing(false)
        end
    end
    self.hintTargets = targets
    if targets then
        for block in pairs(targets) do
            block:setFlashing(true)
        end
    end
end

-- Rebuilds the connected set only when the blocks under the feet change.
function PlayerSlam:getHintTargets(breakables)
    local cache = self.hintCache
    local same = cache and #cache.sources == #breakables
    if same then
        for i, block in ipairs(breakables) do
            if cache.sources[i] ~= block then same = false break end
        end
    end
    if same then return cache.targets end

    local targets = {}
    for _, block in ipairs(breakables) do
        for connected in pairs(block:getConnectedBlocks()) do
            targets[connected] = true
        end
    end
    self.hintCache = { sources = breakables, targets = targets }
    return targets
end