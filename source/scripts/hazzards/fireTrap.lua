local gfx <const> = playdate.graphics

local DEFAULT_ON_TIME <const> = 2  -- seconds the fire stays lit
local DEFAULT_OFF_TIME <const> = 2 -- seconds the fire stays out

--- @class FireTrap : AnimatedSprite
--- @overload fun(...): FireTrap
FireTrap = {}
class('FireTrap').extends(AnimatedSprite)

FireTrap.COLLIDE_RECT = { 0, 0, 20, 20 }


-- LDtk fields (all optional):
--   timed       Bool  - false = always on, true = cycles on/off
--   onTime      Float - seconds lit per cycle
--   offTime     Float - seconds out per cycle
--   startOffset Float - seconds to delay the first switch, to stagger traps
--   startOn     Bool  - whether the trap begins lit
function FireTrap:init(x, y, entity, sheetPath)
    self:setZIndex(Z_INDEXES.Hazzard)
    local imageTable = gfx.imagetable.new("images/hazzards/fire/fireTrap-table-20-20")

    FireTrap.super.init(self, imageTable)

    self:setupAnimations()
    self:playAnimation()

    self:setCenter(0, 0)
    self:moveTo(x, y)
    self:add()

    self:setTag(TAGS.Hazzard)
    self:setCollideRect(table.unpack(self.COLLIDE_RECT))

    local fields = (entity and entity.fields) or {}
    self.fields = fields
    -- array of Enum.Switches values; wrap a single value in case the field isn't an array yet
    local ids = fields.switchId
    if ids == nil then
        ids = {}
    elseif type(ids) ~= "table" then
        ids = { ids }
    end
    self.switchIds = ids

    if fields.switchState ~= nil then
        self:setEnabled(fields.switchState)
        return
    end


    local startOn = fields.startOn ~= false
    self:setEnabled(startOn)

    if fields.timed then
        -- LDtk times are in SECONDS; playdate timers use milliseconds
        self.onMs = (fields.onTime or DEFAULT_ON_TIME) * 1000
        self.offMs = (fields.offTime or DEFAULT_OFF_TIME) * 1000
        local firstPhaseMs = (startOn and self.onMs or self.offMs) + (fields.startOffset or 0) * 1000
        self:scheduleToggle(firstPhaseMs)
    end

end


function FireTrap:setupAnimations()
    self:addState("idle", 1, 2, {tickStep = 4})
end


-- Lit traps are visible and kill on contact; unlit traps are hidden and harmless
function FireTrap:setEnabled(enabled)
    self.enabled = enabled
    self:setVisible(enabled)
    self:setCollisionsEnabled(enabled)
end


function FireTrap:scheduleToggle(delayMs)
    self.toggleTimer = playdate.timer.new(delayMs, function()
        self:setEnabled(not self.enabled)
        self:scheduleToggle(self.enabled and self.onMs or self.offMs)
    end)
end


-- Stop the cycle when the level unloads this sprite, otherwise the timer keeps running
function FireTrap:remove()
    if self.toggleTimer then
        self.toggleTimer:remove()
        self.toggleTimer = nil
    end
    FireTrap.super.remove(self)
end

function FireTrap:listensTo(switchId)
    for _, id in ipairs(self.switchIds) do
        if id == switchId then return true end
    end
    return false
end

function FireTrap:onSwitchActivated()
    if self.toggleTimer then
        self.toggleTimer:remove()
        self.toggleTimer = nil
    end
    self:setEnabled(not self.enabled)
    self.fields.switchState = self.enabled
end


