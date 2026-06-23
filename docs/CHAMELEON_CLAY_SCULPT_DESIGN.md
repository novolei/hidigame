# Chameleon 人物泥塑设计文档

## 1. 目标

本功能把藏匿者的「环境融入」升级为一套可操作的现场泥塑工具。玩家进入环境融入技能后,先选择并调整一个可吸附到环境或物品表面的吸附点,然后生成一个与当前本体同大小、无 pose、可编辑的体素外壳。技能期间玩家可以使用 Paint / Sculpt 工具改造这个外壳的颜色、材质观感和体积轮廓;玩家也可以在任意时刻选择「还原本体」,立刻回到带骨骼动画的真实自身模型并恢复自由移动。

核心体验是「我把自己捏成能贴在这里的形状」,不是「一键变成地图物体」。该系统必须保留藏匿者的人形破绽和猎人的观察空间。

## 2. 设计边界

### 2.1 必须满足

- 进入环境融入技能时,玩家可以选择环境或物品表面作为吸附点。
- 吸附点可以微调位置、朝向和贴合偏移,直到玩家确认。
- 确认后生成同大小可编辑体素外壳,并隐藏或弱化真实骨骼模型。
- 体素外壳在技能期间不带 pose,不播放骨骼动画,以静态雕塑姿态贴合吸附表面。
- Paint 和 Sculpt 工具共用环境融入技能入口、HUD、取色和材质采样逻辑。
- 玩家可以随时还原本体,还原后显示真实骨骼模型、恢复动画和自由移动。
- 服务器必须校验吸附、雕刻、还原请求,客户端不能单方面宣布自己已经完美伪装。

### 2.2 明确不做

- 不实时修改现有带骨骼角色 Mesh 的拓扑。
- 不把玩家精确替换成地图物体 Mesh。
- 不让体素外壳具备完整骨骼动画。
- 不在每一笔雕刻后重建复杂物理碰撞。
- 不允许移除头、躯干、四肢等人形识别锚点。

## 3. 核心循环

1. 玩家按 `camouflage_absorb` 进入环境融入技能。
2. 系统进入「吸附点选择」状态,玩家用准星指向环境或可伪装物体表面。
3. 屏幕显示吸附预览:表面法线、贴合轮廓、体素外壳占位框。
4. 玩家微调吸附点,确认后进入「泥塑外壳」状态。
5. 真实本体被冻结并隐藏或半透明化;同尺寸无 pose 体素外壳出现在吸附点。
6. 玩家使用 Paint / Sculpt 工具对体素外壳改色、补体积、削体积、平滑和压平。
7. 玩家满意后可以保持伪装,也可以继续微调。
8. 任意时刻按还原输入,体素外壳消失,真实骨骼本体回到当前位置并恢复自由移动。

## 4. 玩家状态机

| 状态 | 可见模型 | 移动 | 输入焦点 | 退出条件 |
|---|---|---|---|---|
| `REAL_BODY` | 真实骨骼本体 | 自由移动 | 常规角色输入 | 按 `camouflage_absorb` |
| `ANCHOR_PICK` | 真实本体 + 吸附预览 | 慢速或冻结 | 吸附点选择输入 | 确认 / 取消 |
| `SHELL_ACTIVE` | 无 pose 体素外壳 | 冻结或极慢爬移 | Paint / Sculpt 工具输入 | 还原本体 / 死亡 / 被强制显形 |
| `RESTORING` | 体素外壳淡出,本体淡入 | 冻结 0.2s | 无 | 自动回到 `REAL_BODY` |

`SHELL_ACTIVE` 是本功能的核心状态。进入该状态后,玩家的位置与吸附点绑定;移动系统不再直接驱动可见模型,只保留相机环绕、工具操作和还原输入。

## 5. 吸附点设计

### 5.1 可吸附目标

- 静态地图 Mesh。
- 具有碰撞体的场景物品。
- 可复制伪装物件,例如已有 `FruitProp` 或后续 world object。
- 服务器标记为 `sculpt_attachable` 的动态物体。

不可吸附目标:

- 其他玩家。
- 武器、空投、临时粒子、纯触发区。
- 过小、过薄或法线不稳定的表面。
- 距离超过技能范围的表面。

### 5.2 吸附点数据

```gdscript
{
    "target_path": NodePath,
    "target_instance_id": int,
    "world_position": Vector3,
    "world_normal": Vector3,
    "surface_index": int,
    "uv": Vector2,
    "local_offset": Vector3,
    "yaw": float,
    "roll": float,
    "shell_scale": Vector3,
    "snap_distance": float
}
```

