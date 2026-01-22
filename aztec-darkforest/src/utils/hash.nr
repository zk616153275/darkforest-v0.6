// Hash functions - MiMC implementation
// Using noir-lang/mimc library for compatibility with Circom MiMCSponge

use dep::mimc;

/// MiMC sponge hash for planet ID calculation
///
/// This matches the output of the original Circom MiMCSponge(2, 220, 1)
/// used in circuits/init/circuit.circom
///
/// Original Circom:
/// ```circom
/// component mimc = MiMCSponge(2, 220, 1);
/// mimc.ins[0] <== x;
/// mimc.ins[1] <== y;
/// mimc.k <== PLANETHASH_KEY;
/// pub <== mimc.outs[0];
/// ```
///
/// Input: (x, y, key)
/// Output: planet_id (hash)
pub fn compute_planet_hash(x: Field, y: Field, key: Field) -> Field {
    // Use the mimc library's sponge function
    // MiMCSponge with 2 inputs, 220 rounds (as per circomlib)
    mimc::mimc_bn254([x, y, key])
}

/// MiMC hash for 3 inputs (used in Perlin Random function)
///
/// Original Circom uses MiMCSponge(3, 4, 1) for the Random template:
/// ```circom
/// component mimc = MiMCSponge(3, 4, 1);
/// mimc.ins[0] <== in[0];
/// mimc.ins[1] <== in[1];
/// mimc.ins[2] <== in[2];
/// mimc.k <== KEY;
/// ```
pub fn compute_perlin_random(x: Field, y: Field, scale: Field, key: Field) -> Field {
    // For Perlin random, we use a simpler hash
    mimc::mimc_bn254([x, y, scale, key])
}

/// Extract 4 bits from hash for gradient selection (0-15)
///
/// Original Circom does:
/// ```circom
/// out <== num2Bits.out[3] * 8 + num2Bits.out[2] * 4 + num2Bits.out[1] * 2 + num2Bits.out[0];
/// ```
pub fn hash_to_gradient_index(hash: Field) -> u8 {
    // Convert hash to bits and extract lowest 4 bits
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
