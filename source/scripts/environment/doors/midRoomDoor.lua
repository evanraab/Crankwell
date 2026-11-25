local pd <const> = playdate
local gfx <const> = pd.graphics

-- A door in the middle of a room. Stand in front of it and press Up: it plays its
-- opening animation, the screen fades, and the player comes out at the door its
-- LDtk `target` field points to (usually in another room).
--
-- LDtk fields:
--   target  Entity ref - the door to come out of (point it at another MidRoomDoor)
--   opened  Bool       - optional; set at runtime so the door stays open when the room reloads

--- @class MidRoomDoor : Door
--- @overload fun(...): MidRoomDoor
MidRoomDoor = {}
class("MidRoomDoor").extends(Door)

-- 3 frames of 20x20: closed -> opening -> open
local doorFrames <const> = gfx.imagetable.new("images/doors/door-table-20-20")
assert(doorFrames, "missing images/doors/door-table-20-20.png")

local CLOSED_FRAME <const> = 1
local OPEN_FRAME <const> = #doorFrames
local FRAME_MS <const> = 80

function MidRoomDoor:init(x, y, entity)
    self.iid = entity.iid
    self.target = entity.fields.target
    -- Door:init skips doors whose `unlocked` field is true, so this door keeps
    -- its open state in `opened` instead
    local frame = entity.fields.opened and OPEN_FRAME or CLOSED_FRAME
    MidRoomDoor.super.init(self, x, y, entity, doorFrames[frame])
    -- overlap, not solid: the player walks in front of the door
    self:setTag(TAGS.Interactable)
end

function MidRoomDoor:update()
    MidRoomDoor.super.update(self)

    local anim = self.openAnim
    if not anim then return end

    if anim:isValid() then
        self:setImage(anim:image())
    else
        self.openAnim = nil
        self:setImage(doorFrames[OPEN_FRAME])
        local done = self.onOpened
        self.onOpened = nil
        if done then done() end
    end
end

-- Plays the opening animation once; `onOpened` runs when it finishes
-- (right away if the door is already open)
function MidRoomDoor:open(onOpened)
    if self.openAnim then return end
    if self.fields.opened then
        if onOpened then onOpened() end
        return
    end
    self.fields.opened = true
    self.onOpened = onOpened
    -- false = play once instead of looping
    self.openAnim = gfx.animation.loop.new(FRAME_MS, doorFrames, false)
end

-- Shows the door already open, with no animation (used for the door you come out of)
function MidRoomDoor:showOpened()
    self.fields.opened = true
    self.openAnim = nil
    self.onOpened = nil
    self:setImage(doorFrames[OPEN_FRAME])
end

-- Called by the player when Up is pressed in front of the door.
-- Returns true if the player is going through (so Up shouldn't also jump).
function MidRoomDoor:enter(player)
    if not self.target or self.openAnim then return false end

    player:beginDoorEntry()
    self:open(function()
        player.gameManager:travelThroughDoor(self.target)
    end)
    return true
end
