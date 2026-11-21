local imageBullet <const> = gfx.image.new("images/hazzards/bullets/bullet_1")


---@class OscillatingBullet : Bullet
---@overload fun(...): OscillatingBullet
OscillatingBullet = {}
class("OscillatingBullet").extends(Bullet)

local DEFAULT_AMPLITUDE = 20
local DEFAULT_FREQUENCY = 0.05


function OscillatingBullet:init()
    OscillatingBullet.super.init(self, imageBullet)
end