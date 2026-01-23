# Dark Forest Aztec 迁移任务清单

## 项目概述

| 项目           | 说明                                                          |
| -------------- | ------------------------------------------------------------- |
| **目标**       | 将 Dark Forest 从 Ethereum L1 + Circom 迁移到 Aztec L2 + Noir |
| **核心收益**   | 原生隐私、删除 Verifier、L2 低成本、更简代码                  |
| **预估总工期** | 12-16 周                                                      |
| **测试环境**   | Aztec Local Network (Sandbox)                                 |

---

## Phase 1: 环境搭建与学习 (1-2 周)

### 1.1 开发环境

- [x] 安装 Noir 工具链 (`noirup`, `nargo`)
- [x] 安装 Aztec Sandbox (`aztec-up`)
- [x] 启动本地 Aztec 网络
- [ ] 安装 Aztec.js SDK

### 1.2 学习资料

- [ ] 阅读 Noir 语法文档
- [ ] 阅读 Aztec.nr 合约框架
- [ ] 完成 Aztec 官方教程
- [ ] 理解 Notes (UTXO) 模型

### 1.3 项目初始化

- [x] 创建 `aztec-darkforest/` 目录
- [x] 初始化 `Nargo.toml`
- [x] 设置目录结构
- [x] 配置测试框架

**验收**: 能在 Sandbox 成功部署简单合约

---

## Phase 2: 工具库开发 (2-3 周)

### 2.1 MiMC 哈希

- [x] 实现 `compute_planet_hash(x, y, key)` (使用 noir-lang/mimc 库)
- [ ] **验证与原 Circom 输出一致**
- [x] 编写单元测试

### 2.2 Perlin 噪声

- [x] 研究原 `perlin.circom` 实现
- [x] 用 Noir 重新实现 (MultiScalePerlin)
- [x] 实现 `compute_perlin(x, y, key, scale)`
- [x] 实现 `get_space_type(perlin)` (在 enums.nr)
- [ ] 实现 `get_biome(perlin, spaceType)`
- [ ] **验证与原 Circom 输出一致**
- [x] 编写单元测试

### 2.3 辅助函数

- [x] 实现 `sqrt_u64(x)`
- [x] 实现 `distance(x1, y1, x2, y2)`
- [x] 编写单元测试

### 2.4 类型定义

- [x] 定义 `PlanetPublicState`
- [x] 定义 `PlayerPublicState`
- [x] 定义 `ArtifactState`
- [x] 定义游戏常量和枚举

**验收**: 所有工具函数测试通过，MiMC/Perlin 输出与原版一致

---

## Phase 3: 核心合约实现 (4-5 周)

### 3.1 Notes 定义

- [x] 实现 `CoordNote`
- [x] 实现 `EnergyNote`
- [x] 实现序列化/反序列化
- [x] 实现 Nullifier 计算

### 3.2 主合约框架

- [x] 实现 Storage structs
- [x] 实现 `constructor`
- [x] 实现权限检查 (pause/unpause)

### 3.3 玩家初始化 ⭐

- [x] 实现 `initialize_player(x, y)` 私有函数
- [x] 实现 `_init_player_public(...)` 公开函数
- [x] 验证坐标边界
- [x] 验证 perlin 范围
- [x] 创建 CoordNote
- [x] 创建 EnergyNote
- [x] 创建 EnergyNote
- [x] 更新公开状态
- [ ] 编写测试

### 3.4 星球移动 ⭐

- [x] 实现 `move_planet(...)` 私有函数
- [x] 实现 `_execute_move(...)` 公开函数
- [x] 验证坐标哈希
- [x] 验证距离约束
- [x] 消耗/创建能量 Note
- [x] 创建到达事件
- [ ] 编写测试

### 3.5 坐标揭示

- [x] 实现 `reveal_location(...)`
- [x] 验证冷却时间
- [x] 更新揭示坐标存储
- [ ] 编写测试

### 3.6 星球状态管理

- [x] 实现 `refresh_planet(...)` - 刷新能量/银矿
- [x] 实现能量增长计算
- [x] 实现银矿增长计算
- [x] 实现到达处理

### 3.7 星球升级

- [x] 实现 `upgrade_planet(location, branch)`
- [ ] 编写测试

**验收**: 能在 Sandbox 成功初始化玩家并执行移动

---

## Phase 4: 扩展功能实现 (3-4 周)

### 4.1 神器系统

- [x] 实现 `ArtifactNote` (ArtifactState)
- [x] 实现 `prospect_planet(...)` (find_artifact)
- [x] 实现 `find_artifact(x, y)`
- [ ] 实现 `deposit_artifact(...)`
- [ ] 实现 `withdraw_artifact(...)`
- [ ] 实现 `activate_artifact(...)`
- [ ] **实现神器加成效果 logic**
- [ ] 实现 `deactivate_artifact(...)`
- [ ] 编写测试

