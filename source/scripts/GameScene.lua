import "CoreLibs/sprites"
local Camera = import "scripts/camera/camera"

local gfx <const> = playdate.graphics
local ldtk <const> = LDtk

local TILE_SIZE = 20
-- player.y to the bottom of its collide rect (32x32 sprite, centred, rect 6,8,19,23), plus 1px clearance
local PLAYER_FEET_OFFSET <const> = 16

TAGS = {
    Player = 1,
    Hazzard = 2,
    Pickup = 3,
    Enemy = 4,
    Breakable = 5,
    Checkpoint = 6,
    Platform = 7,
    Interactable = 8,
}

Z_INDEXES = {
    Player = 100,
    Pickup = 50,
    Enemy = 40,
    Hazzard = 35,
    Platform = 30,
}

local ENEMY_ENTITIES <const> = {
    PatrolEnemy = true,
    ArmoredEnemy = true,
    Spikeball = true,
    SpikeBall_FixedDistance = true,
    BigHelmet = true,   -- bosses must be listed so resetBosses can respawn them
}

-- Path is CASE-SENSITIVE on the device (Windows hides this): must match the folder/file exactly.
-- Simulator: parse the .ldtk JSON and export precomputed Lua levels.
-- Device: load the precomputed Lua levels (parsing the JSON there is slow and memory-hungry).
local usePrecomputedLevels = not playdate.isSimulator

ldtk.load("Levels/World.ldtk", usePrecomputedLevels)

if playdate.isSimulator then
    ldtk.export_to_lua_files()
end

-- Wrappers look up the class globals at call time, so load order doesn't matter
local entitySpawners <const> = {
    Spike = function(x, y) Spike(x, y) end,
    Spikeball = function(x, y, e) Spikeball(x, y, e) end,
    SpikeBall_FixedDistance = function(x, y, e) SpikeBall_FixedDistance(x, y, e) end,
    PatrolEnemy = function(x, y, e) PatrolEnemy(x, y, e) end,
    ArmoredEnemy = function(x, y, e) ArmoredEnemy(x, y, e) end,
    FlyingEnemy = function(x, y, e) FlyingEnemy(x, y, e) end,
    Ability = function(x, y, e) Ability(x, y, e) end,
    Key = function(x, y, e) Key(x, y, e) end,
    KeyDoor = function(x, y, e) KeyDoor(x, y, e) end,
    SwitchDoor = function(x, y, e) SwitchDoor(x, y, e) end,
    MidRoomDoor = function(x, y, e) MidRoomDoor(x, y, e) end,
    Switch = function(x, y, e) Switch(x, y, e) end,
    BigHelmet = function(x, y, e) BigHelmet(x, y, e) end,
    Checkpoint = function(x, y, e) Checkpoint(x, y, e) end,
    Breakable = function(x, y, e) BreakableBlock(x, y, e) end,
    MovingPlatform = function(x, y, e) MovingPlatform(x, y, e) end,
    TriggeredPlatform = function(x, y, e) TriggeredPlatform(x, y, e) end,
    TimedPlatform = function(x, y, e) TimedPlatform(x, y, e) end,
    CrumblingPlatform = function(x, y, e) CrumblingPlatform(x, y, e) end,
    BouncePlatform = function(x, y, e) BouncePlatform(x, y, e) end,
    ProjectileShooter = function(x, y, e) ProjectileShooter(x, y, e) end,
    FireTrap = function(x, y, e) FireTrap(x, y, e) end,
    Chest = function(x, y, e) Chest(x, y, e) end,
}

---@class GameScene
--- @overload fun(...): GameScene
---@field init fun(self: GameScene)
local GameScene = {}

local NEIGHBOUR_DIRECTIONS <const> = { "north", "south", "east", "west" }

