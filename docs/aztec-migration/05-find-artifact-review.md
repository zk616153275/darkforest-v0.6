# Find Artifact 逻辑审查报告

> 对比 Circom/Solidity (v0.6) 与 Aztec Noir 实现的差异

## 📌 审查范围

| 层级     | Solidity/Circom                     | Aztec Noir                        |
| -------- | ----------------------------------- | --------------------------------- |
| ZK 电路  | `circuits/biomebase/circuit.circom` | 内置于 `main.nr#find_artifact`    |
| 合约入口 | `DFArtifactFacet.sol#findArtifact`  | `main.nr#find_artifact` (private) |
| 核心逻辑 | `LibArtifactUtils.sol#findArtifact` | `main.nr#find_artifact_callback`  |
| 随机生成 | `LibGameUtils.sol`                  | `artifact/discovery.nr`           |

---

## 🔴 关键差异总结

| #   | Diff               | Solidity/Circom                             | Noir Status                    | Severity  |
| --- | ------------------ | ------------------------------------------- | ------------------------------ | --------- |
| 1   | Prospect mechanism | Two-step: `prospectPlanet` + `findArtifact` | [ ] Deferred (needs design)    | 🔴 High   |
| 2   | Random source      | `blockhash(prospectedBlockNumber)`          | [ ] Deferred (needs Aztec RNG) | 🔴 High   |
| 3   | Planet type check  | Must be `PlanetType.RUINS`                  | [x] DONE                       | 🔴 High   |
| 4   | Gear Ship check    | Requires Gear Ship on planet                | [ ] Optional feature           | 🟡 Medium |
| 5   | Biome calculation  | ZK circuit proves biomebase                 | [x] DONE (simplified)          | 🟡 Medium |
| 6   | Rarity algorithm   | Based on planet level + bonus               | [x] DONE                       | 🔴 High   |
| 7   | Artifact Type dist | 8 types + biome influence                   | [x] DONE                       | 🟡 Medium |
| 8   | Player score       | Add to player.score                         | [x] DONE                       | 🟡 Medium |
| 9   | Prospect expiry    | Valid for 256 blocks                        | [ ] Deferred (depends on #1)   | 🟡 Medium |
| 10  | Energy cost        | No direct cost                              | [x] DONE (50% pop cost)        | 📝 Design |

---

## 📋 详细差异分析

### DIFF-1: Prospect 两步机制 🔴

**Solidity 实现（两步）：**

```solidity
// 第一步：prospectPlanet - 锁定随机种子
function prospectPlanet(uint256 locationId) public {
    Planet storage planet = gs().planets[locationId];
    require(planet.planetType == PlanetType.RUINS);  // ← 必须是 RUINS
    require(planet.prospectedBlockNumber == 0);       // ← 未 prospect 过

    if (gameConstants().SPACESHIPS.GEAR) {
        require(containsGear(locationId));            // ← 需要 Gear Ship
    }

    planet.prospectedBlockNumber = block.number;      // ← 锁定区块号
}

// 第二步：findArtifact - 使用锁定的区块 hash 生成随机种子
function findArtifact(...) {
    require(planet.prospectedBlockNumber != 0);
    require(block.number - planet.prospectedBlockNumber < 256);  // ← 256 区块内有效

    uint256 artifactSeed = keccak256(
        planetId,
        blockhash(planet.prospectedBlockNumber)  // ← 使用 blockhash 作为随机源
    );
}
```

**Noir 实现（单步）：**

```rust
#[external("private")]
fn find_artifact(x: Field, y: Field, planet_id: Field) {
    // 直接调用，无 prospect 步骤
    self.enqueue_self.find_artifact_callback(planet_id, sender);
}

fn find_artifact_callback(...) {
    // 无 RUINS 检查
    // 无 Gear Ship 检查
    // 使用固定 pedersen hash 而非 blockhash
    if crate::artifact::discovery::is_artifact_found(planet_id) { ... }
}
```

**TODO：**

- [ ] 考虑是否需要 prospect 机制（Aztec 没有 blockhash 可用）
- [ ] 添加 RUINS 星球类型检查
- [ ] 添加 Gear Ship 检查（如果启用 SPACESHIPS.GEAR）

---

### DIFF-2: 随机源差异 🔴

**Solidity：**

```solidity
uint256 artifactSeed = keccak256(
    planetId,
    coreAddress,
    blockhash(planet.prospectedBlockNumber)  // 动态、不可预测
);
```

**Noir：**

```rust
let hash = dep::std::hash::pedersen_hash([planet_id, 8888]);  // 静态、可预测
```

**问题：**

- Noir 使用固定种子 `8888`，结果完全可预测
- 玩家可以在链下预计算任意星球是否有 artifact

**TODO：**

- [ ] 需要引入不可预测的随机源（如 Aztec randomness oracle 或链上状态）
- [ ] 或改用 commit-reveal 模式模拟 prospect 机制

---

### DIFF-3: Rarity 算法差异 🔴

**Solidity - 基于 Planet Level：**

```solidity
function artifactRarityFromPlanetLevel(uint256 planetLevel) returns (ArtifactRarity) {
    if (planetLevel <= 1) return ArtifactRarity.Common;      // Level 0-1
    else if (planetLevel <= 3) return ArtifactRarity.Rare;   // Level 2-3
    else if (planetLevel <= 5) return ArtifactRarity.Epic;   // Level 4-5
    else if (planetLevel <= 7) return ArtifactRarity.Legendary;
    else return ArtifactRarity.Mythic;
}

// 还有 levelBonus 机制
if (secondLastByteOfSeed < 4)  bonus = 2;
else if (secondLastByteOfSeed < 16) bonus = 1;

// 最终 rarity = artifactRarityFromPlanetLevel(planet.level + bonus)
```

**Noir - 固定概率：**

```rust
let roll = bytes[31] as u8;
if roll < 150 { ArtifactRarity::COMMON() }       // ~60%
else if roll < 220 { ArtifactRarity::RARE() }   // ~25%
else if roll < 245 { ArtifactRarity::EPIC() }   // ~10%
else if roll < 253 { ArtifactRarity::LEGENDARY() }
else { ArtifactRarity::MYTHIC() }
```

**TODO：**

- [ ] 修改 `roll_rarity` 使用 planet level 影响
- [ ] 实现 level bonus 机制

---

### DIFF-4: Artifact Type 分布差异 🟡

**Solidity - 详细分布 + Biome 影响：**

```solidity
if (lastByte < 39) artifactType = Monolith;
else if (lastByte < 78) artifactType = Colossus;
// Spaceship commented out
else if (lastByte < 156) artifactType = Pyramid;
else if (lastByte < 171) artifactType = Wormhole;
else if (lastByte < 186) artifactType = PlanetaryShield;
else if (lastByte < 201) artifactType = PhotoidCannon;
else if (lastByte < 216) artifactType = BloomFilter;
else if (lastByte < 231) artifactType = BlackDomain;
else {
    // Biome 影响最后的类型
    if (biome == Ice) artifactType = PlanetaryShield;
    else if (biome == Lava) artifactType = PhotoidCannon;
    // ...
}
```

**Noir - 简化 5 种：**

```rust
if roll < 50 { MONOLITH() }
else if roll < 100 { COLOSSUS() }
else if roll < 150 { SPACESHIP() }  // Note: Solidity 里注释掉了
else if roll < 200 { PYRAMID() }
else { WORMHOLE() }
```

**TODO：**

- [ ] 添加 PlanetaryShield, PhotoidCannon, BloomFilter, BlackDomain 类型
- [ ] 实现 biome 对类型的影响
- [ ] 考虑移除 SPACESHIP（Solidity 里被注释）

---

### DIFF-5: Biome 计算 🟡

**Solidity/Circom：**

```
biomebase/circuit.circom 证明:
- MiMCSponge(x, y, PLANETHASH_KEY) = hash
- perlin(x, y, BIOMEBASE_KEY) = biomeBase

LibGameUtils._getBiome(spaceType, biomebase) 计算最终 biome
```

**Noir：**

```rust
// 使用存储的 perlin 值，未使用单独的 biomebase
let planet_perlin = planet.perlin;
let artifact_type = roll_artifact_type(planet_id, planet_perlin as u8);
```

**问题：**

- Noir 未区分 spacetype perlin 和 biomebase perlin
- 原版使用两个不同的 perlin key

**TODO：**

- [ ] 考虑是否需要实现 biomebase 逻辑
- [ ] 或简化为统一使用 spacetype perlin

---

### DIFF-6: 能量消耗 📝

**Solidity：** 无直接能量消耗（通过 prospect 机制隐式限制）

**Noir：**

```rust
let cost = planet.population_cap / 2;
assert(planet.population >= cost, "Insufficient energy for prospecting");
planet.population -= cost;
```

**评估：** 这是一个合理的设计变更，补偿了移除 prospect 机制后的平衡

---

### DIFF-7: 玩家积分 🟡

**Solidity：**

```solidity
gs().players[msg.sender].score += gameConstants().ARTIFACT_POINT_VALUES[
    uint256(foundArtifact.rarity)
];
```

**Noir：** 未实现

**TODO：**

- [ ] 添加 ARTIFACT_POINT_VALUES 配置
- [ ] 在 find_artifact_callback 中更新玩家积分

---

## 📝 函数 TODO 注释模板

### main.nr#find_artifact

```rust
/// TODO REVIEW DIFFS:
/// - [ ] DIFF-1: 添加 prospect 机制或替代方案
/// - [ ] DIFF-3: RUINS 星球类型检查
/// - [ ] DIFF-4: Gear Ship 检查
```

### main.nr#find_artifact_callback

```rust
/// TODO REVIEW DIFFS:
/// - [ ] DIFF-2: 随机源需要改进（blockhash 替代）
/// - [ ] DIFF-5: Rarity 应基于 planet level
/// - [ ] DIFF-6: Artifact type 分布需要扩展
/// - [ ] DIFF-7: 添加玩家积分更新
```

### artifact/discovery.nr#is_artifact_found

```rust
/// TODO REVIEW DIFFS:
/// - [ ] DIFF-2: 随机源可预测，需改进
```

### artifact/discovery.nr#roll_rarity

```rust
/// TODO REVIEW DIFFS:
/// - [ ] DIFF-5: 应使用 planet level 而非固定概率
/// - [ ] DIFF-5: 实现 level bonus 机制
```

### artifact/discovery.nr#roll_artifact_type

```rust
/// TODO REVIEW DIFFS:
/// - [ ] DIFF-6: 添加更多 artifact 类型
/// - [ ] DIFF-6: 实现 biome 对类型的影响
```

---

## ✅ 一致性检查通过项

| 项目             | 描述                                                  |
| ---------------- | ----------------------------------------------------- |
| ✅ ZK 证明坐标   | 私有函数验证 `compute_planet_hash(x, y) == planet_id` |
| ✅ 所有权检查    | `planet.owner == sender`                              |
| ✅ 已搜索检查    | `has_tried_finding_artifact` 标志                     |
| ✅ 星球刷新      | 调用 `_refresh_planet_internal`                       |
| ✅ Artifact 存储 | 创建 ArtifactState 并存储                             |
| ✅ 事件发射      | 发出 ArtifactFound 事件                               |

---

## 🔗 相关文件

- [DFArtifactFacet.sol](file:///home/zk/web3-projects/darkforest-v0.6/eth/contracts/facets/DFArtifactFacet.sol)
- [LibArtifactUtils.sol](file:///home/zk/web3-projects/darkforest-v0.6/eth/contracts/libraries/LibArtifactUtils.sol)
- [LibGameUtils.sol](file:///home/zk/web3-projects/darkforest-v0.6/eth/contracts/libraries/LibGameUtils.sol)
- [biomebase/circuit.circom](file:///home/zk/web3-projects/darkforest-v0.6/circuits/biomebase/circuit.circom)
- [main.nr](file:///home/zk/web3-projects/darkforest-v0.6/aztec-darkforest/src/main.nr)
- [artifact/discovery.nr](file:///home/zk/web3-projects/darkforest-v0.6/aztec-darkforest/src/artifact/discovery.nr)