### 4.2 飞船系统

- [ ] 实现飞船类型神器
- [ ] 实现飞船移动效果
- [ ] 实现 `give_spaceships(...)`
- [ ] 编写测试

### 4.3 捕获区域

- [x] 实现捕获区域生成 (Move Logic)
- [x] 实现 `invade_planet(...)` (Move Logic)
- [x] 实现 `capture_planet(...)` (Move Logic)
- [ ] 编写测试

### 4.4 管理员功能

- [x] 实现 `pause()` / `unpause()`
- [ ] 实现 `set_owner(...)`
- [ ] 实现 `create_planet(...)`
- [ ] 编写测试

### 4.5 数据查询

- [x] 实现 `get_planet(...)` (View functions)
- [x] 实现 `get_player(...)`
- [x] 实现批量查询 (Individual views available)

**验收**: 所有扩展功能测试通过

---

## Phase 5: 前端适配 (3-4 周)

### 5.1 Aztec.js 集成

- [ ] 安装 `@aztec/aztec.js`
- [ ] 创建 `AztecWalletManager`
- [ ] 创建 `AztecContractManager`
- [ ] 实现 PXE 连接

### 5.2 合约 API 重写

- [ ] 重写 `initializePlayer()` 调用
- [ ] 重写 `move()` 调用
- [ ] 重写 `revealLocation()` 调用
- [ ] 重写 `findArtifact()` 调用
- [ ] 重写所有 getter 调用
- [ ] 实现事件监听

### 5.3 删除遗留代码

- [ ] 删除 `SnarkArgsHelper.ts`
- [ ] 删除 `WhitelistSnarkArgsHelper.ts`
- [ ] 删除 snarkjs 依赖

### 5.4 类型适配

- [ ] 更新 TypeScript 类型
- [ ] 添加 Aztec 特定类型

### 5.5 UI 调整

- [ ] 更新钱包连接组件
- [ ] 更新交易状态显示
- [ ] 更新错误处理

**验收**: 前端能正常连接合约并执行核心操作

---

## Phase 6: 测试与部署 (2-3 周)

### 6.1 合约单元测试

- [ ] 测试 MiMC/Perlin 输出一致性
- [ ] 测试玩家初始化流程
- [ ] 测试星球移动逻辑
- [ ] 测试能量/银矿计算
- [ ] 测试神器系统
- [ ] 测试边界条件和错误处理

### 6.2 集成测试

- [ ] 编写端到端测试脚本
- [ ] 测试完整游戏流程
- [ ] 测试多玩家场景
- [ ] **测试隐私保护** (验证链上数据不泄露坐标)

### 6.3 性能测试

- [ ] 测量证明生成时间
- [ ] 测量交易确认时间
- [ ] 对比原版性能

### 6.4 Local Network 部署

- [ ] 部署到 Aztec Local Network (Sandbox)
- [ ] 配置前端连接
- [ ] 进行实际测试
- [ ] 修复发现的问题

### 6.5 文档

- [ ] 编写部署文档
- [ ] 编写 API 文档
- [ ] 更新 README

**验收**: 所有测试通过，Local Network 运行正常

---

## 优先级矩阵

| 优先级 | 任务                   | 阻塞关系          |
| ------ | ---------------------- | ----------------- |
| P0     | Phase 1 环境搭建       | 阻塞所有          |
| P0     | Phase 2 MiMC/Perlin    | 阻塞 Phase 3      |
| P0     | Phase 3.3 玩家初始化   | 阻塞 Phase 3.4+   |
| P0     | Phase 3.4 星球移动     | 核心功能          |
| P1     | Phase 3.5-3.7 其他核心 | 依赖 3.3/3.4      |
| P1     | Phase 5.1-5.2 前端核心 | 可与 Phase 3 并行 |
| P2     | Phase 4 扩展功能       | 依赖 Phase 3      |
| P3     | Phase 6 测试部署       | 依赖全部          |

---

## 里程碑

| 里程碑     | 预期周次 | 交付物                    |
| ---------- | -------- | ------------------------- |
| M1: MVP    | Week 6   | 可初始化 + 移动的最小版本 |
| M2: Core   | Week 10  | 所有核心功能完成          |
| M3: Full   | Week 13  | 全功能版本                |
| M4: Launch | Week 15  | Local Network 测试完成    |

---

## 风险与缓解

| 风险                  | 缓解措施                              |
| --------------------- | ------------------------------------- |
| ~~Noir 没有 MiMC 库~~ | ✅ 已解决：使用 noir-lang/mimc 官方库 |
| ~~Perlin 实现复杂~~   | ✅ 已实现 MultiScalePerlin            |
| Aztec Sandbox 不稳定  | 关注官方更新，使用稳定版本            |
| 前端学习曲线          | 提前学习，参考官方示例                |