`world_position` 与 `world_normal` 来自射线命中。`local_offset` 用于让玩家沿表面拖动吸附点。`yaw` 和 `roll` 用于调整外壳朝向,避免默认站立姿态与墙面、地面、箱体边缘不协调。

### 5.3 吸附点调整

| 操作 | 行为 |
|---|---|
| 鼠标移动 | 更新准星命中的候选吸附点 |
| 左键 | 确认当前吸附点 |
| 右键拖动 | 沿命中表面平移吸附点 |
| 鼠标滚轮 | 调整外壳贴合偏移或缩放预览 |
| `Q/E` | 绕表面法线旋转外壳 |
| `R` | 重置吸附点微调 |
| `Esc` 或再次按 `camouflage_absorb` | 取消并回到真实本体 |

吸附预览必须显示三个东西:落点圆环、表面法线短线、同尺寸外壳包围盒。玩家要能一眼判断「我会贴在哪里」。

## 6. 体素外壳

### 6.1 生成原则

体素外壳不是复制当前动画姿态,而是以角色当前身高和碰撞体尺寸生成一套无 pose 静态人形体积:

- 头部:球体或椭球。
- 躯干:胶囊或椭球柱。
- 双臂:简化胶囊,默认贴近躯干。
- 双腿:简化胶囊,默认并拢或微分开。
- 背部/底部:保留足够体积用于贴地、贴墙或贴物体。

外壳尺寸来自当前真实本体的碰撞体和视觉包围盒,默认与本体同高度、同最大宽度。后续允许玩家通过 Sculpt 改变轮廓,但必须受人形锚点保护。

### 6.2 推荐技术形态

MVP 使用 `VoxelTerrain` + `VoxelStreamMemory` + `VoxelMesherTransvoxel` 创建局部小体素体,不使用 LOD。

推荐尺寸:

| 参数 | MVP 值 | 说明 |
|---|---:|---|
| 体素域 | `64 x 80 x 64` | 覆盖人形外壳 |
| 体素世界比例 | 1 voxel = 0.035m 到 0.05m | 兼顾细节和性能 |
| 编辑块大小 | 16 | 与插件默认块思路一致 |
| 碰撞 | 关闭复杂 voxel 碰撞 | 继续使用玩家简化碰撞体 |
| 存储 | 内存流 + 操作日志 | 单局临时伪装 |

### 6.3 人形锚点

为防止玩家削成纯箱子或贴图薄片,体素外壳维护不可删除的锚点体积:

- `head_core`
- `torso_core`
- `left_arm_core`
- `right_arm_core`
- `left_leg_core`
- `right_leg_core`

雕刻的 Remove / Flatten 操作不能把锚点区域的 SDF 推到空气侧。Add / Smooth 可以影响锚点边缘,但不能让锚点失去可识别轮廓。

## 7. 工具设计

### 7.1 模式切换

环境融入技能内有三个子模式:

| 模式 | 用途 |
|---|---|
| `Anchor` | 选择和调整吸附点 |
| `Paint` | 取色、上色、材质采样、笔触覆盖 |
| `Sculpt` | 加体积、削体积、平滑、压平 |

确认吸附点后默认进入 `Paint`。玩家可以在 `Paint / Sculpt` 之间切换,但不退出技能。

### 7.2 Paint 工具

Paint 复用现有环境融入系统:

- 第一击或指定输入用于从环境采样颜色、粗糙度、金属度、法线贴图。
- 左键在体素外壳表面喷涂。
- 右键或滚轮调整笔刷半径。
- `Z/X` 调 roughness。
- `F/G` 调 metallic。
- 喷涂仍保留笔触边缘、湿润反光、过度饱和等可识别破绽。

体素外壳的 Paint 实现优先级:

1. 如果 voxel mesher 支持颜色通道渲染,写入 `CHANNEL_COLOR`。
2. 如果颜色通道材质效果不足,将体素外壳转换为可绘制 Mesh 后复用现有 overlay/paint texture。
3. MVP 可先使用单材质 tint + 局部操作日志,验证玩法。

### 7.3 Sculpt 工具

| 工具 | 行为 | 约束 |
|---|---|---|
| Add | 沿表面法线补体积 | 半径受限,不能超出最大外壳 bounds |
| Remove | 削去体积 | 不能削掉人形锚点 |
| Smooth | 平滑局部 SDF | 不改变锚点体积分类 |
| Flatten | 朝吸附表面压平 | 仅影响表层,保留核心体积 |
| Pin | 标记局部不可被后续 Remove 影响 | 只在本次外壳生命周期内有效 |
| Reset Shell | 重置为初始无 pose 人形外壳 | 保留当前吸附点 |

