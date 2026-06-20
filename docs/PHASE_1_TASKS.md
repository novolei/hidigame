# Phase 1 任务清单 — Prop Hunt

> 基于 GDD v0.3.3 锁定
> 起点:PoC-1 + PoC-2 并行推进
> 状态:PoC-1 / PoC-2 实施中

---

## 0. 任务总览

### 0.1 阶段定义
- **PoC-1**:职业切换 + 24 人 lobby + 1:3 自动分配 + 120s 准备 + Hunter 准备室
- **PoC-2**:AK47 武器系统 + 4 种弹药包 + 120 上限 + 服务器侧命中判定
- **PoC-3**:喷涂(无限制)+ 变形轮盘 + 模拟约束
- **PoC-4**:卡牌系统(扩展 Hunter 卡池)
- **PoC-5**:道具 + 空投 + Stalker 抢先破坏
- **PoC-6**:视角切换系统

### 0.2 优先级
| 优先级 | 任务 | 状态 |
|--------|------|------|
| P0 | PoC-1 + PoC-2(可玩闭环 + 武器基础) | **实施中** |
| P1 | PoC-3(藏匿者核心) | 等待 PoC-1 完成 |
| P1 | PoC-5(空投 + 抢先) | 等待 PoC-1 完成 |
| P2 | PoC-4(卡牌扩展) | 任意时间 |
| P2 | PoC-6(视角切换) | 任意时间 |

---

## 1. PoC-1 详细任务

### 1.1 目标
实现可玩的最小闭环:玩家加入 lobby → 选择职业 → 1:3 自动分配 → 120s 准备阶段 → 进入主战场 → 胜负判定。

### 1.2 任务拆分

#### TASK-1.1:改造 level.gd 加入职业 spawn / 1:3 分配
- **文件**:`scripts/level.gd`
- **依赖**:无
- **预计工时**:2h
- **验收**:
  - 玩家加入 lobby 时记录职业选择(Chameleon/Stalker/Hunter)
  - 服务器按 1:3 比例自动调整 Hunter 数量
  - 服务器按 Chameleon:Stalker = 1:1 默认均分 Props 内部
  - spawn 时按职业分配到不同位置(Hunter → 准备室,Props → 主战场)

#### TASK-1.2:改造 player.gd 加入职业状态机
- **文件**:`scripts/player.gd`
- **依赖**:TASK-1.1
- **预计工时**:1.5h
- **验收**:
  - `Character` 类新增 `role: Role` 枚举(`CHAMELEON / STALKER / HUNTER`)
  - `_ready()` 根据节点名或网络参数设置 role
  - `is_chameleon()` / `is_stalker()` / `is_hunter()` 三个 helper
  - 准备阶段 Hunter 玩家被锁定(无法移动)

#### TASK-1.3:新增 Hunter 准备室场景
- **文件**:`scenes/level/preparation_room.tscn`(新)
- **依赖**:TASK-1.2
- **预计工时**:1.5h
- **验收**:
  - 准备室场景:30×30m 平面 + 8 个 Hunter 出生点(支持扩展到更多)
  - 视觉上"参考弹药箱"(纯展示,无功能)
  - "战场观察窗"(可选,Phase 1 简化)
  - 准备室门(碰撞体)阻挡 Hunter 进入主地图

#### TASK-1.4:改造 main_menu_ui 加入职业选择 + host 配置
- **文件**:`scenes/ui/main_menu_ui.tscn` + `scripts/main_menu_ui.gd`
- **依赖**:无
- **预计工时**:1h
- **验收**:
  - 新增 3 个职业按钮:Chameleon / Stalker / Hunter
  - host 配置面板:玩家上限 / 单局时长 / 准备时长
  - 玩家选择职业 → 发送 `player_role_selected` 信号到 Network

#### TASK-1.5:Network 加 1:3 自动分配逻辑
- **文件**:`scripts/network.gd`
- **依赖**:无
- **预计工时**:1h
- **验收**:
  - 玩家加入时记录 `players[id].role`
  - 服务器在准备阶段开始时执行 `auto_balance_roles()`:
    - 计算 Hunter 数量 = floor(总玩家数 / 4),上限 8
    - 剩余玩家平均分配给 Chameleon / Stalker
  - 角色变化广播给所有客户端

#### TASK-1.6:120s 准备倒计时
- **文件**:`scripts/level.gd` + 新增 UI
- **依赖**:TASK-1.1
- **预计工时**:1h
- **验收**:
  - 玩家全员加入后,服务器开始 120s 倒计时
  - 客户端实时显示倒计时
  - 倒计时 = 0 时,服务器广播"准备结束",Hunter 准备室门打开

---

## 2. PoC-2 详细任务

### 2.1 目标
让 Hunter 玩家可以用 AK47 射击 Props,服务器侧做命中判定,弹药从地图拾取。

