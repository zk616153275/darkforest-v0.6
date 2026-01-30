// Planet type definitions
use dep::aztec::protocol_types::address::AztecAddress;

/// Planet public state - visible to all players
/// Corresponds to eth/contracts/DFTypes.sol#Planet
pub struct PlanetPublicState {
    // Core identity
    pub planet_id: Field,
    pub owner: AztecAddress,

    // Level and type
    pub level: u8,              // 0-9
    pub planet_type: u8,        // PlanetType enum
    pub space_type: u8,         // SpaceType enum

    // Stats
    pub range: u64,
    pub speed: u64,
    pub defense: u64,

    // Population (energy) - current and limits
    pub population: u64,        // Current energy/population
    pub population_cap: u64,
    pub population_growth: u64,

    // Silver
    pub silver_cap: u64,
    pub silver_growth: u64,
    pub silver: u64,

    // State
    pub is_initialized: bool,
    pub is_home_planet: bool,
    pub is_destroyed: bool,
    pub last_updated: u64,

    // Upgrades
    pub upgrade_state_0: u8,
    pub upgrade_state_1: u8,
    pub upgrade_state_2: u8,

    // Hat (cosmetic)
    pub hat_level: u8,

    // Artifact discovery
    pub has_tried_finding_artifact: bool,
    pub prospected_block_number: u64,

    // Capture zone
    pub invader: AztecAddress,
    pub invade_start_block: u64,
    pub capturer: AztecAddress,

    // Perlin value (for biome calculation)
    pub perlin: u64,
}

impl PlanetPublicState {
    pub fn default() -> Self {
        Self {
            planet_id: 0,
            owner: AztecAddress::zero(),
            level: 0,
            planet_type: 0,
            space_type: 0,
            range: 0,
            speed: 0,
            defense: 0,
            population: 0,
            population_cap: 0,
            population_growth: 0,
            silver_cap: 0,
            silver_growth: 0,
            silver: 0,
            is_initialized: false,
            is_home_planet: false,
            is_destroyed: false,
            last_updated: 0,
            upgrade_state_0: 0,
            upgrade_state_1: 0,
            upgrade_state_2: 0,
            hat_level: 0,
            has_tried_finding_artifact: false,
            prospected_block_number: 0,
            invader: AztecAddress::zero(),
            invade_start_block: 0,
            capturer: AztecAddress::zero(),
            perlin: 0,
        }
    }
}

/// Revealed coordinates public state
/// Stores valid coordinates that have been revealed
pub struct RevealedCoords {
    pub location_id: Field,
    pub x: Field,
    pub y: Field,
    pub revealer: AztecAddress,
}

impl RevealedCoords {
    pub fn default() -> Self {
        Self {
            location_id: 0,
            x: 0,
            y: 0,
            revealer: AztecAddress::zero(),
        }
    }
}

use dep::aztec::protocol_types::traits::{Serialize, Deserialize, ToField, FromField, Packable};

impl Serialize for RevealedCoords {
    let N: u32 = 4;
    fn serialize(self) -> [Field; 4] {
        [self.location_id, self.x, self.y, self.revealer.to_field()]
    }
}

impl Deserialize for RevealedCoords {
    let N: u32 = 4;
    fn deserialize(input: [Field; 4]) -> Self {
        Self {
            location_id: input[0],
            x: input[1],
            y: input[2],
            revealer: AztecAddress::from_field(input[3]),
        }
    }
}

impl Packable for RevealedCoords {
    let N: u32 = 4;
    fn pack(self) -> [Field; 4] {
        self.serialize()
    }
    fn unpack(input: [Field; 4]) -> Self {
        Self::deserialize(input)
    }
}

impl Serialize for PlanetPublicState {
    let N: u32 = 21;
    fn serialize(self) -> [Field; 21] {
        // --- Combined Field 1 (Metadata): level, planet_type, space_type ---
        // v0 + v1*256 + v2*65536
        let metadata: Field = (self.level as Field)
            + (self.planet_type as Field) * 256
            + (self.space_type as Field) * 65536;

        // --- Combined Field 2 (Upgrades): upgrade_state_0/1/2, hat_level ---
        // v0 + v1*256 + v2*65536 + v3*16777216
        let upgrades: Field = (self.upgrade_state_0 as Field)
            + (self.upgrade_state_1 as Field) * 256
            + (self.upgrade_state_2 as Field) * 65536
            + (self.hat_level as Field) * 16777216;

        // --- Combined Field 3 (Flags): is_initialized, is_home_planet, is_destroyed, has_tried_finding_artifact ---
        // v0 + v1*2 + v2*4 + v3*8  (bools only need 1 bit each, but use 2 for simplicity)
        let flags: Field = (self.is_initialized as Field)
            + (self.is_home_planet as Field) * 2
            + (self.is_destroyed as Field) * 4
            + (self.has_tried_finding_artifact as Field) * 8;

        [
            self.planet_id,                     // 0
            self.owner.to_field(),              // 1
            metadata,                           // 2 (Combined: level, planet_type, space_type)
            upgrades,                           // 3 (Combined: upgrade_state_0/1/2, hat_level)
            flags,                              // 4 (Combined: is_initialized, is_home_planet, is_destroyed, has_tried_finding_artifact)
            self.range as Field,                // 5
            self.speed as Field,                // 6
            self.defense as Field,              // 7
            self.population as Field,           // 8
            self.population_cap as Field,       // 9
            self.population_growth as Field,    // 10
            self.silver as Field,               // 11
            self.silver_cap as Field,           // 12
            self.silver_growth as Field,        // 13
            self.last_updated as Field,         // 14
            self.prospected_block_number as Field, // 15
            self.invade_start_block as Field,   // 16
            self.perlin as Field,               // 17
            self.invader.to_field(),            // 18
            self.capturer.to_field(),           // 19
            0                                   // 20 (Reserved for future use)
        ]
    }
}

