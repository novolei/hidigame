# Prop Hunt Card System Design

版本: v0.1 implementation baseline  
状态: 已接入开局抽卡、卡槽 HUD、一次性消耗、首批卡牌池与第一版效果

## 1. 目标

卡牌系统是一局内的一次性战术资源, 用来让每局的追逃节奏出现不同组合, 但不替代职业主能力。

核心规则:
- Lobby 点击开始后, 服务器锁定阵营并为每个非观战玩家发起抽卡。
- Hunter 从 Hunter pool 抽卡; Chameleon 和 Stalker 都从 Prop pool 抽卡。
- 每名玩家进行两轮抽卡。每轮从所属池随机 3 张, 玩家选择 1 张保留。
- 第二轮不会出现第一轮已经保留的卡。
- 最终每名玩家携带 2 张不同卡牌进入本局。
- 每张卡牌本局只能使用或触发 1 次。
- 比赛结束后未使用卡牌作废。

## 2. 交互流程

1. `Network.server_auto_balance_roles(true)` 锁定角色。
2. `Network.server_start_card_drafts_for_match()` 为所有玩家生成第一轮三选一。
3. 本地 `CardHUD` 显示三张候选卡, 玩家点击或按 `1/2/3` 保留。
4. 服务器校验候选卡合法后生成第二轮三选一。
5. 第二次保留后, 服务器生成两个卡槽并同步给该玩家。
6. 局内玩家点击卡槽或按 `Z/X` 使用手动卡。
7. 反应卡不可手动使用, 由伤害/死亡路径自动消耗。

## 3. 当前实现

代码入口:
- `res://scripts/card_database.gd`: 卡牌池、文案、数值、分类。
- `res://scripts/network.gd`: 权威抽卡、保留、消耗、反应卡触发。
- `res://scripts/card_hud.gd`: 左下角抽卡/卡槽 HUD。
- `res://scripts/level.gd`: 开局发牌、HUD 生命周期、热键、卡牌事件转发。
- `res://scripts/player.gd`: 卡牌效果应用、免伤/复活等战斗钩子。

当前 v0.1 原则:
- 网络和状态先完整落地。
- 复杂视觉表现先用 feedback、tint、虚像、显形、减速、弹药清空等可验证效果表达。
- 后续可以逐张卡升级 VFX、范围指示器、音效、命中特效和 AI/炮塔专属目标逻辑。

## 4. Prop Pool

| ID | 名称 | 类型 | 触发 | 时长 | v0.1 效果 |
| --- | --- | --- | --- | --- | --- |
| A1 | 瞬间隐形 / Chromatic Burst | 主动 | 手动 | 1s | 隐藏角色视觉, 脚步声保留 |
| A2 | 强化变小 / Micro Form | 主动 | 手动 | 15s | 角色缩放到 0.25 倍, 到时恢复 |
| A3 | 闪光弹 / Flashbang | 主动 | 手动 | 5s | 10m 内 Hunter 收到视野干扰反馈 |
| A4 | 诱饵残影 / Decoy Echo | 主动 | 手动 | 15s | 原地生成静止蓝色虚像 |
| A5 | 移行换位 / Portal Step | 主动 | 手动 | 瞬时 | 传送到 40-50m 随机落地点并留残影 |
| D1 | 静止力场 / Static Aura | 防御 | 手动 | 8s | 8m 内 Prop 获得伤害免疫 |
| D2 | 时之砂 / Emergency Conceal | 防御 | 自动 | 5s | 致命/低血伤害时自动消耗, 恢复到 65 血并短暂无敌 |
| D3 | 涂装炸弹 / Paint Bomb | 防御 | 手动 | 5s | 20m 内 Hunter 收到 PAINT 干扰反馈 |
| D4 | 时间静止 / Time Stop | 防御 | 手动 | 8s | 10m 内 Hunter 移速变为 50% |
| D5 | 雾隐分身 / Mist Clones | 防御 | 手动 | 8s | 生成 2 个虚像 |
| P1 | 远程遥感 / Sense | 被动 | 手动 | 8s | 35m 内 Hunter 缩小到 50% |
| P2 | 子弹清空 / Empty Bullet | 被动 | 手动 | 瞬时 | 清空所有 Hunter AK 弹药 |
| P3 | 无声步伐 / Silent Steps | 被动 | 手动 | 18s | 脚步声不播放 |
| P4 | 极度免疫 / Extreme Immunity | 被动 | 手动 | 25s | 免疫伤害和 Hunter 控制 |
| P5 | 复活卡 / Revival Card | 被动 | 自动 | 5s | 死亡后 5s 自动复活到远离 Hunter 的位置 |