-- Everything lives in world coordinates: a level's content is offset by its LDtk world rect.
function GameScene:init()
    self.loadedLevels = {}   -- level name -> sprites created for that level
    -- in init, next to loadedLevels:
    self.enemySprites = {}   -- level name -> enemy sprites only

    self.wantedLevels = {}   -- active level + its neighbours
    self.pendingLoads = {}
    self.levelStarts = {}     -- level name -> {x, y} from PlayerStart entities
    self.checkpoint = nil     -- { level = "Level_2", x = ..., y = ..., sprite = cp }

    Checkpoint.onActivated = function(cp) self:setCheckpoint(cp) end

    self.spawnLevel = "Level_0"
    gfx.setBackgroundColor(gfx.kColorBlack)
    gfx.clear()
    local spawnRect = ldtk.get_rect(self.spawnLevel)

    self:setActiveLevel(self.spawnLevel, true)
    self.camera = Camera.new(self)

    -- Prefer the level's PlayerStart entity (populated by setActiveLevel above) so the
    -- initial spawn always lands on ground the level actually has, regardless of its
    -- tile grid size. Fall back to the old fixed offset for levels without one.
    local start = self.levelStarts[self.spawnLevel]
    if start then
        self.spawnX = start.x
        self.spawnY = start.y
    else
        self.spawnX = spawnRect.x + 2 * TILE_SIZE
        self.spawnY = spawnRect.y + 10 * TILE_SIZE
    end
    self.player = Player(self.spawnX, self.spawnY, self)
end

-- Streams in at most one pending level per frame to avoid a hitch.
function GameScene:update()
    local name = table.remove(self.pendingLoads, 1)
    if name and self.wantedLevels[name] then
        self:loadLevel(name)
    end
end

function GameScene:addTileLayers(level_name, offsetX, offsetY)
    for layer_name, layer in pairs(ldtk.get_layers(level_name) or {}) do
        if layer.tiles then
            local tilemap = ldtk.create_tilemap(level_name, layer_name)
            if tilemap then
                local layerSprite = gfx.sprite.new()
                layerSprite:setTilemap(tilemap)
                layerSprite:setCenter(0, 0)
                layerSprite:moveTo(offsetX, offsetY)
                layerSprite:setZIndex(layer.zIndex)
                layerSprite:add()

                local emptyTiles = ldtk.get_empty_tileIDs(level_name, "Solid", layer_name)
                if emptyTiles then
                    gfx.sprite.addWallSprites(tilemap, emptyTiles, offsetX, offsetY)
                end
            end
        end
    end
end

local function snapshotSprites()
    local set = {}
    for _, s in ipairs(gfx.sprite.getAllSprites()) do set[s] = true end
    return set
end

