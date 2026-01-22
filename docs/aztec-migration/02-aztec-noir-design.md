# Dark Forest Aztec Noir 合约设计方案

## 1. 架构差异

| 特性         | 原 Solidity         | Aztec Noir               |
| ------------ | ------------------- | ------------------------ |
| **隐私模型** | 公开状态 + 客户端ZK | **原生私有状态** (Notes) |
| **ZK 验证**  | 独立 Verifier 合约  | **协议层自动验证**       |
| **合约模式** | Diamond 代理模式    | **模块化合约**           |
| **状态存储** | 公开 mapping        | 私有 Notes + 公开状态    |
| **证明生成** | 前端 snarkjs        | **Aztec.js 自动处理**    |

### 删除的组件

- DFVerifierFacet (协议自动验证)
- SnarkArgsHelper.ts (不需要手动证明)
- Circom 电路 (.circom)
- 密钥文件 (.wasm, .zkey)

---

## 2. 合约文件结构

```
aztec-darkforest/
├── Nargo.toml
├── src/
│   ├── main.nr                 # 主合约入口
│   ├── planet/
│   │   ├── mod.nr              # 星球模块
│   │   ├── state.nr            # 状态管理
│   │   ├── move.nr             # 移动逻辑
│   │   └── init.nr             # 初始化
│   ├── player/
│   │   └── mod.nr              # 玩家模块
│   ├── artifact/
│   │   └── mod.nr              # 神器模块
│   ├── types/
│   │   ├── planet.nr           # Planet 结构
│   │   ├── player.nr           # Player 结构
│   │   └── artifact.nr         # Artifact 结构
│   ├── utils/
│   │   ├── hash.nr             # MiMC 哈希
│   │   └── perlin.nr           # Perlin 噪声
│   └── notes/
│       ├── coord_note.nr       # 坐标 Note
│       └── energy_note.nr      # 能量 Note
└── test/
    └── main.test.nr
```

---

## 3. Notes (私有状态) 设计

### CoordNote - 私有坐标

```rust
struct CoordNote {
    owner: AztecAddress,        // Note 拥有者
    planet_id: Field,           // 星球 ID (公开的 hash)
    x: Field,                   // 私有 X 坐标
    y: Field,                   // 私有 Y 坐标
    perlin: Field,              // perlin 值
    randomness: Field,          // 防碰撞随机值
}
```

### EnergyNote - 私有能量

```rust
struct EnergyNote {
    owner: AztecAddress,
    planet_id: Field,
    energy: u64,                // 私有能量值
    randomness: Field,
}
```

---

## 4. 公开状态设计

### PlanetPublicState

```rust
struct PlanetPublicState {
    planet_id: Field,
    owner: AztecAddress,
    level: u8,
    planet_type: u8,
    space_type: u8,
    range: u64,
    speed: u64,
    defense: u64,
    population_cap: u64,
    population_growth: u64,
    silver_cap: u64,
    silver_growth: u64,
    last_updated: u64,
    is_destroyed: bool,
}
```

### PlayerPublicState

```rust
struct PlayerPublicState {
    address: AztecAddress,
    is_initialized: bool,
    home_planet_id: Field,
    score: u64,
    space_junk: u64,
    last_reveal_timestamp: u64,
}
```

---

## 5. 核心函数设计

### 5.1 玩家初始化

```rust
#[aztec(private)]
fn initialize_player(
    x: Field,           // 私有: 出生点 X
    y: Field,           // 私有: 出生点 Y
) -> Field {
    // 1. 计算星球 ID (MiMC hash)
    let planet_id = compute_planet_hash(x, y);

    // 2. 验证坐标在边界内
    assert(x * x + y * y < radius * radius);

    // 3. 验证 perlin 在初始化范围
    let perlin = compute_perlin(x, y);
    assert(perlin >= INIT_PERLIN_MIN && perlin < INIT_PERLIN_MAX);

    // 4. 创建私有 CoordNote
    let coord_note = CoordNote::new(sender, planet_id, x, y, perlin);
    storage.coord_notes.at(sender).insert(&mut coord_note);

    // 5. 创建初始 EnergyNote
    let energy_note = EnergyNote::new(sender, planet_id, INITIAL_POPULATION);
    storage.energy_notes.at(planet_id).insert(&mut energy_note);

    // 6. 调用公开函数更新状态
    context.call_public_function("_init_player_public", [...]);

    planet_id
}
```

