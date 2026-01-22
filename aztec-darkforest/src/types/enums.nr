// Enums for game types
// Corresponds to eth/contracts/DFTypes.sol enums

/// Planet type
/// Corresponds to PlanetType enum in Solidity
pub struct PlanetType;

impl PlanetType {
    pub fn PLANET() -> u8 { 0 }
    pub fn SILVER_MINE() -> u8 { 1 }
    pub fn RUINS() -> u8 { 2 }
    pub fn TRADING_POST() -> u8 { 3 }
    pub fn SILVER_BANK() -> u8 { 4 }
}

/// Space type (determined by perlin noise)
/// Corresponds to SpaceType enum in Solidity
pub struct SpaceType;

impl SpaceType {
    pub fn NEBULA() -> u8 { 0 }
    pub fn SPACE() -> u8 { 1 }
    pub fn DEEP_SPACE() -> u8 { 2 }
    pub fn DEAD_SPACE() -> u8 { 3 }
}

/// Biome type
/// Corresponds to Biome enum in Solidity
pub struct Biome;

impl Biome {
    pub fn UNKNOWN() -> u8 { 0 }
    pub fn OCEAN() -> u8 { 1 }
    pub fn FOREST() -> u8 { 2 }
    pub fn GRASSLAND() -> u8 { 3 }
    pub fn TUNDRA() -> u8 { 4 }
    pub fn SWAMP() -> u8 { 5 }
    pub fn DESERT() -> u8 { 6 }
    pub fn ICE() -> u8 { 7 }
    pub fn WASTELAND() -> u8 { 8 }
    pub fn LAVA() -> u8 { 9 }
    pub fn CORRUPTED() -> u8 { 10 }
}

/// Upgrade branch
pub struct UpgradeBranch;

impl UpgradeBranch {
    pub fn DEFENSE() -> u8 { 0 }
    pub fn RANGE() -> u8 { 1 }
    pub fn SPEED() -> u8 { 2 }
}

/// Artifact type
pub struct ArtifactType;

impl ArtifactType {
    pub fn UNKNOWN() -> u8 { 0 }
    pub fn MONOLITH() -> u8 { 1 }
    pub fn COLOSSUS() -> u8 { 2 }
    pub fn SPACESHIP() -> u8 { 3 }
    pub fn PYRAMID() -> u8 { 4 }
    pub fn WORMHOLE() -> u8 { 5 }
    pub fn PLANETARY_SHIELD() -> u8 { 6 }
    pub fn PHOTOID_CANNON() -> u8 { 7 }
    pub fn BLOOM_FILTER() -> u8 { 8 }
    pub fn BLACK_DOMAIN() -> u8 { 9 }
    // Spaceships
    pub fn SHIP_MOTHERSHIP() -> u8 { 10 }
    pub fn SHIP_CRESCENT() -> u8 { 11 }
    pub fn SHIP_WHALE() -> u8 { 12 }
    pub fn SHIP_GEAR() -> u8 { 13 }
    pub fn SHIP_TITAN() -> u8 { 14 }
}

/// Artifact rarity
pub struct ArtifactRarity;

impl ArtifactRarity {
    pub fn UNKNOWN() -> u8 { 0 }
    pub fn COMMON() -> u8 { 1 }
    pub fn RARE() -> u8 { 2 }
    pub fn EPIC() -> u8 { 3 }
    pub fn LEGENDARY() -> u8 { 4 }
    pub fn MYTHIC() -> u8 { 5 }
}

/// Get space type from perlin value
pub fn get_space_type_from_perlin(
    perlin: u64,
    threshold_1: u64,
    threshold_2: u64,
    threshold_3: u64,
) -> u8 {
    if perlin < threshold_1 {
        SpaceType::NEBULA()
    } else if perlin < threshold_2 {
        SpaceType::SPACE()
    } else if perlin < threshold_3 {
        SpaceType::DEEP_SPACE()
    } else {
        SpaceType::DEAD_SPACE()
    }
}
