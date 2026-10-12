# 迟归 / Late Return

Godot **4.3**（GDScript，GL Compatibility 渲染器）制作的 2D 横版像素风末日生存 Demo。当前版本：**Demo v2.01**（`project.godot` 的 `config/version`，主菜单右下角显示）。

> 从“醒来”到“回来”。哥哥在废弃便利店醒来，搜刮水和食物，潜行穿过已经不属于人类的街道，回到妹妹等他的学校教室。之后每天从营地出发，寻找能治疗妹妹哮喘病的药。

本文件既是项目说明，也是**交接给其他开发 Agent 的工作手册**：项目现状、架构、各系统位置与规则、如何运行测试、开发约定、已知问题都在这里。开始改代码前请完整读一遍「开发约定」和「已知问题」。

---

## 目录

1. [项目现状](#1-项目现状)
2. [运行与环境](#2-运行与环境)
3. [操作](#3-操作)
4. [游戏流程](#4-游戏流程)
5. [目录结构](#5-目录结构)
6. [架构总览](#6-架构总览)
7. [各系统详解](#7-各系统详解)
8. [数据驱动：如何添加内容](#8-数据驱动如何添加内容)
9. [美术、音频与场景生成管线](#9-美术音频与场景生成管线)
10. [测试](#10-测试)
11. [开发约定（Agent 必读）](#11-开发约定agent-必读)
12. [已知问题与未做的内容](#12-已知问题与未做的内容)
13. [开发历史](#13-开发历史)
14. [致谢](#14-致谢)

---

## 1. 项目现状

| 部分 | 状态 |
|---|---|
| Demo 1（便利店 → 街道 → 学校营地结局 → 第一页日记） | 完成，可从头玩到尾 |
| Demo 2（每日循环：营地 → 地图 → 外出区域 → 地点 → 回家 → 日记） | 完成；只有「学校旁边的便利店」可去，其余地点只显示 |
| 手持装备（3 个快捷栏）、背包拖放、装备栏 | 完成 |
| 营地仓库（40 格，营地食物 / 水的唯一数据来源） | 完成 |
| A1.1 堆叠系统（类型堆叠上限、右键菜单 使用 / 拆分 / 丢弃、整组拾取） | 完成 |
| Demo v2.01：背包成为唯一容量来源（塔科夫式）、用词统一（丧尸 / 储藏间 / 英文六点省略号） | 完成，**这是最近一次完成的任务** |
| 存档（自动存档单槽）、检查点、设置菜单（屏幕 + 声音） | 完成 |
| 自动测试 | 12 套测试脚本，最后一次全部通过（见第 10 节） |

当前分支：`claude/sharp-knuth-0n3dex`（每个功能一个提交，见第 13 节）。

---

## 2. 运行与环境

- 需要 **Godot 4.3 stable**（已验证 `4.3.stable.official.77dcf97d8`）。仓库里**没有** Godot 可执行文件，需自行下载。
- 主场景：`scenes/ui/main_menu.tscn`。

```bash
godot --path .                      # 运行游戏
godot --headless --path . --import  # 新增脚本 / 图片后先重新导入（更新 class_name 缓存与 .import）
```

显示设置（`project.godot`）：
- 设计分辨率 **480×270**；`stretch/mode=viewport`，`scale_mode=integer`。窗口默认 1440×810。
- 纹理过滤默认 **Nearest**，并开启 2D 像素对齐（transform / vertex snap）。
- 任何输出分辨率下，镜头看到的世界范围都一样。

Autoload（单例，按顺序）：

| 名称 | 文件 | 作用 |
|---|---|---|
| `GameState` | `scripts/systems/game_state.gd` | 全部运行时游戏数据：背包、装备、仓库、日期、外出状态、世界状态、检查点快照 |
| `AudioManager` | `scripts/systems/audio_manager.gd` | 音效 / 环境音播放、总线 |
| `NoiseSystem` | `scripts/systems/noise_system.gd` | 全局噪音总线（潜行核心） |
| `SceneManager` | `scripts/systems/scene_manager.gd` | 场景切换、淡入淡出、读取画面、像素光标 |
| `SaveSystem` | `scripts/systems/save_system.gd` | 自动存档单槽 |
| `Settings` | `scripts/systems/settings.gd` | 屏幕 / 声音设置（`user://settings.cfg`） |

物理层：1 world · 2 player · 3 enemies · 4 interactables · 5 pickups · 6 hitboxes · 7 vision_blockers。

---

## 3. 操作

| 按键 | 动作 |
|---|---|
| A / D | 移动 |
| Space | 跳跃 · 躲藏中：敲击引诱丧尸 · 长剧情中：长按跳过 |
| Shift | 奔跑（很响） |
| Caps Lock | 切换静步 |
| F | 互动 / 搜刮 / 拾取 / 躲藏 / 离开 |
| Tab | 背包 |
| H | 手电筒 |
| 1 / 2 / 3 | 选择手持栏；再按一次同一个 = 空手 |
| G | （营地，外出后，在妹妹旁边）结束今天 |
| 鼠标 | 瞄准 |
| 鼠标左键 | 使用手持物：开枪、挥刀、投掷 · 躲藏中且丧尸在范围内：小刀击杀 |
| 鼠标右键（按住） | 屏住呼吸 · **背包 / 仓库界面里：物品右键菜单** |
| Esc | 暂停（界面打开时先关闭界面 / 菜单） |
| F3 | 调试叠加层（仅 debug 构建） |

所有按键都在项目 InputMap 中定义，例如 `move_left`、`interact`、`inventory`、`hand_1..3`、`end_day`、`debug_toggle`。

---

## 4. 游戏流程

### Demo 1（剧情日，9月28日）

1. 主菜单 → 便利店醒来，教学手电筒。
2. 搜刮至少水 ×4、食物 ×4，有保底分配；还有收银台。凑齐前出口锁住。
3. **Street Checkpoint**：街道上的检查点。
4. 废弃街道：
   - 巡逻丧尸的视觉 / 听觉 / 存在感；
   - 草丛和躲藏点，屏息；
   - 吼叫会连锁引来其他丧尸，追逐；
   - 死亡 → GAME OVER → 从检查点重来。
5. 学校营地：与妹妹的头顶对话，结局。可长按 Space 跳过，跳过与正常看完结束在完全相同的状态。
6. 第一页手写日记 → 任务变为 **寻找能够治疗哮喘病的药** → 进入 Demo 2。

### Demo 2（之后的每一天）

1. 营地 Hub（`camp_hub.tscn`）：
   - 和妹妹说话；
   - 仓库角落 [F] 打开仓库界面；
   - 门 [F] 外出。
2. 手绘地图（`region_map`）：
   - 选地点，显示食物 / 水的花费；
   - 只有「学校旁边的便利店」可去，Wargame 中心、市中心医院、地铁站会说「后面的区域以后再来探索吧......」。
3. 出发时从**仓库**扣除真实的食物和水。
4. 进入外出区域（`region_store.tscn`）：
   - 第一次进入时建立**外出检查点**并自动存档；
   - 至少进入一个地点（便利店；有钥匙时还有后面的储藏间 `warehouse.tscn`）后，回家的门才打开。
5. 回到营地：
   - 显示「本次带回：」清单，稀有物另起一行；
   - **不会自动入库**，玩家自己在仓库界面把东西放进去。
6. 和妹妹说话或按 [G] 结束今天 → 按模板生成手写日记，内容是今天真实带回的东西 → 新的一天：
   - 日期 +1，按真实日历；
   - 手枪子弹回到 10；
   - 血量回满；
   - 其他一切保留。

---

## 5. 目录结构

```
project.godot
scenes/
  maps/          convenience_store / street / school_camp / camp_hub / region_store / warehouse
  player/        player.tscn
  enemies/       zombie.tscn
  interactables/ store/ street/ warehouse/   可搜刮容器、躲藏点、门
  props/         store/ street/ warehouse/   装饰物
  items/         pickup.tscn（地面掉落物）、bottle_projectile.tscn
  ui/            hud, inventory_ui, main_menu, pause_menu, region_map, diary, confirm_dialog, theme.tres ...
  effects/       tracer.tscn
scripts/
  actors/        player.gd, zombie.gd, sister.gd        （薄协调者，规则在组件里）
  components/    movement, health, breath, stealth, flashlight, weapon, interaction,
                 vision, hearing, ground_nav, patrol, attack, throw,
                 hand_equipment, hide_takedown
  ai/            state_machine.gd, zombie_state.gd, states/（13 个状态）
  hand/          hand_behavior.gd（基类）, weapon_behavior.gd, throw_behavior.gd
  items/         pickup_item.gd, bottle_projectile.gd, use/（物品“使用”效果）
  interactables/ interactable.gd, loot_container.gd, hide_spot.gd, grass_area.gd,
                 light_zone.gd, exit_door.gd, warehouse_door.gd, trigger_zone.gd
  levels/        level.gd（基类）+ 每张地图一个脚本, camp_storage.gd
  systems/       autoload 单例 + inventory.gd, inventory_actions.gd, loot_director.gd,
                 dialogue_player.gd, diary_writer.gd, game_camera.gd, render_layers.gd
  ui/            各界面脚本；item_slot.gd（拖放格子）, item_context_menu.gd（右键菜单）
  data/          Resource 类：item_data, weapon_data, loot_table, loot_entry, container_data,
                 location_data, dialogue_data, dialogue_pool, zombie_data, rig_data
  effects/       flicker_light, foreground_fader, tracer
resources/       items, weapons, loot_tables, containers, enemies, locations, dialogue, tilesets（.tres）
art/             生成的像素美术（characters, environment, fx, lights, ui）
audio/           生成的音效（sfx）与环境音（amb）
fonts/           Fusion Pixel（像素字体）、霞鹜文楷子集（日记手写体）+ OFL 许可
tools/
  art/           像素美术生成器（Python：numpy + Pillow）
  audio/         程序化音效生成器（numpy + scipy）
  builders/      用 Python 生成 .tscn 地图 / 道具场景
  fonts/         日记字体子集脚本
  tests/         自动测试（SceneTree 脚本）
docs/            art_asset_requirements.md（素材清单）, rendering_layers.md（图层 / 光照约定）
```

---

## 6. 架构总览

**核心原则**（贯穿整个项目，改代码时要保持）：

- **Actor 是薄协调者**：`player.gd` / `zombie.gd` 只读输入、转发意图、选动画。规则写在 `components/` 里，丧尸行为写在 `ai/states/` 里。
- **数据驱动**：
  - 物品、武器、掉落表、容器、丧尸类型、地点、对话都是 `.tres` 资源。
  - 新加同类内容只需新 `.tres`；新**行为**才写新脚本。
  - **禁止按物品名称写判断**，一律看 `ItemData` 字段（类型、`equipment_category`、`task_tag`、`use_behavior` 等）。
- **UI 只是视图**：
  - 所有界面只显示 `GameState`，自己不保存任何数据。
  - 所有改动都通过 `GameState` / `Inventory` / `InventoryActions` 的 API，并通过信号刷新界面。
- **单一数据来源**：
  - 营地的食物 / 水 = 仓库里真实物品的数量（按 `task_tag`），没有另外的计数器。
  - 背包、仓库、地面掉落物共用同一种堆叠数据 `{item, count}`。
- **永不吞物品**：任何移动、拆分、拾取在放不下时都拒绝并保持原状，不能部分丢失。

主要信号（`GameState`）：

| 信号 | 何时发出 |
|---|---|
| `inventory_changed` | 背包变化 |
| `equipment_changed` | 装备栏变化 |
| `camp_changed` | 仓库或待整理区变化 |
| `objective_changed` | 任务变化 |
| `ammo_changed` | 子弹数变化 |
| `active_hand_changed` | 当前手持栏变化 |

---

## 7. 各系统详解

### 7.1 库存核心 `scripts/systems/inventory.gd`（`Inventory`，RefCounted）

- 固定格数。每格是 `null` 或 `{"item": ItemData, "count": int}`，这就是全项目唯一的 ItemStack 格式。
- 主要函数：

| 函数 | 作用 |
|---|---|
| `add(item, n)` | 先补满同物品未满的堆叠，再占空格；返回放不下的数量；会发 `item_added`、`changed` |
| `can_add(item, n)` | 算上未满堆叠和空格，判断能否全部放下 |
| `remove(id, n)` / `remove_tag(tag, n)` | 移除，从后面的格子开始拿 |
| `split(index, amount)` | 拆分到**本容器**的第一个空格 |
| `first_free()`、`used_slots()`、`counts()`、`count_item()`、`count_tag()` | 查询 |
| `resize(n, force)` | 缩小时先往前整理，默认不丢物品 |
| `to_data()` / `from_data()` | 存档用，每格存 `{path, count}` |

- `GameState` 里的三个实例：

| 实例 | 内容 |
|---|---|
| `GameState.inventory` | 背包。**角色本身 0 格**（`BASE_CAPACITY = 0`），格数全部来自装备的 `capacity_bonus`：旧背包 10、工装服 +5。没背背包 = 没有背包格 |
| `GameState.storage` | 营地仓库，40 格（`STORAGE_CAPACITY`） |
| `GameState.pending` | 「待整理」溢出区。现在基本用不到，只作安全网保留 |

### 7.2 堆叠上限（A1.1）`scripts/data/item_data.gd`

- `ItemData.stack_limit()` 按 `item_type` 查 `STACK_BY_TYPE`：

| 类型 | 上限 |
|---|---|
| WEAPON / EQUIPMENT / KEY / QUEST | 1 |
| THROWABLE | 20 |
| MATERIAL / JUNK / AMMO | 67 |
| CONSUMABLE | 10 |
| CURRENCY | 999 |

- `stackable = false` 的物品一律为 1。
- 个别例外用 `max_stack_override`（大于 0 时生效）。
- **旧的 `max_stack` 字段已经删除**，代码里一律调用 `stack_limit()`。

### 7.3 装备与手持栏

- `GameState.equipment` 的结构是：栏位 id → `{item, count}` 或 null。栏位有：
  - 手持 `hand1`/`hand2`/`hand3`（类型都是 HAND）；
  - `helmet`、`armor`、`clothing`、`backpack`。
- 能放进哪一栏由 `ItemData.slot_type()` 决定，它看 `equippable` + `equipment_category` + `usable_in_hand`。钱、食物、水、钥匙永远不能装备。
- 默认配置：1 = 手枪，2 = 小刀，3 = 空。
- 只有当前选中的手持物生效，它运行自己的 `HandBehavior`（`scripts/hand/`）：
  - `weapon_behavior.gd`：手枪瞄准 / 射击、小刀挥砍；
  - `throw_behavior.gd`：瓶子瞄准与抛物线投掷。
  - 切换时先 `unequip()` 旧的，再 `equip()` 新的。由 `HandEquipmentComponent` 持有。
- 手持栏也可以放一叠物品（例如瓶子）。用完后 `consume_hand()` 会从背包补充。

### 7.4 物品移动 API（拖放的唯一入口）`GameState.move_item(src, dst, dry_run)`

- 引用格式（ref）：

| ref | 指向 |
|---|---|
| `{"kind":"bag","index":i}` | 背包格 |
| `{"kind":"storage","index":i}` | 仓库格 |
| `{"kind":"pending","index":i}` | 待整理区格 |
| `{"kind":"equip","slot":"hand1"}` | 装备栏 |
| `{"kind":"discard"}` | 丢弃格 |

- 支持移动、合并、交换，并做合法性检查：
  - 装备栏是否接受该物品；
  - 背包容量（卸下工装服或背包时，如果东西放不下就拒绝；卸背包时提示「背包里还有东西，先拿出来才能取下。」）；
  - **背包不能放进背包**：`ItemData.fits_in_bag()`（看 `equipment_category == BACKPACK`）为 false 的物品不能进背包格，包括交换和地面拾取，提示「背包不能放进背包里。」。背包只能穿在背包栏，或放进营地仓库等其他容器；
  - 待整理区不能作为目标。
- 返回 `""` 表示成功，否则是原因文本。
- `dry_run = true` 只做检查。拖动时 `ItemSlot` 用它来显示**绿框（可装备）/ 红框（不行）/ 中性框（背包格）**。
- 其他相关函数：
  - `quick_equip(bag_index)` / `unequip_to_bag(slot)`：背包界面的「装备 / 卸下」按钮；
  - `discard(ref)`：删除一整组，拒绝 KEY / QUEST；
  - `stack_at(ref)` / `container_of(ref)`：读取 ref 对应的数据。

### 7.5 右键菜单与物品动作（A1.1）

- **动作层** `scripts/systems/inventory_actions.gd`（`InventoryActions`，静态函数）。行为由**上下文**决定，不写在按钮里：

| 上下文 | 来源 |
|---|---|
| `Context.PLAYER_BACKPACK` | 背包格 |
| `Context.CAMP_STORAGE` | 仓库格 |

  `menu_state(ref)` 返回菜单里哪些选项可用。
- 【使用】只有 `ItemData.use_behavior != null` 时可用（`is_usable()`）。
  - 执行效果（`ItemUseBehavior.use(item, user)`，返回 `""` 表示成功）后，这一组数量 −1，为 0 时清空。
  - 目前只有绷带（`HealUseBehavior`，+35 HP）；满血时不消耗。
  - **装备不等于使用**，装备仍然通过拖放 / 装备按钮。
- 【拆分】只有数量 ≥ 2 时可用。
  - 窗口显示 `xx / yy`，yy 只是这一格的数量；合法范围 1 … yy−1，不合法时确认按钮为灰色。
  - 新的一组放到同一容器的空格；没有空格时提示「没有空余位置。」，什么都不变。
- 【丢弃】：

| 上下文 | 行为 |
|---|---|
| CAMP_STORAGE | 红字确认「你确定要销毁当前物品？」是 / 否；选「是」永久删除，不生成掉落物 |
| PLAYER_BACKPACK | `drop_to_ground()`：整组变成玩家身边的**一个** Pickup |

  仓库界面的「丢弃格」拖放也会弹出同样的红字确认。钥匙 / 剧情物品的丢弃是灰色。
- **UI**：
  - `scripts/ui/item_context_menu.gd`（`ItemContextMenu`）包含菜单、拆分窗口、确认窗口，背包界面和仓库界面各有一个实例。
  - 关闭时机：点击外部、Esc、使用成功、丢弃成功、打开拆分窗口。
  - 菜单打开期间，如果这组数据被其他操作改变，菜单会自动关闭，不会操作过期的数据。

### 7.6 地面掉落物 `scripts/items/pickup_item.gd` + `scenes/items/pickup.tscn`

- 一个 Pickup = 一整组物品的世界表现，保存 `item`、`count`、`instance_data`。
- `set_stack()` / `get_stack()` 与库存格式互转。
- 提示显示两行，例如「机械零件 ×35」和「[F] 拾取」。标题行是 `Interactable.prompt_title`。
- **整组拾取或完全不拾取**：
  - `Player.receive_item()` 先调用 `can_add`，放不下就说「已经装不下了。」，掉落物保持原样；
  - 放得下就按正常规则合并，例如 17/20 + 8 → 20 + 5。
- 搜刮容器（`LootContainer._spawn_drops`）每个掉落条目生成一个 Pickup。

### 7.7 营地仓库与营地资源

- 营地资源：
  - `camp_food()` / `camp_water()` / `camp_view()` = `storage.count_tag(&"food"/&"water")`；
  - `can_afford(cost)` / `missing_for(cost)`；
  - `begin_expedition()` 从仓库 `remove_tag` 扣除。
- `stash(item, n)`：放入仓库，放不下的进入待整理区（目前只用于开局初始物资和测试）。
- 仓库界面 `scripts/ui/storage_ui.gd`（`StorageUI`）：
  - 左边仓库 40 格；
  - 右边背包、3 个手持栏、头盔 / 护甲 / 服装 / 背包栏、丢弃格；
  - 拖放和背包界面一样。
- 仓库角落的外观（`scripts/levels/camp_storage.gd`）按真实库存分几个阶段显示。
- 右上角 HUD 的食物 / 水数字同样来自仓库。

### 7.8 外出与结算

- `GameState.expedition = {active, location, region, location_visited, seed, acquired, carried_out}`。
  - 外出期间，`_on_item_added` 记录获得的物品到 `acquired`。
  - `carried_out` 是出门时身上带的东西。
- `end_expedition()`：
  - **不移动任何物品**；
  - 计算带回 = `min(acquired, 现在携带 − carried_out)`，写入 `daily.gains`（给日记用），返回 `{"items": ...}` 给 HUD 显示「本次带回：」。
- `LootDirector`（`scripts/systems/loot_director.gd`）：
  - 关卡加载时决定每个容器的掉落，存进 `GameState.world`，跨天、死亡、换场景都保留；
  - 剧情日保证水 / 食物最低数量；
  - 自由阶段每次外出会让少数已搜过的容器刷新低价值物品，储藏间钥匙可能随机出现；
  - 随机数用外出 seed，重来时结果一样。
- `warehouse_door.gd`（便利店后面的**储藏间**，游戏内统一叫「储藏间」，营地的叫「营地仓库」）：
  - 没有钥匙时摇门会发出噪音；
  - 用过一次钥匙后永久打开。

### 7.9 潜行与丧尸 AI

- **噪音**：`NoiseSystem.emit_noise(pos, radius, source, kind)`。
  - 噪音只带发生地点，不带发出者的实时位置。
  - `kind` 例如 footstep、gunshot、roar、bottle、hide_lure。
- **听觉**：`HearingComponent` 听到的只是噪音发生的地点；中间隔墙时范围减半。
- **视觉**：`VisionComponent` 综合以下因素累积怀疑值：
  - 距离、朝向、视锥；
  - 射线遮挡（墙、车、vision_blockers 层）；
  - 玩家的 Presence 和是否躲藏。
- **存在感**：`StealthComponent` 计算 Presence（0~1）。
  - 来源有姿态、速度、手电，以及手工放置的 `LightZone.exposure`（−1~1）。
  - 视觉光照与玩法曝光是**刻意分开**的，详见 `docs/rendering_layers.md`。
- **呼吸**：`BreathComponent` 管周期呼吸噪音、屏息（氧气）、喘气。
- **丧尸状态机**（`scripts/ai/states/`，13 个状态）：idle、patrol、wander、suspicious、investigate、alert、chase、attack、search、return、patrol_resume、feed、dead。
  - 吼叫本身是大噪音，会把附近丧尸连锁引来。
  - 看到玩家躲进去的丧尸会来搜查，搜查时间更长、范围逐渐扩大。
- **躲藏点**（`hide_spot.gd`）：内部 Presence = 0，带绿色环境语言（杂草、藤蔓、苔藓、绿布）。躲藏中可以：
  - 投掷瓶子；
  - 按 Space 敲击，发出 `hide_lure` 噪音引诱丧尸；
  - 小刀在任意手持栏、且丧尸在范围内时，左键击杀（`hide_takedown_component.gd`，镜头拉近，探身一刀，再缩回）。
- **瓶子**：真实抛物线飞行，在碰撞点碎裂并发出噪音。丧尸会冲向噪音点，但不会因此放弃看得见的玩家。
- 死亡：附近丧尸围上来啃食，画面变暗红剪影 → GAME OVER → 从检查点重来。

### 7.10 存档与检查点 `scripts/systems/save_system.gd`

- 单一自动存档 `user://savegame.dat`，当前格式 **VERSION 3**（包含仓库和待整理区）。
  - 二进制 Variant 文件，读取时禁止对象，篡改的文件无法实例化脚本。
- 只在安全点保存：
  - Street Checkpoint；
  - 每次到达营地 Hub（新一天开始、回到家）；
  - 进入外出区域时的外出检查点。
- 外出中读档等同于「从检查点重来」：不会重复扣费，也不会复制物品。
- 快照：`GameState.snapshot()` / `apply_snapshot()`；检查点：`save_checkpoint()` / `restore_checkpoint()`。
- 主菜单：
  - 有存档时显示「继续游戏」，并显示日期和地点；
  - 「新游戏」覆盖存档前会先确认。
- **测试进程会自动使用自己的存档文件**（`user://savegame_test_<pid>.dat`），不会碰到真实存档。

### 7.11 其他系统

| 系统 | 位置 / 说明 |
|---|---|
| 场景切换 | `SceneManager.change_scene(path, fade, loading)`；`is_busy()`；像素光标 `set_cursor()` |
| 关卡基类 | `scripts/levels/level.gd`：持有 player / hud / camera；`wait()` / `fade()` 用关卡自己的计时器（关卡被释放时协程自动丢弃）；死亡流程 |
| 对话 | `dialogue_player.gd` + `resources/dialogue/*.tres`；头顶气泡 `WorldUI.say()`；妹妹闲聊池 `sister_pool.tres` |
| 日记 | `diary_writer.gd` 按模板生成（只写真实带回的东西）；`diary_screen.gd`；手写字体霞鹜文楷子集 |
| 互动 | `Interactable`（Area2D）：`prompt_title` / `prompt_text` / `prompt_key`、`condition`、`focus_priority`；玩家的 `InteractionComponent` 选择焦点 |
| 跳过剧情 | `cutscene_skip.gd`：只在 CUTSCENE 状态监听，长按 Space |
| 设置 | 屏幕（全屏 / 无边框 / 窗口 + 16:9 分辨率；改动 15 秒内不确认会恢复）和声音（主音量 / 音乐 / 音效 0-100）。总线：Master ← Music ← Ambience；Master ← SFX ← World, UI, Voice |
| 调试 | F3：FPS、玩家状态、Presence、噪音、丧尸状态、视锥、最后看到 / 听到的位置 |

### 7.12 渲染图层、光照、前景

- 详见 `docs/rendering_layers.md`。
- **z_index 表在两处，必须保持一致**：`tools/builders/layers.py`（场景生成器用）和 `scripts/systems/render_layers.gd`（代码里的 `RenderLayers.*`）。
  - 修绘制顺序问题时请选正确的图层，不要随手改 z_index。
- 像素精灵、瓦片、UI 一律 Nearest。只有光晕 / 阴影块（`halo.png`）和 `ForegroundBlur` 允许 LINEAR，`test_visual_layers` 会检查这一点。
- 每张地图有多层光源（冷色环境光、暖色局部光、天空光、手电）。
- 每张地图有近景 `Foreground`，以及更近的模糊层 `ForegroundBlur`；遮住玩家、丧尸或可互动物时会淡出（`foreground_fader.gd`）。
- UI CanvasLayer 层级：

| 层级 | 内容 |
|---|---|
| 10+ | WorldUI / HUD |
| 20 | 背包 |
| 21 | 仓库 |
| 25 | 地图 |
| 26 | 确认框 |
| 30 | 暂停 |
| 90 | 存档提示 |
| 100 | 淡入淡出 |

---

## 8. 数据驱动：如何添加内容

| 想加的东西 | 做法 |
|---|---|
| 新物品 | 新建 `resources/items/xxx.tres`（`ItemData`）：`id`、`display_name`、`description`、`icon`、`item_type`（决定堆叠上限）、`task_tag`（`food` / `water` 会算作营地资源）、`diary_name` |
| 特殊堆叠上限 | 设 `max_stack_override` |
| 可「使用」的物品 | 设 `use_behavior` 为一个 `ItemUseBehavior` 子类资源（新效果 = 在 `scripts/items/use/` 新建子类） |
| 手持装备 | `equippable = true`、`equipment_category`（PISTOL / MELEE_WEAPON / THROWABLE / HAND_TOOL）、`usable_in_hand = true`、`hand_behavior` 脚本、需要时加 `weapon`（`WeaponData`） |
| 服装 / 背包类装备 | `equipment_category` = CLOTHING / HEAD / ARMOR / BACKPACK，可加 `capacity_bonus` |
| 掉落 | `resources/loot_tables/*.tres`（`LootTable` + `LootEntry`：权重、数量范围），容器用 `resources/containers/*.tres`（`ContainerData`：提示文字、搜刮时间、台词） |
| 地点 | `resources/locations/*.tres`（`LocationData`：地图位置、花费、`playable`、`region_scene`） |
| 丧尸类型 | `resources/enemies/*.tres`（`ZombieData`） |
| 对话 | `resources/dialogue/*.tres` |

新增脚本或图片后运行 `godot --headless --path . --import`。

---

## 9. 美术、音频与场景生成管线

全部美术和音效都由脚本生成，素材清单与替换要求见 `docs/art_asset_requirements.md`。

- **美术** `tools/art/*.py`（Python 3 + numpy + Pillow）：
  - `pixlib.py` 提供 150 色统一调色板、逐像素着色、抖动、磨损，最后做调色板量化。
  - 角色用骨骼姿势绑定再栅格化成像素（`character.py`），48×48 帧。
  - 生成脚本有：`gen_player`、`gen_zombie`、`gen_store`、`gen_street`、`gen_city`、`gen_camp`、`gen_ui`、`gen_fx`、`gen_lights`、`gen_foreground`。
- **音频** `tools/audio/gen_audio.py`（numpy + scipy 合成）：属于功能性占位音效，以后建议换成录制的拟音。
- **场景生成器** `tools/builders/*.py`（`tscn.py` 写 Godot 文本场景）：

| 生成器 | 输出 |
|---|---|
| `build_store.py` | `convenience_store.tscn` |
| `build_street.py` | `street.tscn`、`region_store.tscn` 和街道道具 |
| `build_camp.py` | `school_camp.tscn`、`camp_hub.tscn` |
| `build_warehouse.py` | `warehouse.tscn` |
| `build_actors.py` | `zombie.tscn` |

  > ⚠️ **重新运行生成器会覆盖对应的 .tscn**。改地图时请改生成器再重新生成，或者确认生成器与手改内容一致后再运行。
- 字体：`tools/fonts/build_hand_font.py` 把日记手写字体裁成游戏用到的字符子集。**日记里新增汉字时要重新运行它**，否则缺字。参数可以是 npm 包 `lxgw-wenkai-webfont` 的目录，也可以直接是霞鹜文楷 v1.250 的 `LXGWWenKai-Regular.ttf`（仓库 `fonts/TTF/` 下）。

一键重新生成的命令见 `docs/art_asset_requirements.md` 开头。

---

## 10. 测试

测试是 Godot `SceneTree` 脚本（`tools/tests/`），会真的加载场景、推送真实的鼠标 / 按键事件。每套测试输出 `PASS/FAIL` 行，最后一行是 `RESULT: OK` 或 `RESULT: FAILED (n failures)`，退出码 0 / 1。

```bash
# 需要显示器才能截图；无头服务器用 Xvfb：
xvfb-run -a -s "-screen 0 1440x900x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
  -s res://tools/tests/test_stacking.gd -- /tmp/shots
```

| 测试 | 覆盖内容 |
|---|---|
| `test_store.gd` | 便利店搜刮循环 |
| `test_street.gd` | AI、潜行、死亡、检查点 |
| `test_full_flow.gd` | 主菜单 → 第一页日记 |
| `test_day_loop.gd` | Demo 2 每日循环、结算 |
| `test_save.gd` | 自动存档 / 继续 / 不重复扣费 |
| `test_hand_equipment.gd` | 手持栏、拖放、绿 / 红框 |
| `test_visual_layers.gd` | 光照、前景、过滤规则 |
| `test_round_hide.gd` | 可搜刮物、尸体、通行、跳过剧情、躲藏玩法 |
| `test_storage.gd` | 营地仓库 |
| `test_stacking.gd` | A1.1：堆叠上限、右键菜单、拆分、丢弃、整组拾取（67 项） |
| `test_backpack.gd` | Demo v2.01：背包是唯一容量来源、背包不能进背包、卸背包的条件、旧存档修复（26 项） |
| `test_settings.gd` | 设置菜单，**需要 ≥ 2560×1440 的屏幕**（Xvfb 用 `-screen 0 3840x2160x24`） |
| `shoot_scenes.gd` | 只截图每张地图，没有检查项 |
| `shot.gd` | 单场景截图工具：`-- <scene> <out.png> [秒] [动作]` |

最后一次全量运行：以上 12 套测试全部 `RESULT: OK`（Demo v2.01）。

**写测试的经验**：
- 测试脚本里不要在顶层直接引用依赖 autoload 的 `class_name`。autoload 那时还不存在，会报一个无害但干扰判断的 "Identifier not found: GameState"。请用 `root.get_node("/root/GameState")`，并在运行时 `load()` 脚本或资源。
- 对 Variant 用 `:=` 会报 "Cannot infer the type"，请写明类型，例如 `var x: int = ...`。
- 点击 UI 请推送真实事件：`root.push_input()`，坐标乘以 `root.size / Vector2(480, 270)`。现有测试里有 `drag()` / `click()` 辅助函数可以复制。
- 切换场景后等 `SceneManager.is_busy()` 结束，可参考各测试里的 `wait_scene()`。

---

## 11. 开发约定（Agent 必读）

这些是项目负责人在过去各轮中明确提出的要求：

1. **用中文回复用户**，最终汇报也用中文。代码、注释、提交信息保持英文（与现有代码一致）。
2. **先检查再修改**：先读相关的 `.gd` / `.tscn` / `.tres` 和本文件，理解已有系统。**不要推翻或重写正常工作的系统**，要在其上扩展。
3. **严格按范围做**：每轮只做要求的内容，完成后停止，不要顺手加功能。目前明确**不做**的有：重量、商店、制作、自动出售、搜索栏、物品品质、耐久、新物品、Wargame 地图、弹匣系统。
4. **不要建第二套系统**：背包、仓库、掉落物共用 `Inventory` 的 `{item, count}`。物品移动走 `GameState.move_item`；右键动作走 `InventoryActions`。
5. **禁止按名称硬编码物品行为**，用 `ItemData` 字段或行为资源。
6. **数据一致**：任何操作都要改真实数据（Inventory / equipment / storage），并通过信号刷新 UI；存档里也必须体现。禁止只改 UI 文本。
7. **永不吞物品**：放不下就拒绝并保持原状。
8. **测试**：
   - 每轮新增或更新自动测试，并运行**全部**测试套件。
   - 旧测试失败时，先判断是真回归，还是旧测试用了已被新规则取代的假设。如果是后者就更新测试，**绝不能为了让旧测试通过而恢复旧规则**。
9. **诚实汇报**：没有实际验证过的东西不要说“已测试正常”。
10. **视觉品质优先**：像素风统一、小而简洁的 UI。新 UI 沿用 `scenes/ui/theme.tres` 风格；不可用的选项要明显变灰，可操作的选项要有悬停反馈。改完 UI 请截图自查。
11. **汇报格式**：每轮结束按用户要求的条目汇报（通常包括修改文件、新增文件、实现方式、测试结果、未解决问题）。
12. **Git**：只在指定分支上开发和推送，用户没有要求时不开 PR。
13. **更新日志同步**：每次更新后同时更新 `docs/CHANGELOG.md` 和项目文件夹外的 Excel 表 `迟归_开发更新日志.xlsx`（含「简明更新表」页：更新时间 / 版本号 / 更新内容），两边保持一致。
14. **用词规范**：敌人统一叫「丧尸」；便利店后面的房间叫「储藏间」，营地的叫「营地仓库」；省略号统一用英文六点「......」；那家便利店统一叫「学校旁边的便利店」。
15. **每次新 Demo 递交后提醒用户**以下两项暂缓的代码问题（用户要求暂不修改，但每次都要提醒）：
    - 按物品名写判断：稀有物品名单 `GameState.RARE_ITEMS`、外出区域空瓶子提示 `count_item(&"empty_bottle")`、任务栏名称 `hud.gd` 里写死的「水」「食物」；
    - 同一条规则写了两份：便利店「水 ×4、食物 ×4」同时写在 `store_level.gd` 和 `loot_director.gd`，而且关卡里水按物品名统计、食物按类别统计。

---

## 12. 已知问题与未做的内容

- **地面掉落物不存档**：玩家丢在地上、或搜刮出来没捡的物品，离开地图、读档或第二天后就消失了。搜刮状态本身会保存。
- **营地也算地图**：在营地从背包丢弃也是放到地上（同样受上一条影响），只有仓库里的物品才会被销毁。
- **手持栏和装备栏没有右键菜单**，只能拖放整理。
- **目前只有绷带能「使用」**。食物和水是营地消耗资源，没有加使用效果。
- **未明确规定上限的类型由开发者自定**：消耗品 10、现金 999、弹药 67（目前没有弹药物品）。如需调整，改 `ItemData.STACK_BY_TYPE`。
- 待整理区（`pending`）现在基本用不到，只作安全网保留。
- 地图上只有「学校旁边的便利店」可去，其余地点未制作。
- 音效是程序合成的占位品；角色动画是骨骼栅格化，最值得手绘重做（见 `docs/art_asset_requirements.md`）。

---

## 13. 开发历史

| 提交 | 内容 |
|---|---|
| 908f697 | 便利店 Vertical Slice：项目搭建、像素美术管线、玩家、光照、搜刮循环 |
| 12d19c8 | 街道潜行：丧尸 AI、噪音 / 视觉 / 存在感、躲藏点、死亡与检查点 |
| 96b76ef | 学校营地结局、对话系统、Demo End、完整流程测试、文档 |
| abd1216 | 打磨：丧尸定位脚步声、躲藏暗角 |
| 57f9e72 | Demo 2：每日循环、营地 Hub、地图、外出、仓库、投掷物、日记 |
| 87fd895 | 修复地图左键无效；锁定地点新台词 |
| a82b34d | 自动存档与继续游戏 |
| d182502 | 手持装备：3 个 HAND 快捷栏、当前手持物、拖放 |
| a8f63af | 多层平滑光照、玩法曝光、前景层与淡出 |
| c3b21fc | 可搜刮物始终可检查、尸体修复、街道道具可通行、剧情跳过、躲藏战术、设置菜单 |
| 40e3f1e | 营地仓库成为营地物资的唯一数据来源 |
| b2430f8 | 回家不再自动入库，由玩家自行存取任何物品 |
| 3826dd1 | A1.1：按类型堆叠上限、右键菜单（使用 / 拆分 / 丢弃）、整组拾取 |
| ac8ba13 | README：中文交接手册 |
| 370b1ea | **Demo v2.01**：背包成为唯一容量来源、背包不能进背包；丧尸 / 储藏间 / 六点省略号 / 学校旁边的便利店用词统一；地图地名纸色底；版本号；更新日志 |

| 49439b9 | Demo v2.01 补丁：日记手写字体补上「间」字；字体脚本支持直接用 TTF |

完整的更新时间表见 `docs/CHANGELOG.md`。

---

## 14. 致谢

- 字体：[Fusion Pixel Font](https://github.com/TakWolf/fusion-pixel-font)，作者 TakWolf，SIL Open Font License 1.1（`fonts/OFL.txt`）。
- 日记手写体：[LXGW WenKai 霞鹜文楷](https://github.com/lxgw/LxgwWenKai)，SIL OFL 1.1（`fonts/OFL-LXGW-WenKai.txt`），由 `tools/fonts/build_hand_font.py` 裁成游戏所用字符的子集。
- 所有美术与音频由 `tools/` 中的脚本生成。
