# Move Planet 逻辑审查报告

> 对比 Circom/Solidity (v0.6) 与 Aztec Noir 实现的差异

## 📌 审查范围

| 层级     | Solidity/Circom                    | Aztec Noir                         |
| -------- | ---------------------------------- | ---------------------------------- |
| ZK 电路  | `circuits/move/circuit.circom`     | 内置于 `main.nr#move_planet`       |
| 合约入口 | `DFMoveFacet.sol#move`             | `main.nr#move_planet` (private)    |
| 核心逻辑 | `DFMoveFacet.sol#_executeMove`     | `main.nr#move_callback` (public)   |
| 星球刷新 | `LibPlanet.sol#refreshPlanet`      | `main.nr#_refresh_planet_internal` |
| 到达处理 | `LibPlanet.sol#_applyPendingEvent` | `move_planet.nr#apply_arrival`     |

---

## 🔴 关键差异总结

| #   | Diff                     | Solidity/Circom                         | Noir Status                    | Severity  |
| --- | ------------------------ | --------------------------------------- | ------------------------------ | --------- |
| 1   | Travel time delay        | `arrival_time = block.timestamp + time` | [x] DONE                       | 🔴 High   |
| 2   | Refresh planet before op | `refreshPlanet()` at start of every fn  | [x] DONE                       | 🔴 High   |
| 3   | Min travel time          | `if (travelTime == 0) travelTime = 1`   | [x] DONE                       | 🔴 High   |
| 4   | Energy decay             | `calcDecay(popMoved, dist, range)`      | [x] DONE                       | 🔴 High   |
| 5   | Range check              | `distance <= range`                     | [x] DONE                       | 🔴 High   |
| 6   | World radius check       | `require(newRadius <= worldRadius)`     | [x] DONE                       | 🔴 High   |
| 7   | DOS protection           | `checkPlanetDOS()`                      | [ ] Not implemented            | 🟡 Medium |
| 8   | Wormhole artifact        | `_checkWormhole()` distance modifier    | [ ] Not implemented            | 🟡 Medium |
| 9   | Photoid cannon           | `_checkPhotoid()` attack boost          | [ ] Not implemented            | 🟡 Medium |
| 10  | Abandon planet           | `_abandonPlanet()` transfer all + junk  | [ ] Not implemented            | 🟡 Medium |
| 11  | Spaceship moves          | Special rules for ships                 | [ ] Not implemented            | 🟡 Medium |
| 12  | Artifact transport       | `movedArtifactId` field                 | [ ] Not implemented            | 🟠 Low    |
| 13  | Planet events array      | `planetEvents[]` array                  | [x] DONE (planet_arrivals map) | ✅ Done   |
| 14  | Arrival Type             | `Normal/Wormhole/Photoid`               | [ ] Simplified to single type  | 🟠 Low    |

---

## 📋 详细差异分析

### DIFF-1: 旅行时间延迟 ✅ DONE

**Solidity：**

```solidity
// DFMoveFacet.sol#_executeMove
uint256 travelTime = effectiveDistTimesHundred / gs().planets[args.oldLoc].speed;

gs().planetEvents[args.newLoc].push(
    PlanetEventMetadata(
        gs().planetEventsCount,
        PlanetEventType.ARRIVAL,
        block.timestamp + travelTime,  // ← arrival time
        block.timestamp
    )
);
```

**Noir：**

```rust
// main.nr#move_callback
let mut travel_time = crate::planet::move_planet::calculate_travel_time(distance, from_planet.speed);
if travel_time == 0 { travel_time = 1; }
let arrival_time = timestamp + travel_time;

let arrival = crate::types::arrival::ArrivalData {
    arrival_time: arrival_time,
    // ...
};
```

**状态：** ✅ 完成

---

### DIFF-2: 操作前刷新星球 ✅ DONE

**Solidity：**

```solidity
// DFMoveFacet.sol#move
LibPlanet.refreshPlanet(args.oldLoc);  // 刷新源星球
if (gs().planets[args.newLoc].isInitialized) {
    LibPlanet.refreshPlanet(args.newLoc);  // 刷新目标星球
}
```

**Noir：**

```rust
// main.nr#move_callback
self.internal._refresh_planet_internal(from_planet_id);

// 在 upgrade_planet, find_artifact_callback 中也调用
self.internal._refresh_planet_internal(planet_id);
```

**状态：** ✅ 完成

---

### DIFF-3: 最小旅行时间 ✅ DONE

**Solidity：**

```solidity
if (travelTime == 0) {
    travelTime = 1;  // 防止同区块到达
}
```

**Noir：**

```rust
if travel_time == 0 { travel_time = 1; }
```

**状态：** ✅ 完成

---

### DIFF-4: 能量衰减 ✅ DONE

**Solidity (LibPlanet.sol)：**

```solidity
function getDecay(uint256 energy, uint256 dist, uint256 range) {
    return (energy * range) / (range + dist);
}
```

**Noir：**

```rust
// planet/move_planet.nr
pub fn calculate_energy_decay(energy: u64, distance: u64, range: u64) -> u64 {
    let effective_range = range + distance;
    (energy * range) / effective_range
}
```