### 5.2 星球移动

```rust
#[aztec(private)]
fn move_planet(
    from_x: Field, from_y: Field,  // 私有坐标
    to_x: Field, to_y: Field,      // 私有坐标
    from_planet_id: Field,         // 公开
    to_planet_id: Field,           // 公开
    energy_moved: u64,
    silver_moved: u64,
) {
    // 1. 验证坐标哈希
    assert(compute_planet_hash(from_x, from_y) == from_planet_id);
    assert(compute_planet_hash(to_x, to_y) == to_planet_id);

    // 2. 验证目标在边界内
    assert(to_x * to_x + to_y * to_y < radius * radius);

    // 3. 计算距离
    let distance = sqrt((from_x - to_x)^2 + (from_y - to_y)^2);

    // 4. 消耗能量 Note, 创建新 Note
    let energy_note = storage.energy_notes.at(from_planet_id).get_and_remove();
    assert(energy_note.energy >= energy_moved);

    let new_note = EnergyNote::new(sender, from_planet_id,
                                   energy_note.energy - energy_moved);
    storage.energy_notes.at(from_planet_id).insert(&mut new_note);

    // 5. 调用公开函数处理到达
    context.call_public_function("_execute_move", [...]);
}
```

### 5.3 揭示坐标

```rust
#[aztec(private)]
fn reveal_location(
    x: Field,
    y: Field,
    planet_id: Field,
) {
    // 1. 验证坐标
    assert(compute_planet_hash(x, y) == planet_id);

    // 2. 验证拥有坐标 Note
    let coord_note = storage.coord_notes.at(sender)
        .get_note_matching(|n| n.planet_id == planet_id);
    assert(coord_note.is_some());

    // 3. 公开揭示
    context.call_public_function("_reveal_public", [planet_id, x, y]);
}
```

---

## 6. 隐私增强

| 数据     | 原 Solidity              | Aztec Noir       |
| -------- | ------------------------ | ---------------- |
| 星球坐标 | 客户端隐藏，链上公开hash | **链上完全私有** |
| 当前能量 | 链上公开                 | **可选私有**     |
| 移动距离 | 链上公开                 | **私有**         |
| 银矿数量 | 链上公开                 | **可选私有**     |

---

## 7. 函数迁移对照

| 原 Solidity                     | Aztec Noir                     | 变化     |
| ------------------------------- | ------------------------------ | -------- |
| `initializePlayer(a,b,c,input)` | `initialize_player(x,y)`       | 无ZK参数 |
| `move(a,b,c,input,...)`         | `move_planet(x1,y1,x2,y2,...)` | 坐标私有 |
| `revealLocation(a,b,c,input)`   | `reveal_location(x,y,id)`      | 简化     |
| `findArtifact(a,b,c,input)`     | `find_artifact(x,y)`           | 坐标私有 |
| `verifyMoveProof(...)`          | **删除**                       | 自动验证 |

---

## 8. 前端适配

### Aztec.js 调用示例

```typescript
import { Contract, Fr } from '@aztec/aztec.js';

// 初始化玩家 - 无需手动 ZK 证明!
const tx = await contract.methods
  .initialize_player(
    new Fr(x), // 私有输入, 不会出现在链上
    new Fr(y)
  )
  .send()
  .wait();

// 星球移动
const tx = await contract.methods
  .move_planet(
    new Fr(fromX),
    new Fr(fromY), // 私有
    new Fr(toX),
    new Fr(toY), // 私有
    new Fr(fromPlanetId), // 公开
    new Fr(toPlanetId), // 公开
    BigInt(energy),
    BigInt(silver)
  )
  .send()
  .wait();
```

### 可复用代码

- `Frontend/` - 90% 复用
- `packages/renderer/` - 100% 复用
- `Backend/GameLogic/` - 70% 复用

### 需删除

- `SnarkArgsHelper.ts`
- `packages/snarks/`
- snarkjs 依赖

---

## 9. 开发优先级

1. **P0**: MiMC/Perlin 工具函数
2. **P0**: 玩家初始化 (`initialize_player`)
3. **P0**: 星球移动 (`move_planet`)
4. **P1**: 坐标揭示 (`reveal_location`)
5. **P1**: 能量刷新逻辑
6. **P2**: 神器系统
7. **P2**: 飞船系统
8. **P3**: 捕获区域