local function spritesCreatedSince(before)
    local list = {}
    for _, s in ipairs(gfx.sprite.getAllSprites()) do
        if not before[s] then list[#list + 1] = s end
    end
    return list
end

-- Spawns a level's tiles, walls and entities, remembering every sprite it created.
function GameScene:loadLevel(level_name)
    if self.loadedLevels[level_name] then return end
    local rect = ldtk.get_rect(level_name)
    if not rect then return end

    local before = {}
    for _, s in ipairs(gfx.sprite.getAllSprites()) do
        before[s] = true
    end

    self:addTileLayers(level_name, rect.x, rect.y)
    self:spawnEntities(level_name, rect, false)   -- non-enemies

    local sprites = {}
    local isRunning = self.runningLevels[level_name]
    for _, s in ipairs(gfx.sprite.getAllSprites()) do
        if not before[s] then
            sprites[#sprites + 1] = s
            s:setUpdatesEnabled(isRunning)
        end
    end
    self.loadedLevels[level_name] = sprites
    self:spawnEnemies(level_name)

end

function GameScene:unloadLevel(level_name)
    local sprites = self.loadedLevels[level_name]
    if not sprites then return end
    for _, s in ipairs(sprites) do
        s:remove()
    end
    self.loadedLevels[level_name] = nil
    self:removeEnemies(level_name)
end

-- Makes level_name current, keeps it and its neighbours loaded and unloads the rest.
-- The current level and its east/west neighbours (visible while the camera scrolls) run
-- their update(); north/south neighbours stay frozen until the player transitions into them.
function GameScene:setActiveLevel(level_name, loadNow)
      local previous = self.level_name
    if previous and previous ~= level_name then
        self:removeEnemies(previous)
    end
    self.level_name = level_name
    self.levelRect = ldtk.get_rect(level_name)

    local wanted = { [level_name] = true }
    for _, dir in ipairs(NEIGHBOUR_DIRECTIONS) do
        for _, name in ipairs(ldtk.get_neighbours(level_name, dir) or {}) do
            wanted[name] = true
        end
    end
    self.wantedLevels = wanted

    local running = { [level_name] = true }
    for _, dir in ipairs({ "east", "west" }) do
        for _, name in ipairs(ldtk.get_neighbours(level_name, dir) or {}) do
            running[name] = true
        end
    end
    self.runningLevels = running

    for name in pairs(self.loadedLevels) do
        if not wanted[name] then
            self:unloadLevel(name)
        end
    end

    self:loadLevel(level_name)
    self.pendingLoads = {}
    for name in pairs(wanted) do
        if not self.loadedLevels[name] then
            if loadNow then
                self:loadLevel(name)
            else
                self.pendingLoads[#self.pendingLoads + 1] = name
            end
        end
    end

     for name, sprites in pairs(self.loadedLevels) do
        local isRunning = running[name] == true
        for _, s in ipairs(sprites) do s:setUpdatesEnabled(isRunning) end
        for _, s in ipairs(self.enemySprites[name] or {}) do
            s:setUpdatesEnabled(isRunning)
        end
    end
end

function GameScene:setCheckpoint(cp)
    if self.checkpoint and self.checkpoint.sprite == cp then return end
    if self.checkpoint and self.checkpoint.sprite then
        -- optional: deactivate the old one visually, if it's still loaded
    end
    cp:activate()
    self.checkpoint = {
        level = self.level_name,
        x = cp.levelRespawnX,
        y = cp.levelRespawnY,
        sprite = cp,
    }
end

function GameScene:getRespawnPoint()
    -- Checkpoint only counts if it's in the level the player is currently in
    local cp = self.checkpoint
    if cp and cp.level == self.level_name then
        return cp.x, cp.y
    end

    -- Then the door the player last came through, if it's in this level
    local door = self.doorArrival
    if door and door.level == self.level_name then
        return door.x, door.y
    end

    -- Fallback: start of the current level
    local start = self.levelStarts[self.level_name]
    if start then
        return start.x, start.y
    end
    local rect = self.levelRect
    return rect.x + 2 * TILE_SIZE, rect.y + 10 * TILE_SIZE
end

-- Fade out, put the player back at the respawn point, reset any living boss, fade in
function GameScene:respawnPlayer()
    self.camera:startRespawnFade(function()
        self.player:revive()
        self:resetPlayer()
        self:resetBosses(self.level_name)
    end)
end

-- Respawns every boss in the level that is still alive, so it starts over at
-- its spawn point with full health. Defeated bosses stay gone.
function GameScene:resetBosses(level_name)
    local sprites = self.enemySprites[level_name]
    if not sprites then return end

    local kept, toReset = {}, {}
    for _, s in ipairs(sprites) do
        if s:isa(Boss) and not s.health:isDead() then
            toReset[s.entityIid] = true
            s:remove()
        else
            kept[#kept + 1] = s
        end
    end
    if next(toReset) == nil then return end

    local rect = ldtk.get_rect(level_name)
    local isRunning = self.runningLevels[level_name] == true
    for _, entity in ipairs(ldtk.get_entities(level_name) or {}) do
        local spawn = entitySpawners[entity.name]
        if toReset[entity.iid] and spawn then
            local before = snapshotSprites()
            spawn(rect.x + entity.position.x, rect.y + entity.position.y, entity)
            for _, s in ipairs(spritesCreatedSince(before)) do
                s:setUpdatesEnabled(isRunning)
                kept[#kept + 1] = s
            end
        end
    end
    self.enemySprites[level_name] = kept
end

-- Fades out, moves the player to the door `target` points at (an LDtk entity
-- reference: { entityIid, levelIid, ... }), closes both doors, then fades back in.
-- The player stays frozen until the fade-in has finished.
function GameScene:travelThroughDoor(fromDoor, target)
    local level_name = ldtk.get_level_name(target.levelIid)
    assert(level_name, "door target is in an unknown level")
    local player = self.player

    self.camera:startRespawnFade(function()
        self:setActiveLevel(level_name, true)
        self:ensureEnemies(level_name)

        local x, y = self:getDoorArrivalPoint(level_name, target.entityIid)
        self.doorArrival = { level = level_name, x = x, y = y }

        -- both doors are shown closed when the screen fades back in
        fromDoor:close()
        for _, s in ipairs(self.loadedLevels[level_name] or {}) do
            if s.iid == target.entityIid and s.close then
                s:close()
            end
        end

        player.xVelocity = 0
        player.yVelocity = 0
        player:moveTo(x, y)
    end, function()
        player:endDoorEntry()
    end)
end

-- Where the player stands when coming out of a door: centred on it, feet on its bottom edge
function GameScene:getDoorArrivalPoint(level_name, entityIid)
    local rect = ldtk.get_rect(level_name)
    for _, entity in ipairs(ldtk.get_entities(level_name) or {}) do
        if entity.iid == entityIid then
            local x = rect.x + entity.position.x + entity.size.width / 2
            local bottom = rect.y + entity.position.y + entity.size.height
            return x, bottom - PLAYER_FEET_OFFSET
        end
    end
    error("door target entity " .. tostring(entityIid) .. " not found in " .. level_name)
end

function GameScene:resetPlayer()
    local x, y = self:getRespawnPoint()
    self:setActiveLevel(self.level_name, true)  -- make sure neighbours are loaded
    TriggeredPlatform.resetAll()
    TimedPlatform.resetAll() -- also restores Crumbling and Bounce platforms
    self.player:moveTo(x, y)
end


-- enemies == true spawns only enemy entities, false spawns everything else
function GameScene:spawnEntities(level_name, rect, enemies)
    for _, entity in ipairs(ldtk.get_entities(level_name) or {}) do
        if (ENEMY_ENTITIES[entity.name] == true) == enemies then
            local x = rect.x + entity.position.x
            local y = rect.y + entity.position.y
            if entity.name == "PlayerStart" then
                self.levelStarts[level_name] = { x = x, y = y }
            else
                local spawn = entitySpawners[entity.name]
                if spawn then spawn(x, y, entity) end
            end
        end
    end
end

function GameScene:spawnEnemies(level_name)
    local rect = ldtk.get_rect(level_name)
    if not rect then return end
    local before = snapshotSprites()
    self:spawnEntities(level_name, rect, true)
    local sprites = spritesCreatedSince(before)
    local isRunning = self.runningLevels[level_name] == true
    for _, s in ipairs(sprites) do s:setUpdatesEnabled(isRunning) end
    self.enemySprites[level_name] = sprites
end

function GameScene:removeEnemies(level_name)
    local sprites = self.enemySprites[level_name]
    if not sprites then return end
    for _, s in ipairs(sprites) do s:remove() end
    self.enemySprites[level_name] = nil
end

-- Spawns enemies only if the level doesn't currently have any
function GameScene:ensureEnemies(level_name)
    if not self.enemySprites[level_name] then
        self:spawnEnemies(level_name)
    end
end


return GameScene