// Module declarations
mod types;
mod notes;
mod utils;
mod planet;
mod player;
mod artifact; // TODO: Implement artifact module

use aztec::macros::aztec;

#[aztec]
pub contract DarkForest {
    use aztec::{
        protocol_types::address::AztecAddress,
        macros::{functions::{external, initializer, internal, view}, storage::storage},
        state_vars::{public_mutable::PublicMutable},
    };

    // Storage structure
    #[storage]
    struct Storage<Context> {
        admin: PublicMutable<AztecAddress, Context>,
        paused: PublicMutable<bool, Context>,
        world_radius: PublicMutable<u64, Context>,
        planet_count: PublicMutable<u64, Context>,
        player_count: PublicMutable<u64, Context>,
    }

    // Constructor - called once when contract is deployed
    #[external("public")]
    #[initializer]
    fn constructor(admin: AztecAddress, world_radius: u64) {
        self.storage.admin.write(admin);
        self.storage.world_radius.write(world_radius);
        self.storage.paused.write(false);
        self.storage.planet_count.write(0);
        self.storage.player_count.write(0);
    }

    // Pause the game (admin only)
    #[external("public")]
    fn pause() {
        let sender = self.context.msg_sender().unwrap();
        assert(sender == self.storage.admin.read(), "Not admin");
        self.storage.paused.write(true);
    }

    // Unpause the game (admin only)
    #[external("public")]
    fn unpause() {
        let sender = self.context.msg_sender().unwrap();
        assert(sender == self.storage.admin.read(), "Not admin");
        self.storage.paused.write(false);
    }

    // Check if game is paused
    #[external("public")]
    #[view]
    fn is_paused() -> pub bool {
        self.storage.paused.read()
    }

    // Get world radius
    #[external("public")]
    #[view]
    fn get_world_radius() -> pub u64 {
        self.storage.world_radius.read()
    }

    // Get planet count
    #[external("public")]
    #[view]
    fn get_planet_count() -> pub u64 {
        self.storage.planet_count.read()
    }

    // Get player count
    #[external("public")]
    #[view]
    fn get_player_count() -> pub u64 {
        self.storage.player_count.read()
    }
}
