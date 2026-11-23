local gfx <const> = playdate.graphics


--- @class Door : playdate.graphics.sprite
--- @overload fun(...): Door
Door = {}
class('Door').extends(gfx.sprite)

--- `image` is optional; if nil, the image comes from the entity's LDtk tile
function Door:init(x, y, entity, image)
    Door.super.init(self)
    self.fields = entity.fields
    if self.fields.unlocked then
        return
    end

    image = image or LDtk.generate_image_from_entity(entity)
    assert(image, "door entity has no image")

    self:setImage(image)
    self:setCenter(0, 0)
    self:moveTo(x, y)
    self:setCollideRect(0, 0, self:getSize())
    self:add()
end


function Door:tryUnlock(player)
    return false
end

function Door:open()
    self.fields.unlocked = true
    self:remove()
end

