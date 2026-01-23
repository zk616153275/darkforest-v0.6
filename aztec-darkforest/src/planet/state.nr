// Planet state management helpers
// Lazy update logic for energy and silver growth

use crate::types::planet::PlanetPublicState;

/// Apply population (energy) growth over time
/// Returns updated population value (capped at population_cap)
pub fn calculate_population_after_growth(
    current_population: u64,
    population_growth: u64,
    population_cap: u64,
    time_elapsed: u64,
) -> u64 {
    if population_growth == 0 {
        current_population
    } else {
        // Calculate growth: (growth_rate * time) / 3600 seconds per hour
        // Note: Integer division floors the result, same as Solidity
        let growth = (population_growth as Field * time_elapsed as Field) / 3600;
        let new_population = current_population + growth as u64;

        // Cap at population cap
        if new_population > population_cap {
            population_cap
        } else {
            new_population
        }
    }
}

/// Apply silver growth over time
/// Returns updated silver value (capped at silver_cap)
pub fn calculate_silver_after_growth(
    current_silver: u64,
    silver_growth: u64,
    silver_cap: u64,
    time_elapsed: u64,
) -> u64 {
    if silver_growth == 0 {
        current_silver
    } else {
        let growth = (silver_growth as Field * time_elapsed as Field) / 3600;
        let new_silver = current_silver + growth as u64;

        if new_silver > silver_cap {
            silver_cap
        } else {
            new_silver
        }
    }
}

/// Calculate time elapsed since last update
pub fn calculate_time_elapsed(current_timestamp: u64, last_updated: u64) -> u64 {
    if current_timestamp > last_updated {
        current_timestamp - last_updated
    } else {
        0
    }
}

/// Refresh planet state (apply growth)
/// Returns updated PlanetPublicState
pub fn refresh_planet_state(
    mut state: PlanetPublicState,
    timestamp: u64,
    effective_pop_cap: u64,
    effective_pop_growth: u64,
    effective_silver_cap: u64,
    effective_silver_growth: u64,
) -> PlanetPublicState {
    let time_elapsed = calculate_time_elapsed(timestamp, state.last_updated);

    if time_elapsed > 0 {
        // Update population
        state.population = calculate_population_after_growth(
            state.population,
            effective_pop_growth,
            effective_pop_cap,
            time_elapsed
        );

        // Update silver
        state.silver = calculate_silver_after_growth(
            state.silver,
            effective_silver_growth,
            effective_silver_cap,
            time_elapsed
        );

        // Update timestamp
        state.last_updated = timestamp;
    }

    state
}

/// Get planet's current effective stats (after applying upgrades and artifacts)
/// Returns: (range, speed, defense, pop_cap, pop_growth, silver_cap, silver_growth)
pub fn get_effective_stats(
    base_range: u64,
    base_speed: u64,
    base_defense: u64,
    base_pop_cap: u64,
    base_pop_growth: u64,
    base_silver_cap: u64,
    base_silver_growth: u64,
    upgrade_state_0: u8,
    upgrade_state_1: u8,
    upgrade_state_2: u8,
    hat_level: u8,
    artifact_type: u8,
) -> (u64, u64, u64, u64, u64, u64, u64) {
    // 1. Apply upgrade multipliers (Base + Upgrades)
    // Each upgrade level adds 20%
    let range_mult = 100 + (upgrade_state_0 as u64 * 20);
    let speed_mult = 100 + (upgrade_state_1 as u64 * 20);
    let defense_mult = 100 + (upgrade_state_2 as u64 * 20);

    let mut eff_range = (base_range * range_mult) / 100;
    let mut eff_speed = (base_speed * speed_mult) / 100;
    let mut eff_defense = (base_defense * defense_mult) / 100;

    // Hat level bonus (cosmetic but maybe small stat boost?)
    if hat_level > 0 {
       // e.g. 10% pop cap per hat level?
       // Leaving cosmetic for now.
    }

    let mut eff_pop_cap = base_pop_cap;
    let mut eff_pop_growth = base_pop_growth;
    let mut eff_silver_cap = base_silver_cap;
    let mut eff_silver_growth = base_silver_growth;

    // 2. Apply Artifact Bonuses
    if artifact_type == 1 { // MONOLITH
        eff_pop_cap = (eff_pop_cap * 150) / 100;
        eff_pop_growth = (eff_pop_growth * 150) / 100;
    } else if artifact_type == 2 { // COLOSSUS
        eff_defense = (eff_defense * 150) / 100;
    } else if artifact_type == 3 { // SPACESHIP
        eff_speed = (eff_speed * 150) / 100;
    } else if artifact_type == 4 { // PYRAMID
        eff_silver_cap = (eff_silver_cap * 150) / 100;
        eff_silver_growth = (eff_silver_growth * 150) / 100;
    } else if artifact_type == 5 { // WORMHOLE
        eff_range = (eff_range * 200) / 100;
    } else if artifact_type == 6 { // PLANETARY_SHIELD
        eff_defense = (eff_defense * 200) / 100;
    } else if artifact_type == 7 { // PHOTOID_CANNON
        eff_speed = (eff_speed * 200) / 100;
    } else if artifact_type == 8 { // BLOOM_FILTER
        eff_range = (eff_range * 150) / 100;
    }

    (eff_range, eff_speed, eff_defense, eff_pop_cap, eff_pop_growth, eff_silver_cap, eff_silver_growth)
}

/// Check if a planet can be upgraded on a specific branch
pub fn can_upgrade_planet(_level: u8, current_upgrade_level: u8) -> bool {
    // Max upgrade level is 4
    current_upgrade_level < 4
}

/// Calculate the silver cost for upgrading
pub fn get_upgrade_cost(planet_level: u8, current_upgrade_level: u8) -> u64 {
    let base_cost: u64 = 1000 * (planet_level as u64 + 1);
    let level_mult: u64 = (current_upgrade_level as u64 + 1) * 2;
    base_cost * level_mult
}

#[test]
fn test_get_effective_stats_defaults() {
    let (range, speed, defense, pop_cap, _, _, _) = get_effective_stats(
        100, 100, 100,
        1000, 10,
        500, 5,
        0, 0, 0,
        0, 0
    );
    assert(range == 100);
    assert(speed == 100);
    assert(defense == 100);
    assert(pop_cap == 1000);
}

#[test]
fn test_artifact_bonus_wormhole() {
    // Artifact 5 = WORMHOLE (Range * 2)
    let (range, _, _, _, _, _, _) = get_effective_stats(
        100, 100, 100,
        1000, 10,
        500, 5,
        0, 0, 0,
        0, 5
    );
    assert(range == 200);
}

#[test]
fn test_artifact_bonus_monolith() {
    // Artifact 1 = MONOLITH (Pop Cap * 1.5)
    let (_, _, _, pop_cap, pop_growth, _, _) = get_effective_stats(
        100, 100, 100,
        10000, 100,
        500, 5,
        0, 0, 0,
        0, 1
    );
    assert(pop_cap == 15000);
    assert(pop_growth == 150);
}


