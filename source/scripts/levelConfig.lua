-- Switch ACTIVE to try a different tile size / LDtk project.
-- spawnCol/spawnRow are the fallback player spawn, in tiles from the level's top-left.
local VARIANTS <const> = {
    [16] = { file = "Levels/World.ldtk",                      spawnCol = 2, spawnRow = 10 },
    [10] = { file = "Levels/alt_scaling/World_10x10.ldtk",    spawnCol = 3, spawnRow = 16 },
    [20] = { file = "Levels/alt_scaling/World_20x20.ldtk",    spawnCol = 2, spawnRow = 8 },
}

local ACTIVE <const> = 16

local variant <const> = VARIANTS[ACTIVE]

LevelConfig = {
    TILE_SIZE = ACTIVE,
    LEVEL_FILE = variant.file,
    SPAWN_COL = variant.spawnCol,
    SPAWN_ROW = variant.spawnRow,
}
