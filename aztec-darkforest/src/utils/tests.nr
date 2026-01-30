// Utils module tests - hash, perlin, math functions
use crate::utils::hash::compute_planet_hash;
use crate::utils::perlin::compute_perlin;
use crate::utils::math::distance;

#[test]
fn test_hash_consistency() {
    let x: Field = 100;
    let y: Field = 200;
    let key: Field = 7;

    let hash = compute_planet_hash(x, y, key);
    assert(hash != 0);
}

#[test]
fn test_perlin_range() {
    let x: Field = 100;
    let y: Field = 200;
    let key: Field = 8;
    let scale: u64 = 8192;

    let perlin = compute_perlin(x, y, key, scale);
    assert(perlin < 32); // Perlin should be in range 0-31
}

#[test]
fn test_distance_calculation() {
    // 3-4-5 triangle
    assert(distance(0, 0, 3, 4) == 5);

    // 5-12-13 triangle
    assert(distance(0, 0, 5, 12) == 13);
}
