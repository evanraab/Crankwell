local gfx <const> = playdate.graphics

---@class SwitchDoor : Door
--- @overload fun(...): SwitchDoor
SwitchDoor = {}
class('SwitchDoor').extends(Door)

local switchDoorImage <const> = gfx.image.new("images/doors/switch-door")
assert(switchDoorImage, "missing images/doors/switch-door.png")

function SwitchDoor:init(x, y, entity)
    self.switchId = entity.fields.switchId
    -- the PNG is 10x10; scale it up to fill the LDtk entity (20x20)
    local imgW = switchDoorImage:getSize()
    local image = switchDoorImage:scaledImage(entity.size.width / imgW)
    SwitchDoor.super.init(self, x, y, entity, image)
end

function SwitchDoor:onSwitchActivated()
    self:open()
end

function SwitchDoor:listensTo(switchId)
    return self.switchId == switchId
end

