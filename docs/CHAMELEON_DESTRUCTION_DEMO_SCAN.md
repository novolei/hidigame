# Chameleon Sculpt 对 Godot 4 Destruction Demo 的调研结论

调研目标:分析 `H:\Downaloads\Godot_4_Destruction_DEMO_260605\Godot_4_Destruction_DEMO` 中墙体和花瓶的破坏效果,判断哪些设计可以迁移到藏匿者自由泥塑系统。

## 1. Demo 的破坏系统结构

该项目的核心不是一个单一 mesh deform 脚本,而是 `addons/rupturecore` 下的一整套分层破坏框架。

关键文件:

- `addons/rupturecore/demo/RuptureInputController.cs`:把鼠标屏幕点转成一次 `ApplyImpact`。
- `addons/rupturecore/runtime/data/RuptureDamageProfile.cs`:把射线命中、物理冲击、爆炸统一转成 `DamageEvent`。
- `addons/rupturecore/runtime/damage/DamageRouter.cs`:把物理命中的 body RID 分发成不同 `DestructionTarget`。
- `addons/rupturecore/runtime/damage/RepresentationSelector.cs`:根据目标类型选择 Macro / Meso / Micro 表现路径。
- `addons/rupturecore/runtime/fracture/LocalDamageGrid.cs`:在局部网格中累计伤害,用于洞、断裂、穿透和结构完整性判断。
- `addons/rupturecore/runtime/fracture/MicroPrefabRepresentation.cs`:小道具破坏,例如花瓶。
- `addons/rupturecore/runtime/fracture/MesoFractureRepresentation.cs`:结构物实时切片/穿透,例如墙体。
- `addons/rupturecore/runtime/components/RCBreakablePrefabComponent.cs`:小道具 authoring 组件。
- `addons/rupturecore/runtime/components/RCDestructibleComponent.cs`:墙体/结构物 authoring 组件。

## 2. 墙体破坏的方式

墙体不是简单替换模型,而是结构级目标:

1. 物理射线命中墙体 collision。
2. `DamageRouter` 解析命中的 RID,判断是 static structural node。
3. `RepresentationSelector` 同时提交到 Macro 和 Meso。
4. Meso 路径把命中点、半径、冲量写入 `LocalDamageGrid`。
5. Damage grid 负责判断局部是否形成洞、是否穿透、哪个截面最弱。
6. 需要时才进入切片/碎片生成。

对我们的启发:自由泥塑不需要照搬 fracture,但应该照搬“局部影响场”概念。玩家笔刷不应该每次都重建体素体,而应该写入一个低分辨率 `ClayInfluenceGrid`,再让表面顶点从该局部场取样形变。

## 3. 花瓶破坏的方式

花瓶是小道具路径:

1. 花瓶节点挂 `RCBreakablePrefabComponent`。
2. 命中冲量超过 `BreakThreshold` 后,原对象隐藏并释放。
3. 实例化预制 `BrokenScene`。
4. 根据预算只给部分碎片启用完整刚体物理,其余降级为视觉碎片或粒子。

对我们的启发:藏匿者自由泥塑可以采用“宏形态预设 + 局部编辑”:

- `crate_mass`
- `vase_lump`
- `wall_patch`
- `tree_trunk`
- `stone_mound`

这些预设不应是最终形态,而是进入 sculpt 前的低成本初始材料。玩家再用 Push / Pull / Flatten / Smooth 做自由加工。

## 4. 不建议直接搬运的部分

不建议把 `rupturecore` 直接集成到当前藏匿者 sculpt:

- 该系统是 C#/.NET 插件,当前玩法核心大多是 GDScript。
- 它面向破坏、碎片、刚体和结构图,不是面向玩家实时捏形。
- 墙体路径依赖 prefracture / CSG slicing / shard backend,多人同步成本和调试成本都偏高。
- 花瓶路径依赖预制 broken scene,适合“坏掉”,不适合“持续可编辑”。

适合迁移的是架构思想,不是直接搬代码。

## 5. 应迁移到 Chameleon Sculpt 的模式

### 5.1 命中路由

Demo 的输入链路是:

`screen point -> ray hit -> target resolution -> representation dispatch`

本项目应使用:

`screen point -> shell triangle hit -> sculpt tool dispatch -> local surface edit`

本轮已经修复:新增 `FreeformClayShell.intersect_ray_world()`,Sculpt 输入优先命中 shell 自身三角面,不再依赖物理 collision。

### 5.2 局部影响网格

Demo 的 `LocalDamageGrid` 用 3D 小网格累计 damage。我们可以做对应的 `ClayInfluenceGrid`:

```gdscript
{
    "resolution": Vector3i(8, 12, 8),
    "push_pull": PackedFloat32Array,
    "flatten": PackedFloat32Array,
    "smooth": PackedFloat32Array,
    "paint_weight": PackedFloat32Array
}
```

笔刷先写 grid,渲染顶点再从 grid 采样。这样比直接体素重建便宜,也比每次遍历所有顶点更可控。

### 5.3 Representation 分层

参考 `MacroGraphRepresentation / MesoFractureRepresentation / MicroPrefabRepresentation`,Chameleon Sculpt 应拆成:

- Macro:大形态预设,例如墙片、树干、石块、箱体、花瓶团块。
- Surface:实时可编辑表面,负责 Push / Pull / Grab / Flatten / Smooth。
- Paint:复用环境取色和材质采样。
- UGC/Profile:只保存宏形态权重、局部影响场和颜色,不保存完整 runtime mesh。

### 5.4 预算分层

Demo 对碎片数量有 budget。我们也需要 sculpt budget:

- 固定最大顶点数。
- 固定编辑 AABB。
- 单笔最多影响 N 个局部 grid cell 或 N 个顶点。
- 多人同步只传笔刷事件和定期 compact profile。
- 远处玩家只重放低频 profile,不实时跑完整 brush preview。

## 6. 本轮直接修复

本轮已经根据调研修复两个实际问题:

- 默认 `FreeformClayShell` 不再是单一椭球,而是由头、躯干、手臂、腿、手脚组成的平滑 Basic Human clay 代理网格。
- Sculpt 工具不再依赖物理碰撞体命中,新增 mesh triangle raycast,鼠标笔刷可以直接打到 shell 表面。

下一步建议:实现 `ClayInfluenceGrid` 和 3-5 个宏形态预设,让玩家进入环境融入后可以先选择“墙片/树干/石块/花瓶/箱体”这类环境材料基底,再自由雕刻。
