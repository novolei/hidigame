# Chameleon 自由泥塑重构方案

## 1. 策略结论

藏匿者的环境融入泥塑不再定位为「人体捏脸」或「调整身体部位」。它的核心目标是:

- 玩家进入环境融入后,把自己临时变成一团可吸附、可揉捏、可上色的伪装材料。
- 玩家可以自由把身体捏成墙面凸起、树干、石块、箱角、管道、地形隆起等环境形状。
- 技能期间不要求维持人形、骨骼、四肢、头部、身体部位识别锚点。
- 还原时丢弃或收起自由泥塑壳,回到真实带骨骼角色本体并恢复移动。

所以重构方向不是传统角色编辑器的「脸型、身材、四肢参数」,而是「无骨骼 clay shell 的自由表面/体积形变」。

## 2. 当前方案为什么不合理

当前 `SelfVoxelBody` 原型存在几个结构性问题:

- 每次笔刷都会修改 SDF 后同步 `rebuild_mesh()`,帧内重建完整 mesh。
- Paint / Reset / Smooth 都遍历固定 32³ 体素域,分辨率提高会立刻变成指数式成本。
- Voxel/SDF 存储适合地形、洞穴、可破坏体积,但人物伪装需要更直接的表面操作手感。
- 当前 Basic Human 资产没有 blend shape。运行时探针确认 `Main Mesh` 的 `blend_shape_count == 0`,不能依赖现有角色模型做 morph 参数。
- 旧设计中的人形锚点会阻止玩家捏成真正像环境的形状,和自由伪装目标冲突。

结论:Voxel Tools 可以保留为后备或环境体积玩法,但不应继续作为藏匿者自由泥塑的主实现。

## 2.1 当前落地状态

本轮已经落地第一阶段 MVP:

- `scripts/freeform_clay_shell.gd`: 新增固定拓扑的连续 surface clay shell,支持 Push/Pull、Smooth、Flatten、Grab、Paint、soft reset 和 compact profile。
- `scenes/effects/freeform_clay_shell.tscn`: 新增技能期可实例化的 freeform shell 场景。
- `scripts/chameleon_sculpt_system.gd`: 默认实例化目标从 `SelfVoxelBody` 切换为 `FreeformClayShell`。
- `tests/freeform_clay_shell_test.gd`: 覆盖基础笔刷、profile replay 和压力测试。
- `tests/chameleon_sculpt_system_test.gd`、`tests/chameleon_sculpt_network_test.gd`、`tests/chameleon_sculpt_paint_integration_test.gd`、`tests/chameleon_sculpt_ugc_test.gd`: 覆盖技能接入、多人笔刷批次、Hunter 反制、Paint 接入和 UGC 分享码。

当前 MVP 仍然是直接顶点编辑版本,下一阶段再把渲染顶点改为由 `ClayControlCage` 驱动,以获得更强的整体拉伸和更少的网络数据。

## 3. 新核心抽象

### 3.1 FreeformClayShell

`FreeformClayShell` 是技能期间显示和编辑的无骨骼代理壳:

- 独立于真实角色骨骼。
- 默认生成与角色占用空间相近的连续表面网格。
- 不继承当前 pose。
- 只在技能期间作为伪装壳存在。
- 可被自由拉伸、压扁、鼓起、削平、平滑、贴合环境。

它不是体素块,也不是真实角色 mesh。它是一个专门为自由伪装 sculpt 设计的可编辑 surface mesh。

### 3.2 ClayControlCage

为了获得平滑手感和低成本编辑,不要直接每笔改所有渲染顶点。使用控制笼:

```gdscript
{
    "control_points": PackedVector3Array,
    "rest_points": PackedVector3Array,
    "weights_per_vertex": Array[PackedInt32Array],
    "weight_values_per_vertex": Array[PackedFloat32Array],
}
```

笔刷作用在控制点上,渲染顶点由控制点插值更新。这样可以:

- 降低笔刷计算量。
- 让形变天然平滑。
- 支持大范围拉伸和压平。
- 比逐体素重建更接近 3D 游戏 sculpt 的手感。

### 3.3 Macro Morph

BlendShape 不用于「人体部位参数」,而用于少量宏观伪装形态:

- `flatten_wall`: 压扁成贴墙形。
- `stone_lump`: 石块团。
- `trunk_column`: 树干/柱状。
- `crate_mass`: 箱体团。
- `pipe_bend`: 管道弯曲。
- `ground_mound`: 地面隆起。

这些不是角色外观选项,而是进入 sculpt 前的初始材料状态。玩家可以从一个宏形态开始,再用笔刷自由改造。

### 3.4 Surface Delta Layer

所有自由编辑以 delta 存储:

```gdscript
{
    "version": 1,
    "base_shell": "humanoid_clay_v1",
    "macro": {"flatten_wall": 0.7, "stone_lump": 0.2},
    "control_deltas_q": [...],
    "paint_layers": [...],
    "bounds": {"max_radius": 1.4, "max_height": 2.0}
}
```

