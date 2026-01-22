# Dark Forest - Aztec Noir Implementation

This is the Aztec L2 implementation of Dark Forest, migrated from the original Ethereum L1 + Circom version.

## Key Features

- **Native Privacy**: Planet coordinates are stored in private Notes, only visible to owners
- **No Manual ZK Proofs**: Aztec protocol handles proof generation automatically
- **Optional Private Energy**: Hide your attack strength from other players
- **L2 Efficiency**: Lower gas costs on Aztec L2

## Project Structure

```
aztec-darkforest/
├── Nargo.toml              # Project configuration
├── src/
│   ├── main.nr             # Main contract entry point
│   ├── planet/
│   │   ├── mod.nr          # Planet module
│   │   ├── init.nr         # Player initialization
│   │   ├── move_planet.nr  # Planet movement
│   │   ├── reveal.nr       # Coordinate reveal
│   │   └── state.nr        # State management
│   ├── player/
│   │   ├── mod.nr          # Player module
│   │   └── state.nr        # Player state
│   ├── artifact/
│   │   └── mod.nr          # Artifact module (TODO)
│   ├── types/
│   │   ├── mod.nr          # Type definitions
│   │   ├── planet.nr       # Planet struct
│   │   ├── player.nr       # Player struct
│   │   ├── artifact.nr     # Artifact struct
│   │   ├── config.nr       # Game config
│   │   └── enums.nr        # Enums
│   ├── utils/
│   │   ├── mod.nr          # Utilities
│   │   ├── hash.nr         # MiMC hash
│   │   ├── perlin.nr       # Perlin noise
│   │   └── math.nr         # Math functions
│   └── notes/
│       ├── mod.nr          # Notes module
│       ├── coord_note.nr   # Private coordinates
│       └── energy_note.nr  # Private energy
└── test/
    └── main.test.nr        # Tests
```

## Prerequisites

1. Install Noir toolchain:

```bash
curl -L https://raw.githubusercontent.com/noir-lang/noirup/main/install | bash
noirup
```

2. Install Aztec Sandbox:

```bash
bash -i <(curl -s https://install.aztec.network)
aztec-up
```

## Getting Started

### 1. Start Local Aztec Network

```bash
aztec start --sandbox
```

### 2. Compile Contract

```bash
cd aztec-darkforest
nargo compile
```

### 3. Run Tests

```bash
nargo test
```

### 4. Deploy to Local Network

```bash
# TODO: Add deployment script
aztec deploy darkforest
```

## Development Status

### Phase 1: Environment ✅

- [x] Project structure created
- [x] Nargo.toml configured
- [x] Basic types defined

### Phase 2: Utilities 🔄

- [x] Hash function (placeholder)
- [x] Perlin noise (placeholder)
- [x] Math functions
- [ ] **TODO**: Verify MiMC matches Circom
- [ ] **TODO**: Implement full Perlin matching Circom

### Phase 3: Core Functions 🔄

- [x] `initialize_player` structure
- [x] `move_planet` structure
- [x] `reveal_location` structure
- [x] CoordNote implementation
- [x] EnergyNote implementation
- [ ] **TODO**: Complete all edge cases
- [ ] **TODO**: Integration testing

### Phase 4: Extended Features ⏳

- [ ] Artifact system
- [ ] Spaceship system
- [ ] Capture zones
- [ ] Admin functions

### Phase 5: Frontend ⏳

- [ ] Aztec.js integration
- [ ] Contract API rewrite
- [ ] UI adaptation

## Architecture Comparison

| Feature          | Original (Solidity) | Aztec (Noir)         |
| ---------------- | ------------------- | -------------------- |
| ZK Verification  | DFVerifierFacet     | Automatic            |
| Coordinates      | Client-side hidden  | On-chain private     |
| Energy           | Public              | Optionally private   |
| Contract Pattern | Diamond (EIP-2535)  | Modular Noir         |
| Proof Generation | snarkjs (client)    | Aztec.js (automatic) |

## Documentation

See `docs/aztec-migration/` for:

- [01-solidity-architecture.md](./docs/aztec-migration/01-solidity-architecture.md) - Original architecture analysis
- [02-aztec-noir-design.md](./docs/aztec-migration/02-aztec-noir-design.md) - Aztec design document
- [03-migration-checklist.md](./docs/aztec-migration/03-migration-checklist.md) - Migration task list

## License

Same as original Dark Forest project.
