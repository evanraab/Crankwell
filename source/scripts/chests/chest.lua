local pd <const> = playdate
local gfx <const> = pd.graphics

local CHEST_WIDTH <const> = 20
local CHEST_HEIGHT <const> = 20 -- matches the LDtk entity and chest_closed.png

--- @class Chest : playdate.graphics.sprite
--- @overload fun(...): Chest
Chest = {}
class("Chest").extends(gfx.sprite)

-- Plain PNGs, so gfx.image (gfx.imagetable only loads "-table-w-h" sheets or folders)
local closedImage <const> = gfx.image.new("images/chests/chest_closed")
local openImage <const> = gfx.image.new("images/chests/chest_opened") -- taller: the lid sticks up
assert(closedImage and openImage, "missing images/chests/chest_closed.png or chest_opened.png")

-- little "A" bubble shown above the chest while the player can open it
local promptImage <const> = gfx.image.new(14, 16)
gfx.pushContext(promptImage)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRoundRect(0, 0, 14, 16, 4)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRoundRect(0, 0, 14, 16, 4)
    gfx.drawTextAligned("A", 7, 1, kTextAlignment.center)
gfx.popContext()

function Chest:init(x, y, entity)
    Chest.super.init(self)

    -- entity.fields persists for the session, so a chest stays open after its level reloads
    self.fields = (entity and entity.fields) or {}
    self.opened = self.fields.opened == true

    -- anchor at the bottom-left so the taller open image grows upward, not into the floor
    self:setCenter(0, 1)
    self:moveTo(x, y + CHEST_HEIGHT)
    self:setChestImage(self.opened and openImage or closedImage)
    self:setZIndex(Z_INDEXES.Pickup)
    self:setTag(TAGS.Interactable)
    self:add()

    self.prompt = gfx.sprite.new(promptImage)
    self.prompt:setZIndex(Z_INDEXES.Player + 1)
    self.prompt:moveTo(x + CHEST_WIDTH / 2, y - 10)
end

-- Swaps the image and keeps the hitbox on the chest body (the bottom 20x20), whatever the image height.
function Chest:setChestImage(image)
    self:setImage(image)
    local _, h = image:getSize()
    self:setCollideRect(0, h - CHEST_HEIGHT, CHEST_WIDTH, CHEST_HEIGHT)
end

function Chest:update()
    Chest.super.update(self)
    if self.opened then return end

    local player = self:getOverlappingPlayer()
    self:setPromptVisible(player ~= nil)

    if player and pd.buttonJustPressed(pd.kButtonA) then
        self:open(player)
    end
end

function Chest:getOverlappingPlayer()
    for _, s in ipairs(self:overlappingSprites()) do
        if s:getTag() == TAGS.Player and not s.dead then
            return s
        end
    end
    return nil
end

function Chest:setPromptVisible(visible)
    if visible and not self.promptShown then
        self.prompt:add()
    elseif not visible and self.promptShown then
        self.prompt:remove()
    end
    self.promptShown = visible
end

function Chest:open(player)
    self.opened = true
    self.fields.opened = true
    self:setChestImage(openImage)
    self:setPromptVisible(false)
    self:onOpened(player)
end

-- Hook for what the chest gives the player (coins, keys, abilities...).
function Chest:onOpened(player)
end

-- the prompt is its own sprite, so take it with the chest when the level unloads
function Chest:remove()
    self:setPromptVisible(false)
    Chest.super.remove(self)
end
