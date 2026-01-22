// Reveal location logic helpers
// These are pure functions - actual contract entry points are in main.nr

use dep::aztec::protocol_types::address::AztecAddress;

/// Revealed coordinate information
/// Stored publicly after a player reveals their planet location
pub struct RevealedCoord {
    pub planet_id: Field,
    pub x: Field,
    pub y: Field,
    pub revealer: AztecAddress,
}

impl RevealedCoord {
    /// Create a new revealed coordinate entry
    pub fn new(
        planet_id: Field,
        x: Field,
        y: Field,
        revealer: AztecAddress,
    ) -> Self {
        Self { planet_id, x, y, revealer }
    }

    /// Create an empty (not revealed) entry
    pub fn empty() -> Self {
        Self {
            planet_id: 0,
            x: 0,
            y: 0,
            revealer: AztecAddress::zero(),
        }
    }

    /// Check if coordinates have been revealed
    pub fn is_revealed(self) -> bool {
        self.planet_id != 0
    }
}

/// Check if a player can reveal location based on cooldown
///
/// # Arguments
/// * `last_reveal_timestamp` - Player's last reveal time
/// * `current_timestamp` - Current block timestamp
/// * `cooldown` - Reveal cooldown in seconds (typically 24 hours)
///
/// # Returns
/// * true if enough time has passed since last reveal
pub fn can_reveal(
    last_reveal_timestamp: u64,
    current_timestamp: u64,
    cooldown: u64,
) -> bool {
    if last_reveal_timestamp == 0 {
        // Never revealed before
        true
    } else if current_timestamp >= last_reveal_timestamp + cooldown {
        true
    } else {
        false
    }
}

/// Calculate remaining cooldown time
///
/// # Returns
/// * Seconds until next reveal is allowed, or 0 if ready
pub fn get_reveal_cooldown_remaining(
    last_reveal_timestamp: u64,
    current_timestamp: u64,
    cooldown: u64,
) -> u64 {
    if last_reveal_timestamp == 0 {
        0
    } else {
        let elapsed = if current_timestamp > last_reveal_timestamp {
            current_timestamp - last_reveal_timestamp
        } else {
            0
        };

        if elapsed >= cooldown {
            0
        } else {
            cooldown - elapsed
        }
    }
}
