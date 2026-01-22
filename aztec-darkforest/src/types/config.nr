// Game configuration struct
// Passed to constructor during contract deployment

/// Game configuration
/// Corresponds to eth/contracts/libraries/LibStorage.sol#GameConstants + SnarkConstants
struct GameConfig {
    // World bounds
    world_radius: u64,
    world_radius_min: u64,
    world_radius_locked: bool,

    // Planet generation
    planet_rarity: u64,
    max_natural_planet_level: u64,

    // Perlin thresholds for space types
    perlin_threshold_1: u64,
    perlin_threshold_2: u64,
    perlin_threshold_3: u64,

    // Biome thresholds
    biome_threshold_1: u64,
    biome_threshold_2: u64,

    // Init perlin range (where players can spawn)
    init_perlin_min: u64,
    init_perlin_max: u64,

    // Spawn area
    spawn_rim_area: u64,

    // SNARK keys
    planethash_key: Field,
    spacetype_key: Field,
    biomebase_key: Field,

    // Perlin config
    perlin_mirror_x: bool,
    perlin_mirror_y: bool,
    perlin_length_scale: u64,

    // Timing
    time_factor_hundredths: u64,
    location_reveal_cooldown: u64,

    // Features
    planet_transfer_enabled: bool,
    space_junk_enabled: bool,
    space_junk_limit: u64,

    // Capture zones
    capture_zones_enabled: bool,
    capture_zone_radius: u64,
    capture_zone_hold_blocks_required: u64,
}

impl GameConfig {
    /// Create default test configuration
    pub fn default_test() -> Self {
        Self {
            world_radius: 50000,
            world_radius_min: 15000,
            world_radius_locked: false,
            planet_rarity: 16384,
            max_natural_planet_level: 9,
            perlin_threshold_1: 11,
            perlin_threshold_2: 13,
            perlin_threshold_3: 15,
            biome_threshold_1: 15,
            biome_threshold_2: 17,
            init_perlin_min: 12,
            init_perlin_max: 13,
            spawn_rim_area: 0,
            planethash_key: 7,
            spacetype_key: 8,
            biomebase_key: 9,
            perlin_mirror_x: false,
            perlin_mirror_y: false,
            perlin_length_scale: 8192,
            time_factor_hundredths: 100,
            location_reveal_cooldown: 86400, // 24 hours
            planet_transfer_enabled: true,
            space_junk_enabled: true,
            space_junk_limit: 1000,
            capture_zones_enabled: false,
            capture_zone_radius: 500,
            capture_zone_hold_blocks_required: 100,
        }
    }
}
