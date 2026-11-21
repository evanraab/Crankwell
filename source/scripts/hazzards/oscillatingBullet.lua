local imageBullet <const> = gfx.image.new("images/hazzards/bullets/bullet_1")


---@class OscillatingBullet : Bullet
---@overload fun(...): OscillatingBullet
OscillatingBullet = {}
class("OscillatingBullet").extends(Bullet)

local DEFAULT_AMPLITUDE = 20
local DEFAULT_FREQUENCY = 0.05


function OscillatingBullet:init()
    OscillatingBullet.super.init(self, imageBullet)


    self.baseY = y
    self.oscillationAmplitude = DEFAULT_AMPLITUDE
    self.oscillationFrequency = DEFAULT_FREQUENCY
    self.oscillationAngle = 0
end


function OscillatingBullet:applyGravity()
    self.oscillationAngle += self.oscillationFrequency
    self.yVelocity = self.oscillationAmplitude * self.oscillationFrequency
        * math.cos(self.oscillationAngle)
end

function OscillatingBullet:update()
    OscillatingBullet.super.update()
    self:applyGravity()
end
