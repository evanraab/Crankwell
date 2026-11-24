local gfx <const> = playdate.graphics


--- @class Switch: playdate.graphics.sprite
--- @overload fun(...): Switch
Switch = {}
class('Switch').extends(gfx.sprite)

function Switch:init(x, y, entity)
    self.fields = entity.fields
    self.switchId = entity.fields.switchId
    if self.fields.activated then
        return
    end
    local image = LDtk.generate_image_from_entity(entity)
    assert(image, "door entity has no tile image")
   
    self:setImage(image)
    self:setCenter(0, 0)
    self:moveTo(x, y)
    self:add()

    self:setCollideRect(0, 0, self:getSize())
end

function Switch:onJumpedOn(player)
    self.fields.activated = true
    if self.switchId ~= nil then
        for _, s in ipairs(gfx.sprite.getAllSprites()) do
            if s ~= self and s.listensTo and s:listensTo(self.switchId) then
                s:onSwitchActivated()
            end
        end
    end
    self:remove()
end