## 5. Hunter Pool

Hunter 卡牌设计目标是补足搜索、控制、资源、反隐四类手段, 避免 Hunter 只依赖 AK 和手电。

| ID | 名称 | 类型 | 触发 | 时长 | v0.1 效果 |
| --- | --- | --- | --- | --- | --- |
| H1 | 脉冲扫描 / Pulse Scan | 追踪 | 手动 | 6s | 24m 内 Prop 轮廓/音频提示 |
| H2 | 黑光显影 / Blacklight | 追踪 | 手动 | 8s | 18m 内 Prop 显形提示 |
| H3 | 超频弹匣 / Overclock Rounds | 资源 | 手动 | 8s | 补充 60 弹药并短时移速提升 |
| H4 | 重力网 / Gravity Net | 控制 | 手动 | 8s | 10m 内 Prop 移速变为 55% |
| H5 | 回声标记 / Echo Marker | 追踪 | 手动 | 5s | 标记 35m 内最近 Prop |
| H6 | 光牢 / Light Cage | 控制 | 手动 | 7s | 12m 内 Prop 显形并减速 |
| H7 | 炮塔过载 / Turret Overdrive | 资源 | 手动 | 10s | 重置自动炮塔过热并记录过载窗口 |
| H8 | 补给缓存 / Ammo Cache | 资源 | 手动 | 瞬时 | 补充 AK 弹药到上限 |
| H9 | 肾上腺素 / Adrenaline | 控制 | 手动 | 6s | Hunter 移速提升到 145% |
| H10 | 信号干扰 / Signal Jammer | 控制 | 手动 | 6s | 14m 内 Prop 收到干扰反馈 |

## 6. 平衡约束

- 卡牌只在一局内有效, 不做跨局经济。
- 同一玩家一局最多 2 张卡, 且不重复。
- 反应卡占用一个卡槽, 因此强保命会牺牲主动战术。
- Hunter 卡牌以搜索/控制/资源为主, 不直接增加秒杀能力。
- Prop 卡牌以脱战/欺骗/保命为主, 不直接攻击 Hunter。

## 7. 后续增强清单

- 抽卡阶段暂停或软锁准备倒计时, 等所有玩家选完后再进入正式准备。
- 卡牌选择 UI 增加稀有度、分类色、详细描述和确认态。
- Decoy/Mist Clone 接入可被攻击、炮塔锁定优先级和假血条。
- Flashbang/Paint Bomb 接入真实屏幕 shader overlay。
- Signal Jammer 接入 `Network._server_use_card_slot` 的范围校验, 让 Prop 手动卡短时发动失败。
- Hunter 反隐卡与 Stalker 阴影系统、Chameleon 涂装系统做更细的反制参数。

## Current Draft Timing Contract

- Start Match enters `CARD_DRAFT` first; `PREP` starts only after all active non-spectator players finish drafting.
- Each player gets 2 pick rounds. Each round offers 3 cards and gives the player 10 seconds to choose.
- The full draft budget is 20 seconds per player and does not consume hider preparation time.
- If a player does not choose before the current round expires, the server randomly keeps one of the 3 visible choices.
- The first kept card is synced to the card loadout immediately, so slot 1 appears while round 2 is still active.
- The central draft UI keeps cards prominent over a blurred/tinted background and shows both pick and total countdowns.
