// Planet state management helpers
// Lazy update logic for energy and silver growth

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
        let growth = (population_growth * time_elapsed) / 3600;
        let new_population = current_population + growth;

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
        let growth = (silver_growth * time_elapsed) / 3600;
        let new_silver = current_silver + growth;

        if new_silver > silver_cap {
            silver_cap
        } else {
            new_silver
        }
    }
}

/// Get planet's current effective stats (after applying upgrades)
/// Returns: (range, speed, defense, pop_cap, pop_growth)
pub fn get_effective_stats(
    base_range: u64,
    base_speed: u64,
    base_defense: u64,
    population_cap: u64,
    population_growth: u64,
    upgrade_state_0: u8,
    upgrade_state_1: u8,
    upgrade_state_2: u8,
) -> (u64, u64, u64, u64, u64) {
    // Apply upgrade multipliers
    // Each upgrade level adds 20%
    let range_mult = 100 + (upgrade_state_0 as u64 * 20);
    let speed_mult = 100 + (upgrade_state_1 as u64 * 20);
    let defense_mult = 100 + (upgrade_state_2 as u64 * 20);

    let effective_range = (base_range * range_mult) / 100;
    let effective_speed = (base_speed * speed_mult) / 100;
    let effective_defense = (base_defense * defense_mult) / 100;

    (effective_range, effective_speed, effective_defense, population_cap, population_growth)
}

/// Check if a planet can be upgraded on a specific branch
pub fn can_upgrade_planet(level: u8, current_upgrade_level: u8) -> bool {
    // Check planet level (must be > 0 to upgrade)
    if level == 0 {
        false
    } else {
        // Max upgrade level is 4
        current_upgrade_level < 4
    }
}

/// Calculate the silver cost for upgrading
pub fn get_upgrade_cost(planet_level: u8, current_upgrade_level: u8) -> u64 {
    let base_cost: u64 = 1000 * (planet_level as u64 + 1);
    let level_mult: u64 = (current_upgrade_level as u64 + 1) * 2;
    base_cost * level_mult
}

/// Calculate time elapsed since last update
pub fn calculate_time_elapsed(current_timestamp: u64, last_updated: u64) -> u64 {
    if current_timestamp > last_updated {
        current_timestamp - last_updated
    } else {
        0
    }
}