### 2.2 任务拆分

#### TASK-2.1:新增 weapon_system.gd (AK47 + 服务器 raycast)
- **文件**:`scripts/weapon_system.gd`(新)
- **依赖**:TASK-1.2(角色系统)
- **预计工时**:3h
- **验收**:
  - `WeaponSystem` 类继承 `Node3D`
  - 30 发弹匣,120 发总上限,初始 0 发
  - 600 RPM 射速
  - 单发 25% 伤害,4 发击杀
  - 服务器侧 raycast 命中判定
  - 弹药耗尽时切近战(1 发 10%)

#### TASK-2.2:新增 ammo_pickup.gd (4 种弹药包)
- **文件**:`scripts/ammo_pickup.gd`(新)
- **依赖**:TASK-2.1
- **预计工时**:2h
- **验收**:
  - `AmmoPickup` 类继承 `Node3D` / `Area3D`
  - 4 种类型:小 +30 / 中 +60 / 大 填满 / 特殊
  - 视觉区分(颜色 / 标签)
  - Hunter 走近 1m 自动拾取
  - Prop 不可拾取(默认 v0.3.3)
  - 拾取后 30s 重置

#### TASK-2.3:武器挂载 + 输入映射 + 弹道可视化
- **文件**:`scenes/weapons/ak47.tscn`(新) + `project.godot`
- **依赖**:TASK-2.1
- **预计工时**:2h
- **验收**:
  - AK47 模型 + 枪口闪光 + 弹道光线
  - 挂载到 Hunter player(右手 / 胸前位置)
  - 输入映射:`shoot` (MOUSE_BUTTON_LEFT) + `reload` (R)
  - 弹道可视化:服务器侧 raycast 命中后,客户端显示 0.2s 弹道光线

#### TASK-2.4:弹药上限 120 校验 + 服务器侧伤害判定
- **文件**:`scripts/weapon_system.gd` + `scripts/player.gd`
- **依赖**:TASK-2.1
- **预计工时**:1.5h
- **验收**:
  - 拾取弹药时校验总弹药 ≤ 120
  - 服务器侧 raycast 命中 Prop → 扣 25% 血
  - 4 发击杀,3 发爆头击杀
  - 击杀全场广播 + 提示

---

## 3. 任务依赖图

```
[TASK-1.4 main_menu]
        ↓
[TASK-1.5 Network 分配]
        ↓
[TASK-1.1 level spawn]
        ↓
[TASK-1.2 player 角色] ──→ [TASK-1.3 准备室]
        ↓
[TASK-1.6 倒计时] ←──┘
        
[TASK-1.2] ──→ [TASK-2.1 weapon]
                    ↓
            [TASK-2.2 ammo] + [TASK-2.3 武器挂载]
                    ↓
                [TASK-2.4 命中判定]
```

---

## 4. 验收里程碑

### M1:可加入 + 选职业 + 自动分配(完成 1.4 / 1.5)
- [ ] 玩家加入 lobby
- [ ] 选择 Chameleon / Stalker / Hunter
- [ ] 服务器按 1:3 自动调整
- [ ] 控制台打印分配结果

### M2:可 spawn + 准备室(完成 1.1 / 1.2 / 1.3)
- [ ] Hunter 进入准备室
- [ ] Props 进入主战场
- [ ] 120s 倒计时可见
- [ ] 倒计时结束后门打开

### M3:可战斗(完成 2.1 / 2.2 / 2.3 / 2.4)
- [ ] Hunter 用 AK47 射击
- [ ] 4 发击杀 Prop
- [ ] 弹药包可拾取
- [ ] 弹药上限 120 校验生效

---

## 5. 文件改动清单(本次任务)

### 新建
- `scripts/weapon_system.gd`
- `scripts/ammo_pickup.gd`
- `scenes/weapons/ak47.tscn`
- `scenes/level/preparation_room.tscn`

### 修改
- `scripts/level.gd`
- `scripts/player.gd`
- `scripts/network.gd`
- `scripts/main_menu_ui.gd`
- `scenes/ui/main_menu_ui.tscn`
- `project.godot`(加输入映射)

---

## 6. 风险与缓解

| 风险 | 缓解 |
|------|------|
| 现有 player.gd 改动过大破坏原模板 | 增量添加,新功能用 if 分支隔离 |
| 服务器 raycast 性能差 | 限制射速 + 不允许穿透多目标 |
| 准备室与主战场边界处理复杂 | 用 collision_layer 物理隔离 |
| 24 人 lobby 同步延迟 | SceneReplicationConfig 频率分档(远 / 近) |

---

## 7. 当前进度

```
PoC-1: [▱▱▱▱▱▱] 0/6
PoC-2: [▱▱▱▱] 0/4
```