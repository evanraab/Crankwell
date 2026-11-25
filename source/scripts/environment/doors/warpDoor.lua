local pd <const> = playdate
local gfx <const> = pd.graphics

-- A door that warps the player to another door. Stand in front of it and press Up: it plays its
-- opening animation, the screen fades, and the player comes out at the door its
-- LDtk `target` field points to (usually in another room). Both doors are closed
-- again once the screen is black.
--
-- LDtk fields:
--   target  Entity ref - the door to come out of (point it at another WarpDoor)

--- @class WarpDoor : Door
--- @overload fun(...): WarpDoor
WarpDoor = {}
class("WarpDoor").extends(Door)

-- 3 frames of 20x20: closed -> opening -> open
local doorFrames <const> = gfx.imagetable.new("images/doors/door-table-20-20")
assert(doorFrames, "missing images/doors/door-table-20-20.png")

local CLOSED_FRAME <const> = 1
local OPEN_FRAME <const> = #doorFrames
local FRAME_MS <const> = 80

function WarpDoor:init(x, y, entity)
    self.iid = entity.iid
    self.target = entity.fields.target
    WarpDoor.super.init(self, x, y, entity, doorFrames[CLOSED_FRAME])
    -- overlap, not solid: the player walks in front of the door
    self:setTag(TAGS.Interactable)
end

function WarpDoor:update()
    WarpDoor.super.update(self)

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
function WarpDoor:open(onOpened)
    if self.openAnim then return end
    self.onOpened = onOpened
    -- false = play once instead of looping
    self.openAnim = gfx.animation.loop.new(FRAME_MS, doorFrames, false)
end

-- Snaps the door back to its closed frame, cancelling any opening animation
function WarpDoor:close()
    self.openAnim = nil
    self.onOpened = nil
    self:setImage(doorFrames[CLOSED_FRAME])
end

-- Called by the player when Up is pressed in front of the door.
-- Returns true if the player is going through (so Up shouldn't also jump).
function WarpDoor:enter(player)
    if not self.target or self.openAnim then return false end

    player:beginDoorEntry()
    self:open(function()
        player.gameManager:travelThroughDoor(self, self.target)
    end)
    return true
end
