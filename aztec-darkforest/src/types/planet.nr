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

use dep::aztec::protocol_types::traits::{Serialize, Deserialize, ToField, FromField};

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

impl Serialize for PlanetPublicState {
    let N: u32 = 28;
    fn serialize(self) -> [Field; 28] {
        [
            self.planet_id,
            self.owner.to_field(),
            self.level as Field,
            self.planet_type as Field,
            self.space_type as Field,
            self.range as Field,
            self.speed as Field,
            self.defense as Field,
            self.population as Field,
            self.population_cap as Field,
            self.population_growth as Field,
            self.silver_cap as Field,
            self.silver_growth as Field,
            self.silver as Field,
            self.is_initialized as Field,
            self.is_home_planet as Field,
            self.is_destroyed as Field,
            self.last_updated as Field,
            self.upgrade_state_0 as Field,
            self.upgrade_state_1 as Field,
            self.upgrade_state_2 as Field,
            self.hat_level as Field,
            self.has_tried_finding_artifact as Field,
            self.prospected_block_number as Field,
            self.invader.to_field(),
            self.invade_start_block as Field,
            self.capturer.to_field(),
            self.perlin as Field
        ]
    }
}

impl Deserialize for PlanetPublicState {
    let N: u32 = 28;
    fn deserialize(input: [Field; 28]) -> Self {
        Self {
            planet_id: input[0],
            owner: AztecAddress::from_field(input[1]),
            level: input[2] as u8,
            planet_type: input[3] as u8,
            space_type: input[4] as u8,
            range: input[5] as u64,
            speed: input[6] as u64,
            defense: input[7] as u64,
            population: input[8] as u64,
            population_cap: input[9] as u64,
            population_growth: input[10] as u64,
            silver_cap: input[11] as u64,
            silver_growth: input[12] as u64,
            silver: input[13] as u64,
            is_initialized: input[14] != 0,
            is_home_planet: input[15] != 0,
            is_destroyed: input[16] != 0,
            last_updated: input[17] as u64,
            upgrade_state_0: input[18] as u8,
            upgrade_state_1: input[19] as u8,
            upgrade_state_2: input[20] as u8,
            hat_level: input[21] as u8,
            has_tried_finding_artifact: input[22] != 0,
            prospected_block_number: input[23] as u64,
            invader: AztecAddress::from_field(input[24]),
            invade_start_block: input[25] as u64,
            capturer: AztecAddress::from_field(input[26]),
            perlin: input[27] as u64,
        }
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

/// Get default stats for a planet level
pub fn get_default_stats(level: u8) -> PlanetDefaultStats {
    // TODO: Populate with actual game balance values
    // These are placeholder values
    if level == 0 {
        PlanetDefaultStats {
            population_cap: 100000,
            population_growth: 417,
            range: 99,
            speed: 75,
            defense: 400,
            silver_growth: 9,
            silver_cap: 1000,
            barbarian_percentage: 0,
        }
    } else if level == 1 {
        PlanetDefaultStats {
            population_cap: 400000,
            population_growth: 833,
            range: 177,
            speed: 75,
            defense: 400,
            silver_growth: 18,
            silver_cap: 4000,
            barbarian_percentage: 1,
        }
    } else {
        PlanetDefaultStats {
            population_cap: 100000,
            population_growth: 417,
            range: 99,
            speed: 75,
            defense: 400,
            silver_growth: 9,
            silver_cap: 1000,
            barbarian_percentage: 0,
        }
    }
}