Sculpt 的核心 API 对应:

- Add / Remove: `VoxelTool.do_sphere` 或 `grow_sphere`
- Smooth: `VoxelTool.smooth_sphere`
- Flatten: 对局部 SDF 做自定义平面投影或多次 Remove/Add 混合
- Reset: 重新生成初始 SDF buffer

## 8. 还原本体

### 8.1 玩家体验

玩家可在任意时刻选择还原本体。还原后:

- 体素外壳立即停止接收输入。
- 真实骨骼模型显示。
- 动画恢复。
- 角色解除冻结。
- 相机回到正常跟随。
- 玩家可以自由移动、跳跃、战斗或再次进入环境融入。

### 8.2 还原位置

默认把真实本体放回吸附点附近的安全站立位置:

1. 从体素外壳中心向外壳背离表面的方向偏移半个碰撞半径。
2. 向下做地面探测。
3. 检查玩家 capsule 是否与世界碰撞重叠。
4. 如果失败,沿表面切线尝试最多 8 个候选点。
5. 仍失败时,回到进入技能前的最后安全位置。

这能避免玩家从墙面或物体内部还原后卡住。

### 8.3 强制还原

以下情况强制还原:

- 受到致命伤害。
- 被 Hunter 强制显形技能命中。
- 吸附目标被销毁或移动过远。
- 服务器检测到外壳状态无效。
- 回合阶段切换到 END。

## 9. 网络与权威

### 9.1 原则

体素外壳是玩家可见外形的一部分,必须服务端权威。客户端负责预览和即时手感,服务端负责校验和广播最终操作。

### 9.2 RPC 流

```gdscript
request_sculpt_anchor(anchor_payload)
apply_sculpt_anchor(anchor_payload)

request_sculpt_shell_start(anchor_payload, shell_seed, body_metrics)
apply_sculpt_shell_start(anchor_payload, shell_seed, body_metrics)

request_sculpt_stroke_batch(strokes)
apply_sculpt_stroke_batch(strokes)

request_sculpt_restore(reason)
apply_sculpt_restore(reason, restore_transform)

request_sculpt_snapshot(peer_id)
apply_sculpt_snapshot(snapshot_payload)
```

连续笔刷可使用 `unreliable_ordered`,吸附开始、还原、snapshot 必须使用 `reliable`。

### 9.3 服务端校验

服务端必须校验:

- 请求者是否为该玩家 authority。
- 玩家角色是否是 `Network.Role.CHAMELEON`。
- 当前阶段是否允许环境融入。
- 吸附目标是否合法、距离是否合法、法线是否合法。
- 笔刷半径、强度、频率是否在范围内。
- Remove / Flatten 是否破坏人形锚点。
- 外壳最大体积、最大宽度、高度变化是否超出限制。

### 9.4 Snapshot

新玩家加入、丢包恢复或远端外壳缺失时,服务器发送 snapshot。

MVP snapshot 可用操作日志:

```gdscript
{
    "anchor": Dictionary,
    "body_metrics": Dictionary,
    "shell_seed": int,
    "strokes": Array[Dictionary],
    "paint_state": Dictionary,
    "version": int
}
```

后续如果操作日志过长,改为压缩 `VoxelBuffer` 数据块。

## 10. 视觉与反馈

### 10.1 吸附预览

- 可吸附表面:绿色或当前 sampled color 圆环。
- 不可吸附表面:红色圆环并显示简短失败原因。
- 外壳包围盒:半透明人形轮廓。
- 法线:短箭头,用于提示外壳会贴向哪个方向。

### 10.2 泥塑反馈

- Add: 软泥鼓起效果。
- Remove: 刮削粉尘或碎片。
- Smooth: 局部半透明柔化波纹。
- Flatten: 表面压痕和刮平线。
- Paint: 沿用现有笔触和湿润反光。

### 10.3 Hunter 识别线索

- 雕刻边缘保留轻微体素化轮廓。
- 过度 Flatten 会产生可见压痕。
- 吸附点附近有短暂残留痕迹。
- 近距离手电照射可增强体素外壳边缘高光。

## 11. 与现有系统的关系

| 现有系统 | 关系 |
|---|---|
| `CamouflageSystem` | 扩展为环境融入总入口,加入 Anchor / Paint / Sculpt 子模式 |
| `player.gd` camouflage RPC | 复用现有 submit/request/apply 风格,增加 sculpt RPC |
| `ShapeShiftSystem` | 继续负责 Q 轮盘预设变形;泥塑是技能内临时外壳,不是档案预设 |
| `CharacterBody3D` 移动 | `SHELL_ACTIVE` 期间冻结或极慢;还原后恢复 |
| `SkillHUD` / `CamouflageHUD` | 增加子模式、吸附状态、雕刻工具和还原提示 |
| `shadow_visibility_system.gd` | 不直接耦合;但 Hunter 反制可读取外壳状态增强显示 |