UGC 和网络不再同步完整体素体,而同步:

- 宏形态权重。
- 控制点 delta。
- 笔刷操作日志。
- Paint overlay 贴图或调色板索引。

## 4. 工具手感设计

### 4.1 必备工具

| 工具 | 行为 | 说明 |
|---|---|---|
| Push/Pull | 沿表面法线鼓起或压入 | 替代 Add/Remove 体素 |
| Grab | 抓住一块表面拖动 | 最像自由揉泥 |
| Flatten | 向目标平面压平 | 贴墙、贴地、贴箱面关键 |
| Smooth/Relax | 平滑控制点 delta | 消除折痕 |
| Inflate | 均匀膨胀局部 | 做石块/树瘤 |
| Pinch | 收紧局部 | 做边缘、凹槽 |
| Paint | 沿 UV/三平面投影上色 | 复用环境取色 |

### 4.2 吸附点如何影响 sculpt

吸附点不只是摆放位置,还提供编辑参考:

- `anchor_plane`: Flatten 默认压向吸附表面平面。
- `anchor_normal`: Shell 的局部 forward/up 与表面法线对齐。
- `surface_sample`: Paint 默认从吸附目标采样材质颜色。
- `snap_strength`: 笔刷可以把局部表面吸向目标表面。

### 4.3 不再保护人形锚点

允许玩家把头、四肢、躯干揉成不可识别形状。平衡不靠人形锚点,而靠:

- 最大包围盒/体积预算。
- 最小厚度限制,防止做成不可见薄片。
- 颜色/材质采样有噪声和冷却,防止完全隐身。
- 猎人扫描/近距离观察可以显示 clay signal。
- 还原本体需要短暂显形或恢复延迟。

## 5. 推荐实现路线

### Phase 0: 冻结当前 voxel 方案

- 保留 `SelfVoxelBody` 作为实验分支或 fallback。
- 不继续在 voxel 方案上加入复杂功能。
- 文档和新代码命名都切换到 `FreeformClayShell`。

### Phase 1: 建立 surface mesh clay shell

新增:

- `scripts/freeform_clay_shell.gd`
- `scenes/effects/freeform_clay_shell.tscn`
- `scripts/freeform_clay_profile.gd`
- `tests/freeform_clay_shell_test.gd`

MVP 初始 mesh 可用程序化 UV sphere / capsule-lump / subdivided ico sphere 拼成一个连续 clay shell,不依赖 Basic Human skeleton。

首版只实现:

- 生成 shell。
- Grab / PushPull / Smooth。
- 局部更新 ArrayMesh。
- Paint 继续复用现有 overlay 材质。
- Serialize control deltas。

### Phase 2: 接入环境融入

`ChameleonSculptSystem` 改为:

- 激活时 spawn `FreeformClayShell`,隐藏真实角色。
- 确认吸附点后把 shell 放到表面。
- 鼠标左键 sculpt,Tab 切 Paint/Sculpt。
- `R` 还原真实角色。

旧 `SelfVoxelBody` 不再作为默认 shell。

### Phase 3: 宏形态和 UGC

新增宏形态:

- wall slab
- stump / trunk
- rock lump
- crate-ish mass
- ground mound

UGC 保存 `macro + control_deltas + paint_layers`,作品码比 SDF 体素快照小很多。

### Phase 4: 多人同步优化

同步策略:

- 实时: unreliable ordered 笔刷操作。
- 周期性: control delta checksum。
- 加入/下载: compact profile snapshot。

服务器校验:

- 控制点 delta 不超出编辑 AABB。
- 体积预算不超限。
- 薄片厚度不低于阈值。
- 笔刷频率和半径限制。

## 6. 为什么不是 Terrain3D

Terrain3D 很适合大型地形 heightmap 的 sculpt、holes、texture paint,但它的核心是地形系统,不是闭合自由角色壳。藏匿者泥塑需要一个可拿起来贴到墙、树、车、箱子上的局部闭合或半闭合 shell,不是世界地形高度场。

## 7. 为什么不完全放弃 SDF

SDF 仍然适合:

- 后续做真正自由拓扑的 blob 物体。
- 需要挖洞/合并/断开的特殊 UGC。
- 环境地形破坏或道具体积变化。

但当前功能第一优先级是手感、性能和伪装体验。因此主线用 surface control cage,不是体素重建。

## 8. 下一步最小可行实现

第一刀不要做完整系统,只做一个可验证的 freeform shell:

1. 生成一个同玩家身高的连续 clay mesh。
2. 鼠标点击 shell 表面,找到最近控制点。
3. Grab 拖动局部表面,有平滑 falloff。
4. Smooth 让局部变形自然。
5. 每笔只更新 mesh 顶点数组,不重建体素、不跑 Transvoxel。
6. 测试约束:一次笔刷更新时间低于当前 voxel 方案,连续 50 笔不卡死,mesh 顶点数稳定。

通过这一步后,再迁移 Paint、吸附点和 UGC。
