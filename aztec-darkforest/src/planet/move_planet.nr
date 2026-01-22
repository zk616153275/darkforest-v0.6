// Planet movement logic helpers

use crate::utils::math::sqrt_u64;

/// Calculate travel time based on distance and speed
pub fn calculate_travel_time(distance: u64, speed: u64) -> u64 {
    if speed == 0 {
        0
    } else {
        (distance * 100) / speed
    }
}

/// Calculate energy decay during travel
pub fn calculate_energy_decay(energy: u64, distance: u64, range: u64) -> u64 {
    if range == 0 {
        0
    } else {
        let effective_range = range + distance;
        (energy * range) / effective_range
    }
}

/// Calculate energy received after defense
pub fn calculate_energy_after_defense(incoming_energy: u64, defense: u64) -> u64 {
    if defense == 0 {
        incoming_energy
    } else {
        (incoming_energy * 100) / defense
    }
}

/// Determine if an attack is successful
/// Returns (is_capture, remaining_energy)
pub fn resolve_combat(attacker_energy: u64, defender_energy: u64) -> (bool, u64) {
    if attacker_energy > defender_energy {
        (true, attacker_energy - defender_energy)
    } else {
        (false, defender_energy - attacker_energy)
    }
}

/// Calculate distance between two coordinates
pub fn calculate_distance(from_x: i64, from_y: i64, to_x: i64, to_y: i64) -> u64 {
    let dx = if from_x > to_x { from_x - to_x } else { to_x - from_x };
    let dy = if from_y > to_y { from_y - to_y } else { to_y - from_y };

    let dx_u64 = dx as u64;
    let dy_u64 = dy as u64;

    let dist_squared = dx_u64 * dx_u64 + dy_u64 * dy_u64;
    sqrt_u64(dist_squared)
}

/// Check if target is within range
pub fn is_within_range(distance: u64, range: u64) -> bool {
    distance <= range * 2
}
