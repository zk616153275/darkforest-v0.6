// Move planet module tests - travel time, energy decay, arrivals
use crate::planet::move_planet::{calculate_travel_time, calculate_energy_decay, is_within_range, apply_arrival};
use crate::types::planet::PlanetPublicState;
use crate::types::arrival::ArrivalData;
use dep::aztec::protocol_types::address::AztecAddress;
use dep::aztec::protocol_types::traits::FromField;

#[test]
fn test_travel_time_calculation() {
    // Basic case: distance 100, speed 100 -> time = 100
    assert(calculate_travel_time(100, 100) == 100);

    // Slower speed: distance 100, speed 50 -> time = 200
    assert(calculate_travel_time(100, 50) == 200);

    // Faster speed: distance 100, speed 200 -> time = 50
    assert(calculate_travel_time(100, 200) == 50);

    // Zero speed should return 0 (edge case)
    assert(calculate_travel_time(100, 0) == 0);

    // Long distance: distance 1000, speed 75 -> time = 1333
    assert(calculate_travel_time(1000, 75) == 1333);
}

#[test]
fn test_energy_decay_calculation() {
    // No distance = full energy
    assert(calculate_energy_decay(1000, 0, 100) == 1000);

    // Distance equals range: energy * range / (range + range) = energy / 2
    assert(calculate_energy_decay(1000, 100, 100) == 500);

    // Short distance: 1000 energy, distance 50, range 100
    // = 1000 * 100 / (100 + 50) = 100000 / 150 = 666
    assert(calculate_energy_decay(1000, 50, 100) == 666);

    // Long distance: 1000 energy, distance 200, range 100
    // = 1000 * 100 / (100 + 200) = 100000 / 300 = 333
    assert(calculate_energy_decay(1000, 200, 100) == 333);

    // Zero range edge case
    assert(calculate_energy_decay(1000, 100, 0) == 0);
}

#[test]
fn test_distance_within_range() {
    // Within range: distance 50, range 100 -> true (50 <= 200)
    assert(is_within_range(50, 100) == true);

    // At max range: distance 200, range 100 -> true (200 <= 200)
    assert(is_within_range(200, 100) == true);

    // Out of range: distance 250, range 100 -> false (250 > 200)
    assert(is_within_range(250, 100) == false);
}

#[test]
fn test_apply_arrival_reinforce() {
    // Setup: owner reinforcing their own planet
    let owner = AztecAddress::from_field(123);
    let mut planet = PlanetPublicState::default();
    planet.owner = owner;
    planet.population = 500;
    planet.silver = 100;
    planet.is_initialized = true;

    let arrival = ArrivalData {
        id: 1,
        player: owner,  // Same owner = reinforce
        from_planet: 1,
        to_planet: 2,
        pop_arriving: 200,
        silver_moved: 50,
        departure_time: 0,
        arrival_time: 100,
        distance: 50,
        to_perlin: 10,
    };

    let timestamp: u64 = 100;
    let defense: u64 = 100;
    let pop_cap: u64 = 1000;
    let silver_cap: u64 = 500;

    let (updated, processed) = apply_arrival(planet, arrival, timestamp, defense, pop_cap, silver_cap);

    assert(processed == true);
    assert(updated.population == 700);  // 500 + 200
    assert(updated.silver == 150);      // 100 + 50
    assert(updated.owner == owner);     // Still same owner
}

#[test]
fn test_apply_arrival_attack_success() {
    let attacker = AztecAddress::from_field(456);
    let defender = AztecAddress::from_field(123);

    let mut planet = PlanetPublicState::default();
    planet.owner = defender;
    planet.population = 100;  // Low defense
    planet.silver = 200;
    planet.is_initialized = true;

    let arrival = ArrivalData {
        id: 1,
        player: attacker,  // Different owner = attack
        from_planet: 1,
        to_planet: 2,
        pop_arriving: 300,  // Strong attack
        silver_moved: 0,
        departure_time: 0,
        arrival_time: 100,
        distance: 50,
        to_perlin: 15,
    };

    let timestamp: u64 = 100;
    let defense: u64 = 100;  // 100% defense (no bonus)
    let pop_cap: u64 = 1000;
    let silver_cap: u64 = 500;

    // Effective defense = 100 * 100 / 100 = 100
    // Attack 300 > Defense 100 -> Conquer!
    // Remaining pop = 300 - 100 = 200

    let (updated, processed) = apply_arrival(planet, arrival, timestamp, defense, pop_cap, silver_cap);

    assert(processed == true);
    assert(updated.owner == attacker);  // Planet conquered
    assert(updated.population == 200);  // 300 - 100
    assert(updated.silver == 100);      // Silver halved: 200 / 2
}

