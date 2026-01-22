// Player state management helpers
// Pure functions for player state operations

/// Calculate new score after adding points
pub fn calculate_score_after_add(current_score: u64, amount: u64) -> u64 {
    current_score + amount
}

/// Calculate new score after deducting points
/// Returns (success, new_score) - success is false if underflow would occur
pub fn calculate_score_after_deduct(current_score: u64, amount: u64) -> (bool, u64) {
    if current_score >= amount {
        (true, current_score - amount)
    } else {
        (false, current_score)
    }
}

/// Calculate new space junk after adding
/// Returns (success, new_junk) - success is false if would exceed limit
pub fn calculate_junk_after_add(
    current_junk: u64,
    amount: u64,
    junk_limit: u64,
) -> (bool, u64) {
    let new_junk = current_junk + amount;
    if new_junk > junk_limit {
        (false, current_junk)
    } else {
        (true, new_junk)
    }
}

/// Calculate new space junk after removing
pub fn calculate_junk_after_remove(current_junk: u64, amount: u64) -> u64 {
    if current_junk >= amount {
        current_junk - amount
    } else {
        0
    }
}

/// Check if player can reveal location based on cooldown
pub fn can_reveal_location(
    last_reveal_timestamp: u64,
    current_timestamp: u64,
    cooldown: u64,
) -> bool {
    if last_reveal_timestamp == 0 {
        true
    } else {
        current_timestamp >= last_reveal_timestamp + cooldown
    }
}
