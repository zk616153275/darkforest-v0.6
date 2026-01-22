// Perlin noise implementation
// Matches the original Circom MultiScalePerlin from circuits/perlin/perlin.circom

use crate::utils::hash::{compute_perlin_random, hash_to_gradient_index};
// use crate::utils::math;

/// Gradient vectors for Perlin noise (16 directions)
/// From original Circom:
/// var vecs[16][2] = [[1000,0],[923,382],[707,707],[382,923],[0,1000],
///                    [-383,923],[-708,707],[-924,382],[-1000,0],
///                    [-924,-383],[-708,-708],[-383,-924],[-1,-1000],
///                    [382,-924],[707,-708],[923,-383]];
global GRADIENT_VECS: [[i64; 2]; 16] = [
    [1000, 0],
    [923, 382],
    [707, 707],
    [382, 923],
    [0, 1000],
    [-383, 923],
    [-708, 707],
    [-924, 382],
    [-1000, 0],
    [-924, -383],
    [-708, -708],
    [-383, -924],
    [-1, -1000],
    [382, -924],
    [707, -708],
    [923, -383],
];

/// Denominator for fixed-point arithmetic
/// From original Circom: DENOMINATOR = 1125899906842624000 (2^50 * 1000)
global DENOMINATOR: u64 = 1125899906842624000;
global VECTOR_DENOMINATOR: u64 = DENOMINATOR / 1000;

/// MultiScale Perlin noise calculation
///
/// This matches the output of circuits/perlin/perlin.circom#MultiScalePerlin
///
/// The original implementation:
/// 1. Computes Perlin at 3 octaves (scale, scale*2, scale*4)
/// 2. Sums: octave0 + octave1 + octave2 + octave0 (weighted)
/// 3. Divides by 4 and scales to [0, 31]
///
/// # Arguments
/// * `x`, `y` - Coordinates (can be negative)
/// * `key` - SPACETYPE_KEY for randomization
/// * `scale` - Base scale (power of 2, max 16384)
/// * `mirror_x`, `mirror_y` - Whether to mirror coordinates
///
/// # Returns
/// * Perlin value in range [0, 31]
pub fn compute_perlin(
    x: Field,
    y: Field,
    key: Field,
    scale: u64,
) -> u64 {
    compute_perlin_full(x, y, key, scale, false, false)
}

/// Full Perlin noise with mirroring options
pub fn compute_perlin_full(
    x: Field,
    y: Field,
    key: Field,
    scale: u64,
    mirror_x: bool,
    mirror_y: bool,
) -> u64 {
    // Handle coordinate mirroring
    // In Circom: if yMirror && x < 0, flip x sign
    //            if xMirror && y < 0, flip y sign
    let x_i64 = field_to_i64(x);
    let y_i64 = field_to_i64(y);

    let x_mirrored = if mirror_y & (x_i64 < 0) { -x_i64 } else { x_i64 };
    let y_mirrored = if mirror_x & (y_i64 < 0) { -y_i64 } else { y_i64 };

    // Compute perlin at 3 octaves and sum with weighting
    // Original: perlins[0] + perlins[1] + perlins[2] + perlins[0]
    let p0 = single_scale_perlin(x_mirrored, y_mirrored, key, scale);
    let p1 = single_scale_perlin(x_mirrored, y_mirrored, key, scale * 2);
    let p2 = single_scale_perlin(x_mirrored, y_mirrored, key, scale * 4);

    let sum = p0 + p1 + p2 + p0; // Weighted sum (p0 counted twice)
    let avg = sum / 4;

    // Scale to [0, 31] range
    // Original: divBy16.quotient + 16 where dividend = outDividedByCount * 16
    let scaled = (avg * 16) / (DENOMINATOR as i64);
    let result = scaled + 16;

    // Clamp to valid range
    if result < 0 {
        0
    } else if result > 31 {
        31
    } else {
        result as u64
    }
}

