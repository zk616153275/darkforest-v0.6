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
    /// Create a default uninitialized planet
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

    /// Check if planet is initialized
    pub fn is_init(self) -> bool {
        self.is_initialized
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
