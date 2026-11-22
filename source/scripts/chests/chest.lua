local pd <const> = playdate
local gfx <const> = pd.graphics

local CHEST_WIDTH <const> = 20
local CHEST_HEIGHT <const> = 16
local LID_HEIGHT <const> = 6

--- @class Chest : playdate.graphics.sprite
--- @overload fun(...): Chest
Chest = {}
class("Chest").extends(gfx.sprite)

-- Placeholder art, drawn once and shared by every chest. Swap for real images later.
local closedImage, openImage, promptImage

local function buildPlaceholderImages()
    closedImage = gfx.image.new(CHEST_WIDTH, CHEST_HEIGHT)
    gfx.pushContext(closedImage)
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(0, 0, CHEST_WIDTH, CHEST_HEIGHT)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawRect(0, 0, CHEST_WIDTH, CHEST_HEIGHT)
        gfx.drawLine(0, LID_HEIGHT, CHEST_WIDTH - 1, LID_HEIGHT) -- lid seam
        gfx.fillRect(CHEST_WIDTH / 2 - 2, LID_HEIGHT - 2, 4, 5) -- lock
    gfx.popContext()

    -- same body, lid flipped up above it and an empty (black) inside
    openImage = gfx.image.new(CHEST_WIDTH, CHEST_HEIGHT)
    gfx.pushContext(openImage)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawRect(0, LID_HEIGHT, CHEST_WIDTH, CHEST_HEIGHT - LID_HEIGHT)
        gfx.fillRect(1, LID_HEIGHT, CHEST_WIDTH - 2, 3) -- dark inside
        gfx.drawRect(0, 0, CHEST_WIDTH, LID_HEIGHT - 2) -- open lid
    gfx.popContext()

    -- little "A" bubble shown above the chest while the player can open it
    promptImage = gfx.image.new(14, 16)
    gfx.pushContext(promptImage)
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRoundRect(0, 0, 14, 16, 4)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawRoundRect(0, 0, 14, 16, 4)
        gfx.drawTextAligned("A", 7, 1, kTextAlignment.center)
    gfx.popContext()
end

function Chest:init(x, y, entity)
    Chest.super.init(self)
    if not closedImage then
        buildPlaceholderImages()
    end

    -- entity.fields persists for the session, so a chest stays open after its level reloads
    self.fields = (entity and entity.fields) or {}
    self.opened = self.fields.opened == true

    self:setImage(self.opened and openImage or closedImage)
    self:setZIndex(Z_INDEXES.Pickup)
    self:setCenter(0, 0)
    self:moveTo(x, y)
    self:setTag(TAGS.Interactable)
    self:setCollideRect(0, 0, self:getSize())
    self:add()

    self.prompt = gfx.sprite.new(promptImage)
    self.prompt:setZIndex(Z_INDEXES.Player + 1)
    self.prompt:moveTo(x + CHEST_WIDTH / 2, y - 10)
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
    self:setImage(openImage)
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
