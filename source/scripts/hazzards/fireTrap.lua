local gfx <const> = playdate.graphics


--- @class FireTrap : AnimatedSprite
--- @overload fun(...): FireTrap
FireTrap = {}
class('FireTrap').extends(AnimatedSprite)

FireTrap.COLLIDE_RECT = { 0, 0, 20, 20 }


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
    self:setCollideRect(table.unpack(self.COLLIDE_RECT)
end


function FireTrap:setupAnimations()
    self:addState("idle", 1, 1)
end