#[test]
fn test_apply_arrival_attack_defended() {
    let attacker = AztecAddress::from_field(456);
    let defender = AztecAddress::from_field(123);

    let mut planet = PlanetPublicState::default();
    planet.owner = defender;
    planet.population = 500;  // Strong defense
    planet.silver = 200;
    planet.is_initialized = true;

    let arrival = ArrivalData {
        id: 1,
        player: attacker,
        from_planet: 1,
        to_planet: 2,
        pop_arriving: 100,  // Weak attack
        silver_moved: 0,
        departure_time: 0,
        arrival_time: 100,
        distance: 50,
        to_perlin: 20,
    };

    let timestamp: u64 = 100;
    let defense: u64 = 100;
    let pop_cap: u64 = 1000;
    let silver_cap: u64 = 500;

    // Effective defense = 500 * 100 / 100 = 500
    // Attack 100 < Defense 500 -> Defended
    // Damage = 100 * 100 / 100 = 100
    // Remaining pop = 500 - 100 = 400

    let (updated, processed) = apply_arrival(planet, arrival, timestamp, defense, pop_cap, silver_cap);

    assert(processed == true);
    assert(updated.owner == defender);  // Still defended
    assert(updated.population == 400);  // 500 - 100 damage
    assert(updated.silver == 200);      // Silver unchanged
}

#[test]
fn test_apply_arrival_not_yet_arrived() {
    let owner = AztecAddress::from_field(123);
    let mut planet = PlanetPublicState::default();
    planet.owner = owner;
    planet.population = 500;
    planet.is_initialized = true;

    let arrival = ArrivalData {
        id: 1,
        player: owner,
        from_planet: 1,
        to_planet: 2,
        pop_arriving: 200,
        silver_moved: 0,
        departure_time: 0,
        arrival_time: 200,  // Future arrival
        distance: 50,
        to_perlin: 5,
    };

    let timestamp: u64 = 100;  // Current time < arrival time
    let defense: u64 = 100;
    let pop_cap: u64 = 1000;
    let silver_cap: u64 = 500;

    let (updated, processed) = apply_arrival(planet, arrival, timestamp, defense, pop_cap, silver_cap);

    assert(processed == false);          // Not processed yet
    assert(updated.population == 500);   // Unchanged
}

#[test]
fn test_apply_arrival_cap_overflow() {
    let owner = AztecAddress::from_field(123);
    let mut planet = PlanetPublicState::default();
    planet.owner = owner;
    planet.population = 900;
    planet.silver = 450;
    planet.is_initialized = true;

    let arrival = ArrivalData {
        id: 1,
        player: owner,
        from_planet: 1,
        to_planet: 2,
        pop_arriving: 300,   // Would overflow cap
        silver_moved: 100,   // Would overflow cap
        departure_time: 0,
        arrival_time: 100,
        distance: 50,
        to_perlin: 25,
    };

    let timestamp: u64 = 100;
    let defense: u64 = 100;
    let pop_cap: u64 = 1000;    // Max 1000
    let silver_cap: u64 = 500;  // Max 500

    // 900 + 300 = 1200 -> capped to 1000
    // 450 + 100 = 550 -> capped to 500

    let (updated, processed) = apply_arrival(planet, arrival, timestamp, defense, pop_cap, silver_cap);

    assert(processed == true);
    assert(updated.population == 1000);  // Capped
    assert(updated.silver == 500);       // Capped
}
