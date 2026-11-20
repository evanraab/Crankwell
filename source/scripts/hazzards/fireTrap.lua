local gfx <const> = playdate.graphics
local imageFireTrap <const> = gfx.image.new("images/hazzards/fire/fireTrap")

--- @class FireTrap : AnimatedSprite
--- @overload fun(...): FireTrap
FireTrap = {}
class('FireTrap').extends(AnimatedSprite)

