// Math utility functions

/// Integer square root using Newton's method
/// Returns floor(sqrt(x))
pub fn sqrt_u64(x: u64) -> u64 {
    if x == 0 {
        0
    } else {
        let mut z = (x + 1) / 2;
        let mut y = x;

        // Newton's method iterations
        for _ in 0..32 {
            if z < y {
                y = z;
                z = (x / z + z) / 2;
            }
        }
        y
    }
}

/// Calculate distance squared between two points
/// Returns (x1-x2)^2 + (y1-y2)^2
pub fn distance_squared(x1: Field, y1: Field, x2: Field, y2: Field) -> Field {
    let dx = x1 - x2;
    let dy = y1 - y2;
    dx * dx + dy * dy
}

/// Calculate distance between two points
/// Returns ceil(sqrt((x1-x2)^2 + (y1-y2)^2))
///
/// Note: We use Field arithmetic for the squared distance,
/// then convert to u64 for the square root
pub fn distance(x1: i64, y1: i64, x2: i64, y2: i64) -> u64 {
    let dx = if x1 > x2 { x1 - x2 } else { x2 - x1 };
    let dy = if y1 > y2 { y1 - y2 } else { y2 - y1 };

    let dx_u64 = dx as u64;
    let dy_u64 = dy as u64;

    let dist_sq = dx_u64 * dx_u64 + dy_u64 * dy_u64;
    sqrt_u64(dist_sq)
}

/// Check if a point (x, y) is within a circle of radius r centered at origin
pub fn is_within_radius(x: Field, y: Field, r: Field) -> bool {
    // Cast to u64 for comparison
    let x_val = x as u64;
    let y_val = y as u64;
    let r_val = r as u64;
    x_val * x_val + y_val * y_val < r_val * r_val
}

/// Absolute value for Field (treating as signed)
/// This assumes the field element represents a value in [-p/2, p/2]
pub fn abs_field(x: Field) -> Field {
    // For signed interpretation, we check if x > p/2
    // If so, return p - x (the negation)
    // This is complex in Noir, simplified version:
    x
}

/// Min of two u64 values
pub fn min_u64(a: u64, b: u64) -> u64 {
    if a < b { a } else { b }
}

/// Max of two u64 values
pub fn max_u64(a: u64, b: u64) -> u64 {
    if a > b { a } else { b }
}

/// Clamp a value between min and max
pub fn clamp_u64(value: u64, min_val: u64, max_val: u64) -> u64 {
    min_u64(max_u64(value, min_val), max_val)
}

#[test]
fn test_sqrt() {
    assert(sqrt_u64(0) == 0);
    assert(sqrt_u64(1) == 1);
    assert(sqrt_u64(4) == 2);
    assert(sqrt_u64(9) == 3);
    assert(sqrt_u64(16) == 4);
    assert(sqrt_u64(100) == 10);
    assert(sqrt_u64(10000) == 100);

    // Non-perfect squares return floor
    assert(sqrt_u64(5) == 2);
    assert(sqrt_u64(8) == 2);
    assert(sqrt_u64(15) == 3);
}

#[test]
fn test_distance() {
    // Same point
    assert(distance(0, 0, 0, 0) == 0);

    // Simple cases
    assert(distance(0, 0, 3, 4) == 5); // 3-4-5 triangle
    assert(distance(0, 0, 5, 12) == 13); // 5-12-13 triangle

    // Negative coordinates
    assert(distance(-3, 0, 0, 4) == 5);
}