impl Deserialize for PlanetPublicState {
    let N: u32 = 21;
    fn deserialize(input: [Field; 21]) -> Self {
        // --- Unpack Combined Field 1 (Metadata) ---
        let metadata = input[2] as u64;
        let level = (metadata % 256) as u8;
        let planet_type = ((metadata / 256) % 256) as u8;
        let space_type = ((metadata / 65536) % 256) as u8;

        // --- Unpack Combined Field 2 (Upgrades) ---
        let upgrades = input[3] as u64;
        let upgrade_state_0 = (upgrades % 256) as u8;
        let upgrade_state_1 = ((upgrades / 256) % 256) as u8;
        let upgrade_state_2 = ((upgrades / 65536) % 256) as u8;
        let hat_level = ((upgrades / 16777216) % 256) as u8;

        // --- Unpack Combined Field 3 (Flags) ---
        let flags = input[4] as u64;
        let is_initialized = (flags % 2) == 1;
        let is_home_planet = ((flags / 2) % 2) == 1;
        let is_destroyed = ((flags / 4) % 2) == 1;
        let has_tried_finding_artifact = ((flags / 8) % 2) == 1;

        Self {
            planet_id: input[0],
            owner: AztecAddress::from_field(input[1]),
            level,
            planet_type,
            space_type,
            range: input[5] as u64,
            speed: input[6] as u64,
            defense: input[7] as u64,
            population: input[8] as u64,
            population_cap: input[9] as u64,
            population_growth: input[10] as u64,
            silver_cap: input[12] as u64,
            silver_growth: input[13] as u64,
            silver: input[11] as u64,
            is_initialized,
            is_home_planet,
            is_destroyed,
            last_updated: input[14] as u64,
            upgrade_state_0,
            upgrade_state_1,
            upgrade_state_2,
            hat_level,
            has_tried_finding_artifact,
            prospected_block_number: input[15] as u64,
            invader: AztecAddress::from_field(input[18]),
            invade_start_block: input[16] as u64,
            capturer: AztecAddress::from_field(input[19]),
            perlin: input[17] as u64,
        }
    }
}

impl Packable for PlanetPublicState {
    let N: u32 = 21;
    fn pack(self) -> [Field; 21] {
        self.serialize()
    }
    fn unpack(input: [Field; 21]) -> Self {
        Self::deserialize(input)
    }
}

/// Planet default stats by level
/// Corresponds to eth/contracts/DFTypes.sol#PlanetDefaultStats
pub struct PlanetDefaultStats {
    pub population_cap: u64,
    pub population_growth: u64,
    pub range: u64,
    pub speed: u64,
    pub defense: u64,
    pub silver_growth: u64,
    pub silver_cap: u64,
    pub barbarian_percentage: u64,
}

