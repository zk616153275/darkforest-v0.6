// Planet initialization logic helpers

use crate::types::planet::PlanetPublicState;
use crate::types::enums::PlanetType;
use dep::aztec::protocol_types::address::AztecAddress;

/// Constants for player initialization
pub global INITIAL_POPULATION: u64 = 50000; // Starting energy
pub global MIN_PLANET_LEVEL: u8 = 0;

/// Calculate planet level from planet ID hash
pub fn calculate_planet_level(planet_id: Field, planet_level_thresholds: [u64; 10]) -> u8 {
    let hash_bytes = planet_id.to_be_bytes::<32>();
    let first_byte = hash_bytes[0] as u64;

    if first_byte < planet_level_thresholds[9] {
        9
    } else if first_byte < planet_level_thresholds[8] {
        8
    } else if first_byte < planet_level_thresholds[7] {
        7
    } else if first_byte < planet_level_thresholds[6] {
        6
    } else if first_byte < planet_level_thresholds[5] {
        5
    } else if first_byte < planet_level_thresholds[4] {
        4
    } else if first_byte < planet_level_thresholds[3] {
        3
    } else if first_byte < planet_level_thresholds[2] {
        2
    } else if first_byte < planet_level_thresholds[1] {
        1
    } else {
        0
    }
}

/// Create initial planet state with default stats
pub fn create_initial_planet(
    planet_id: Field,
    owner: AztecAddress,
    level: u8,
    space_type: u8,
    perlin: u64,
    is_home_planet: bool,
    timestamp: u64,
) -> PlanetPublicState {
    // For Home Planet, PlanetType is always PLANET (0)
    // For others, it should be derived, but create_initial_planet assumes PLANET for now.
    // TODO: Pass planet_type as argument if we want to support initialization of other types via move?
    // Main.nr move_callback currently creates simple planets.

    let stats = crate::types::planet::compute_modified_stats(planet_id, level, PlanetType::PLANET(), space_type);

    let mut initial_pop = 0;
    if is_home_planet {
        initial_pop = INITIAL_POPULATION;
    } else {
        // Barbarian logic
        // Base pirates
        initial_pop = (stats.population_cap * stats.barbarian_percentage) / 100;

        // Multipliers based on SpaceType (logic from LibGameUtils)
        // Dead Space = 20x, Deep Space = 10x, Space = 4x
        // Note: These must match SpaceType enum values
        if space_type == 3 { // DEAD_SPACE
            initial_pop = initial_pop * 20;
        } else if space_type == 2 { // DEEP_SPACE
            initial_pop = initial_pop * 10;
        } else if space_type == 1 { // SPACE
            initial_pop = initial_pop * 4;
        }
    }

    PlanetPublicState {
        planet_id,
        owner,
        level,
        planet_type: PlanetType::PLANET(),
        space_type,
        range: stats.range,
        speed: stats.speed,
        defense: stats.defense,
        population: initial_pop,
        population_cap: stats.population_cap,
        population_growth: stats.population_growth,
        silver_cap: stats.silver_cap,
        silver_growth: stats.silver_growth,
        silver: 0,
        is_initialized: true,
        is_home_planet,
        is_destroyed: false,
        last_updated: timestamp,
        upgrade_state_0: 0,
        upgrade_state_1: 0,
        upgrade_state_2: 0,
        hat_level: 0,
        has_tried_finding_artifact: false,
        prospected_block_number: 0,
        invader: AztecAddress::zero(),
        invade_start_block: 0,
        capturer: AztecAddress::zero(),
        perlin,
    }
}

/// Create an unowned planet
pub fn create_unowned_planet(
    planet_id: Field,
    level: u8,
    space_type: u8,
    perlin: u64,
    timestamp: u64,
) -> PlanetPublicState {
    create_initial_planet(
        planet_id,
        AztecAddress::zero(),
        level,
        space_type,
        perlin,
        false,
        timestamp,
    )
}

/// Verify spawn coordinates are valid
pub fn is_valid_spawn_location(
    dist_squared: u64,
    radius_squared: u64,
    perlin: u64,
    init_perlin_min: u64,
    init_perlin_max: u64,
) -> bool {
    if dist_squared >= radius_squared {
        false
    } else if perlin < init_perlin_min {
        false
    } else if perlin >= init_perlin_max {
        false
    } else {
        true
    }
}
