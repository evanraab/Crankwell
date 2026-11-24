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

    -- LDtk's "Stretch" tile render mode is editor-only; the importer returns the
    -- raw tileset rect (16x16), so scale it to the entity's size (20x20) here.
    local imgW, imgH = image:getSize()
    local w, h = entity.size.width, entity.size.height
    if imgW ~= w or imgH ~= h then
        image = image:scaledImage(w / imgW, h / imgH)
    end

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
