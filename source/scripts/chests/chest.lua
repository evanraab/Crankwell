local pd <const> = playdate
local gfx <const> = pd.graphics

--- @class Chest : playdate.graphics.sprite
--- @overload fun(...): Chest
Chest = {}
class("Chest").extends(playdate.graphics.sprite)

function Chest:init(x, y, entity)
    Chest.super.init(self)
    
end

function Chest:update()
    Chest.super.update(self)
end
