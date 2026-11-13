-- Switch ACTIVE to try a different tile size / LDtk project.
-- spawnCol/spawnRow are the fallback player spawn, in tiles from the level's top-left.
local VARIANTS <const> = {
    [16] = { file = "Levels/World.ldtk",                      spawnCol = 2, spawnRow = 10 },
    [10] = { file = "Levels/alt_scaling/World_10x10.ldtk",    spawnCol = 5, spawnRow = 1 },
}

local ACTIVE <const> = 10

-- 1 = native 400x240. 2 = pixel-doubled: the screen becomes 200x120 logical pixels and
-- everything (tiles, sprites, UI) draws twice as big. Must be set before the camera loads.
local DISPLAY_SCALE <const> = 2

playdate.display.setScale(DISPLAY_SCALE)

local variant <const> = VARIANTS[ACTIVE]

LevelConfig = {
    TILE_SIZE = ACTIVE,
    -- Player physics were tuned in px/frame for 16px tiles. Multiply every speed, acceleration
    -- and gravity by this so jump height (in tiles) and timing stay the same on other grids.
    MOVE_SCALE = ACTIVE / 16,
    LEVEL_FILE = variant.file,
    SPAWN_COL = variant.spawnCol,
    SPAWN_ROW = variant.spawnRow,
}