/// Get base stats for a planet level (0-9)
/// Mapped from LibGameUtils.sol _planetDefaultStats
pub fn get_base_stats(level: u8) -> PlanetDefaultStats {
    if level == 0 { PlanetDefaultStats { population_cap: 100000, population_growth: 417, range: 99, speed: 75, defense: 400, silver_growth: 9, silver_cap: 1000, barbarian_percentage: 0 } }
    else if level == 1 { PlanetDefaultStats { population_cap: 400000, population_growth: 833, range: 177, speed: 75, defense: 400, silver_growth: 18, silver_cap: 4000, barbarian_percentage: 1 } }
    else if level == 2 { PlanetDefaultStats { population_cap: 1600000, population_growth: 1667, range: 317, speed: 75, defense: 400, silver_growth: 35, silver_cap: 16000, barbarian_percentage: 5 } }
    else if level == 3 { PlanetDefaultStats { population_cap: 6400000, population_growth: 3333, range: 567, speed: 75, defense: 400, silver_growth: 71, silver_cap: 64000, barbarian_percentage: 10 } }
    else if level == 4 { PlanetDefaultStats { population_cap: 25600000, population_growth: 6667, range: 1013, speed: 75, defense: 400, silver_growth: 141, silver_cap: 256000, barbarian_percentage: 20 } }
    else if level == 5 { PlanetDefaultStats { population_cap: 102400000, population_growth: 13333, range: 1812, speed: 75, defense: 400, silver_growth: 283, silver_cap: 1024000, barbarian_percentage: 40 } }
    else if level == 6 { PlanetDefaultStats { population_cap: 409600000, population_growth: 26667, range: 3239, speed: 75, defense: 400, silver_growth: 566, silver_cap: 4096000, barbarian_percentage: 55 } }
    else if level == 7 { PlanetDefaultStats { population_cap: 1638400000, population_growth: 53333, range: 5790, speed: 75, defense: 400, silver_growth: 1131, silver_cap: 16384000, barbarian_percentage: 70 } }
    else if level == 8 { PlanetDefaultStats { population_cap: 6553600000, population_growth: 106667, range: 10352, speed: 75, defense: 400, silver_growth: 2263, silver_cap: 65536000, barbarian_percentage: 80 } }
    else { PlanetDefaultStats { population_cap: 26214400000, population_growth: 213333, range: 18503, speed: 75, defense: 400, silver_growth: 4525, silver_cap: 262144000, barbarian_percentage: 90 } }
}

use crate::utils::random;
use crate::types::enums::{PlanetType, SpaceType};

/// Compute final stats for a planet based on its properties
/// Corresponds to LibGameUtils.sol#_defaultPlanet logic
pub fn compute_modified_stats(
    planet_id: Field,
    level: u8,
    planet_type: u8,
    space_type: u8
) -> PlanetDefaultStats {
    let mut stats = get_base_stats(level);

    // 1. Apply Boosts
    if random::is_pop_cap_boost(planet_id) { stats.population_cap = stats.population_cap * 2; }
    if random::is_pop_gro_boost(planet_id) { stats.population_growth = stats.population_growth * 2; }
    if random::is_range_boost(planet_id) { stats.range = stats.range * 2; }
    if random::is_speed_boost(planet_id) { stats.speed = stats.speed * 2; }
    if random::is_def_boost(planet_id) { stats.defense = stats.defense * 2; }

    // 2. Apply Space Type Modifiers
    if space_type == SpaceType::DEAD_SPACE() {
        // Dead Space: Buffs x2, Defense 0.15x
        stats.range = stats.range * 2;
        stats.speed = stats.speed * 2;
        stats.population_cap = stats.population_cap * 2;
        stats.population_growth = stats.population_growth * 2;
        stats.silver_cap = stats.silver_cap * 2;
        stats.silver_growth = stats.silver_growth * 2;
        stats.defense = (stats.defense * 3) / 20;
    } else if space_type == SpaceType::DEEP_SPACE() {
        // Deep Space: Buffs 1.5x, Defense 0.25x
        stats.range = (stats.range * 3) / 2;
        stats.speed = (stats.speed * 3) / 2;
        stats.population_cap = (stats.population_cap * 3) / 2;
        stats.population_growth = (stats.population_growth * 3) / 2;
        stats.silver_cap = (stats.silver_cap * 3) / 2;
        stats.silver_growth = (stats.silver_growth * 3) / 2;
        stats.defense = stats.defense / 4;
    } else if space_type == SpaceType::SPACE() {
        // Space: Buffs 1.25x, Defense 0.5x
        stats.range = (stats.range * 5) / 4;
        stats.speed = (stats.speed * 5) / 4;
        stats.population_cap = (stats.population_cap * 5) / 4;
        stats.population_growth = (stats.population_growth * 5) / 4;
        stats.silver_cap = (stats.silver_cap * 5) / 4;
        stats.silver_growth = (stats.silver_growth * 5) / 4;
        stats.defense = stats.defense / 2;
    }

    // 3. Apply Planet Type Modifiers
    if planet_type == PlanetType::SILVER_MINE() {
        stats.silver_cap = stats.silver_cap * 2;
        stats.defense = stats.defense / 2;
        stats.silver_growth = stats.silver_growth; // Explicitly kept same in Sol
    } else if planet_type == PlanetType::SILVER_BANK() {
        stats.speed = stats.speed / 2;
        stats.silver_cap = stats.silver_cap * 10;
        stats.population_growth = 0;
        stats.population_cap = stats.population_cap * 5;
    } else if planet_type == PlanetType::TRADING_POST() {
        stats.defense = stats.defense / 2;
        stats.silver_cap = stats.silver_cap * 2;
    }

    // Note: Population calculation (barbarians) is handled in init.nr using these stats

    stats
}
