---@class ProjectileEnemy : PatrolEnemy
---@overload fun(...): ProjectileEnemy
ProjectileEnemy = {}
class("ProjectileEnemy").extends(PatrolEnemy)

ProjectileEnemy.PROJECTILE_ENEMY_SHEET = "images/enemies/enemy-table-16-16"
-- uses composition pattern to have both patrol enemy and projectileshooter behavior

function ProjectileEnemy:init(x, y, entity,sheetPath)
    ProjectileEnemy.super.init(self, x, y, entity, sheetPath)
    self.projectileShooter = ProjectileShooter(x, y) -- use projectile shooter class for shooting

end

function ProjectileEnemy:update()
    ProjectileEnemy.super.update(self)
    self.projectileShooter:update()
end