**状态：** ✅ 完成

---

### DIFF-7: DOS 防护 ⚠️ TODO

**Solidity：**

```solidity
// DFMoveFacet.sol
LibGameUtils.checkPlanetDOS(args.newLoc, args.sender);

// LibGameUtils.sol
function checkPlanetDOS(uint256 locationId, address sender) {
    if (gs().planetEvents[locationId].length >= 6) {
        require(gs().planets[locationId].owner == sender);
    }
}
```

**Noir：**

```rust
// 仅检查最大 12 个 arrivals
assert(planet_arrival_count < 12, "Too many pending arrivals on planet");
```

**TODO：**

- [ ] 添加更严格的 DOS 检查：如果 arrivals >= 6 且不是 owner，拒绝

---

### DIFF-8: Wormhole 加速 ⚠️ TODO

**Solidity：**

```solidity
function _checkWormhole(args) returns (bool, uint256) {
    // 如果源或目标有激活的 Wormhole artifact
    // 且 wormholeTo 指向对方
    // 返回距离修改器: 2/4/8/16/32 基于稀有度
    effectiveDistTimesHundred /= distModifier;
}
```

**Noir：** 未实现

**TODO：**

- [ ] 添加 Wormhole artifact 检查
- [ ] 应用距离修改器到旅行时间计算

---

### DIFF-9: Photoid Cannon 攻击加成 ⚠️ TODO

**Solidity：**

```solidity
function _checkPhotoid(args) {
    // 如果源星球有激活的 PhotoidCannon
    // 且已过激活延迟
    // 应用临时升级 buff
    LibGameUtils._buffPlanet(args.oldLoc, temporaryUpgrade);
    // 移动后 debuff
    LibGameUtils._debuffPlanet(args.oldLoc, temporaryUpgrade);
}
```

**Noir：** 未实现

**TODO：**

- [ ] 添加 PhotoidCannon 激活检查
- [ ] 实现临时 buff/debuff 机制

---

### DIFF-10: 放弃星球 ⚠️ TODO

**Solidity：**

```solidity
function _abandonPlanet(args) {
    require(gs().planetEvents[args.oldLoc].length == 0);  // 无进行中的航行
    require(!gs().planets[args.oldLoc].isHomePlanet);

    // 移动所有人口和银币
    popMoved = planet.population;
    silverMoved = planet.silver;

    // 转移空间垃圾
    // 应用放弃升级
}
```

**Noir：** 未实现

**TODO：**

- [ ] 添加 `abandoning` 参数到 move_planet
- [ ] 实现放弃星球逻辑

---

### DIFF-11: 飞船移动 ⚠️ TODO

**Solidity：**

```solidity
function _isSpaceshipMove(args) {
    return gs().artifacts[args.movedArtifactId].artifactType >= ArtifactType.ShipMothership;
}

// 飞船移动规则:
// - popMoved 和 silverMoved 必须为 0
// - 可以征服 0 人口的星球
// - 应用飞船效果 (applySpaceshipArrive/Depart)
```

**Noir：** 未实现

**TODO：**

- [ ] 添加飞船类型 artifact
- [ ] 实现飞船移动规则
- [ ] 实现飞船效果 (Mothership, Whale, Titan, etc.)

---

## ✅ 一致性检查通过项

| 项目            | 描述                                               |
| --------------- | -------------------------------------------------- |
| ✅ ZK 证明坐标  | 私有函数验证 `compute_planet_hash(x, y) == id`     |
| ✅ 所有权检查   | `from_planet.owner == sender`                      |
| ✅ 能量检查     | `population >= energy_sent`                        |
| ✅ 银币检查     | `silver >= silver_sent`                            |
| ✅ 范围检查     | `distance <= range`                                |
| ✅ 宇宙边界检查 | `x^2 + y^2 < world_radius^2`                       |
| ✅ 旅行时间计算 | `travel_time = (distance * 100) / speed`           |
| ✅ 能量衰减     | `pop_arriving = (energy * range) / (range + dist)` |
| ✅ 到达记录存储 | `ArrivalData` 结构体存储                           |
| ✅ 到达处理     | `apply_arrival` 处理增援/攻击                      |
| ✅ 事件发射     | `PlanetMoved` 事件                                 |

---

## 🔗 相关文件

- [DFMoveFacet.sol](file:///home/zk/web3-projects/darkforest-v0.6/eth/contracts/facets/DFMoveFacet.sol)
- [LibPlanet.sol](file:///home/zk/web3-projects/darkforest-v0.6/eth/contracts/libraries/LibPlanet.sol)
- [move/circuit.circom](file:///home/zk/web3-projects/darkforest-v0.6/circuits/move/circuit.circom)
- [main.nr](file:///home/zk/web3-projects/darkforest-v0.6/aztec-darkforest/src/main.nr)
- [planet/move_planet.nr](file:///home/zk/web3-projects/darkforest-v0.6/aztec-darkforest/src/planet/move_planet.nr)
- [types/arrival.nr](file:///home/zk/web3-projects/darkforest-v0.6/aztec-darkforest/src/types/arrival.nr)