## 12. 文件落点建议

| 文件 | 作用 |
|---|---|
| `scripts/chameleon_sculpt_system.gd` | 状态机、输入、吸附、工具调度 |
| `scripts/self_voxel_shell.gd` | 体素外壳生成、编辑、snapshot |
| `scripts/sculpt_anchor.gd` | 吸附目标解析、预览、合法性校验 |
| `scenes/effects/self_voxel_shell.tscn` | 体素外壳场景 |
| `shaders/chameleon_voxel_shell.gdshader` | 体素外壳渲染与 Paint 材质 |
| `tests/chameleon_sculpt_system_test.gd` | 状态机与规则测试 |
| `tests/self_voxel_shell_test.gd` | SDF 生成、锚点保护、操作重放 |

## 13. 实施计划

### Phase 0: 插件兼容性验证

- 安装 `godot_voxel` GDExtension 到 `addons/zylann.voxel/`。
- 验证 Godot 4.7 下 `ClassDB.class_exists("VoxelTerrain")`。
- 验证 headless import 不破坏现有场景。
- 搭建最小 `VoxelTerrain` 场景,用 `VoxelTool.do_sphere` 做 Add / Remove。

通过标准:项目能启动,最小体素体可生成和编辑。

### Phase 1: 单机泥塑原型

- 新建 `SelfVoxelShell`。
- 根据玩家碰撞体生成无 pose 同尺寸人形 SDF。
- 实现 Add / Remove / Smooth。
- 实现人形锚点保护。
- 实现 Reset Shell。

通过标准:本地可进入 shell、雕刻、还原,不会削掉核心人形锚点。

### Phase 2: 吸附点交互

- 增加 Anchor 模式。
- 支持表面射线命中、法线预览、吸附点平移、旋转、偏移。
- 确认后把 shell 放到吸附点。
- 还原时找到安全站立位置。

通过标准:可贴地、贴墙、贴箱体侧面,还原不穿模不卡死。

### Phase 3: Paint / Sculpt 整合

- 在 `CamouflageSystem` 中加入子模式。
- Paint 复用取色和材质采样。
- Sculpt 复用同一笔刷 HUD。
- 让体素外壳进入 paintable target 集合或提供专用 paint path。

通过标准:一个技能入口内完成取色、喷涂、雕刻、平滑和还原。

### Phase 4: 多人同步

- 增加 sculpt anchor / stroke / restore RPC。
- 服务端校验角色、距离、频率、体积、人形锚点。
- 实现 snapshot 重放。
- 远端玩家看到相同体素外壳和主要笔触。

通过标准:Host + Client 下吸附、雕刻、上色、还原一致。

### Phase 5: 反制与平衡

- 手电增强边缘线索。
- 雨或水攻击冲刷 Paint 并软化 Sculpt 外壳。
- Hunter 扫描显示吸附残留。
- 调整雕刻期间移动限制和还原延迟。

通过标准:藏匿者有创造力,但 Hunter 仍有观察和道具反制路径。

## 14. 验收标准

- 藏匿者可以进入环境融入技能并选择合法吸附点。
- 玩家能调整吸附点位置、朝向和贴合偏移。
- 确认后生成同尺寸无 pose 体素外壳。
- 技能期间真实骨骼模型不再作为主可见模型。
- Paint 能对外壳产生可见颜色或材质变化。
- Sculpt 能对外壳产生可见体积变化。
- Remove / Flatten 不能破坏头、躯干、四肢锚点。
- 玩家任意时刻还原后恢复真实骨骼模型、动画和自由移动。
- 多人下远端玩家能看到外壳状态和主要编辑结果。
- 断线重连或新加入玩家能通过 snapshot 看到当前外壳。
- 现有 `ShapeShiftSystem`、Stalker 隐身、Hunter 武器不因本功能回退。

## 15. 待决问题

- 雕刻期间是否完全禁止移动,还是允许沿吸附表面小范围滑移。
- 体素外壳是否参与命中判定,还是继续使用玩家 capsule。
- 体素外壳颜色最终采用 voxel color channel,还是继续使用现有 GPU overlay。
- 还原本体是否需要 0.2s 到 0.5s 暴露动画。
- 吸附到动态物体时,是否随目标移动或在目标移动时强制还原。
- 雕刻外壳是否可以保存为档案预设,还是只允许单局临时存在。