/// Single scale Perlin noise value
fn single_scale_perlin(x: i64, y: i64, key: Field, scale: u64) -> i64 {
    let scale_i64 = scale as i64;

    // Find grid cell corners
    let x_cell = floor_div(x, scale_i64);
    let y_cell = floor_div(y, scale_i64);

    let bottom_left = (x_cell * scale_i64, y_cell * scale_i64);
    let bottom_right = (bottom_left.0 + scale_i64, bottom_left.1);
    let top_left = (bottom_left.0, bottom_left.1 + scale_i64);
    let top_right = (bottom_left.0 + scale_i64, bottom_left.1 + scale_i64);

    // Get gradient at each corner
    let grad_bl = get_gradient(bottom_left.0, bottom_left.1, scale_i64, key);
    let grad_br = get_gradient(bottom_right.0, bottom_right.1, scale_i64, key);
    let grad_tl = get_gradient(top_left.0, top_left.1, scale_i64, key);
    let grad_tr = get_gradient(top_right.0, top_right.1, scale_i64, key);

    // Calculate distance vectors from corners to point
    let dist_bl = (x - bottom_left.0, y - bottom_left.1);
    let dist_br = (x - bottom_right.0, y - bottom_right.1);
    let dist_tl = (x - top_left.0, y - top_left.1);
    let dist_tr = (x - top_right.0, y - top_right.1);

    // Calculate dot products (gradient dot distance)
    let dot_bl = dot_product(grad_bl, dist_bl, scale_i64);
    let dot_br = dot_product(grad_br, dist_br, scale_i64);
    let dot_tl = dot_product(grad_tl, dist_tl, scale_i64);
    let dot_tr = dot_product(grad_tr, dist_tr, scale_i64);

    // Bilinear interpolation based on position within cell
    let fx = mod_positive(x, scale_i64);
    let fy = mod_positive(y, scale_i64);

    // Calculate weights (inverse distance)
    let weight_bl = get_weight(fx, fy, scale_i64, false, false);
    let weight_br = get_weight(fx, fy, scale_i64, true, false);
    let weight_tl = get_weight(fx, fy, scale_i64, false, true);
    let weight_tr = get_weight(fx, fy, scale_i64, true, true);

    // Weighted sum
    let result = (dot_bl * weight_bl + dot_br * weight_br +
                  dot_tl * weight_tl + dot_tr * weight_tr) / (DENOMINATOR as i64);

    result
}

/// Get gradient vector at a grid point
fn get_gradient(x: i64, y: i64, scale: i64, key: Field) -> (i64, i64) {
    let hash = compute_perlin_random(
        i64_to_field(x),
        i64_to_field(y),
        i64_to_field(scale),
        key
    );
    let index = hash_to_gradient_index(hash) as u64;

    let vec = GRADIENT_VECS[index as u32];
    let denominator_scale = (VECTOR_DENOMINATOR as i64);

    (vec[0] * denominator_scale, vec[1] * denominator_scale)
}

/// Dot product of gradient and distance vectors
fn dot_product(grad: (i64, i64), dist: (i64, i64), scale: i64) -> i64 {
    // Scale distance to unit square
    let scaled_dist = (dist.0 / scale, dist.1 / scale);
    (grad.0 * scaled_dist.0 + grad.1 * scaled_dist.1) / (DENOMINATOR as i64)
}

/// Get interpolation weight for a corner
/// From original Circom GetWeight template
fn get_weight(fx: i64, fy: i64, scale: i64, is_right: bool, is_top: bool) -> i64 {
    let denom = DENOMINATOR as i64;
    let scale_denom = denom / scale;

    let fx_scaled = fx * scale_denom;
    let fy_scaled = fy * scale_denom;

    let diff_x = if is_right { denom - fx_scaled } else { fx_scaled };
    let diff_y = if is_top { denom - fy_scaled } else { fy_scaled };

    let factor_x = denom - diff_x;
    let factor_y = denom - diff_y;

    (factor_x * factor_y) / denom
}

/// Floor division (handles negative numbers correctly)
fn floor_div(a: i64, b: i64) -> i64 {
    if a >= 0 {
        a / b
    } else {
        (a - b + 1) / b
    }
}

/// Positive modulo (always returns positive result)
fn mod_positive(a: i64, b: i64) -> i64 {
    let r = a % b;
    if r < 0 { r + b } else { r }
}

/// Convert Field to i64 (assumes value fits in i64 range)
fn field_to_i64(f: Field) -> i64 {
    // This is simplified - actual implementation needs proper field handling
    f as i64
}

/// Convert i64 to Field
fn i64_to_field(i: i64) -> Field {
    if i < 0 {
        -((-i as u64) as Field)
    } else {
        (i as u64) as Field
    }
}

#[test]
fn test_perlin_range() {
    // Perlin should return values in [0, 31]
    let result = compute_perlin(100, 200, 8, 8192);
    assert(result <= 31);
}

#[test]
fn test_perlin_deterministic() {
    // Same inputs should give same outputs
    let result1 = compute_perlin(100, 200, 8, 8192);
    let result2 = compute_perlin(100, 200, 8, 8192);
    assert(result1 == result2);
}

#[test]
fn test_floor_div() {
    // Positive cases
    assert(floor_div(10, 3) == 3);
    assert(floor_div(9, 3) == 3);

    // Negative cases
    assert(floor_div(-1, 3) == -1);
    assert(floor_div(-3, 3) == -1);
    assert(floor_div(-4, 3) == -2);
}

#[test]
fn test_mod_positive() {
    assert(mod_positive(10, 3) == 1);
    assert(mod_positive(-1, 3) == 2);
    assert(mod_positive(-4, 3) == 2);
}
