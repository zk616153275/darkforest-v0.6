// Hash functions - Poseidon2 implementation
// Using Aztec's Poseidon2 for performance and compatibility

use dep::aztec::protocol_types::hash::poseidon2_hash;

/// Compute planet ID using Poseidon2
///
/// Replaced MiMCSponge with Poseidon2 for performance optimization in Aztec.
///
/// Inputs:
/// - x: X coordinate
/// - y: Y coordinate
/// - key: Hash key (PLANETHASH_KEY)
///
/// Output: planet_id (Field)
pub fn compute_planet_hash(x: Field, y: Field, key: Field) -> Field {
    // Poseidon2 is the most efficient in-circuit hash algorithm in Aztec
    poseidon2_hash([x, y, key])
}

/// Compute random value for Perlin noise
pub fn compute_perlin_random(x: Field, y: Field, scale: Field, key: Field) -> Field {
    poseidon2_hash([x, y, scale, key])
}

/// Compute location commitment
/// Useful for "locking" coordinates in ZK proofs without revealing them.
pub fn compute_location_commitment(x: Field, y: Field, salt: Field) -> Field {
    poseidon2_hash([x, y, salt])
}

/// Extract 4 bits from hash for gradient selection (0-15)
pub fn hash_to_gradient_index(hash: Field) -> u8 {
    // Convert hash to bytes and extract the lowest 4 bits of the last byte
    let hash_bytes = hash.to_be_bytes::<32>();
    let lowest_byte = hash_bytes[31];
    lowest_byte & 0x0F
}

#[test]
fn test_planet_hash_not_zero() {
    let x: Field = 100;
    let y: Field = 200;
    let key: Field = 7; // PLANETHASH_KEY from game config

    let hash = compute_planet_hash(x, y, key);

    // Hash should not be zero
    assert(hash != 0);
}

#[test]
fn test_planet_hash_deterministic() {
    let x: Field = 100;
    let y: Field = 200;
    let key: Field = 7;

    let hash1 = compute_planet_hash(x, y, key);
    let hash2 = compute_planet_hash(x, y, key);

    // Same inputs should give same output
    assert(hash1 == hash2);
}

#[test]
fn test_different_coords_different_hash() {
    let key: Field = 7;

    let hash1 = compute_planet_hash(100, 200, key);
    let hash2 = compute_planet_hash(101, 200, key);
    let hash3 = compute_planet_hash(100, 201, key);

    // Different coordinates should give different hashes
    assert(hash1 != hash2);
    assert(hash1 != hash3);
    assert(hash2 != hash3);
}

#[test]
fn test_gradient_index_range() {
    let hash = compute_planet_hash(100, 200, 7);
    let index = hash_to_gradient_index(hash);

    // Index should be in range [0, 15]
    assert(index < 16);
}

#[test]
fn test_location_commitment_deterministic() {
    let x: Field = 123;
    let y: Field = 456;
    let salt: Field = 789;

    let commitment1 = compute_location_commitment(x, y, salt);
    let commitment2 = compute_location_commitment(x, y, salt);

    assert(commitment1 == commitment2);
    assert(commitment1 != 0);
}
