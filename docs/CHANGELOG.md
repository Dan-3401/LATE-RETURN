# 开发更新日志 / Changelog

时间为**东京时间（UTC+9）**，括号内为 UTC。数据来自分支 `claude/sharp-knuth-0n3dex` 的 git 提交记录；「待提交」表示改动已在文件夹里、还没有 git 提交。
同一份数据另有 Excel 版本（项目文件夹外的 `迟归_开发更新日志.xlsx`），每次更新两边同步。

| # | 更新时间（东京） | 版本号 | 提交 | 更新 | 涉及系统 | 文件（新增 / 修改 / 删除） | 行数（+ / −） | 测试 |
|---|---|---|---|---|---|---|---|---|
| 1 | 2026-09-28 04:15（09-27 19:15 UTC） | Demo 1 | `908f697` | 便利店 Vertical Slice | 项目框架、美术管线、音频管线、玩家、便利店、库存、UI | 458 / 0 / 0 | +15363 / −0 | test_store.gd |
| 2 | 2026-09-28 04:39（09-27 19:39 UTC） | Demo 1 | `12d19c8` | 街道潜行 | 丧尸 AI、潜行、噪音、躲藏、死亡与检查点、街道 | 169 / 8 / 0 | +7285 / −11 | test_street.gd（36 项） |
| 3 | 2026-09-28 05:18（09-27 20:18 UTC） | Demo 1 | `96b76ef` | 学校营地结局 | 对话系统、营地、妹妹、结局、文档 | 51 / 14 / 0 | +2542 / −2 | test_full_flow.gd |
| 4 | 2026-09-28 05:20（09-27 20:20 UTC） | Demo 1 | `abd1216` | 打磨 | 音效、躲藏 UI | 0 / 3 / 0 | +27 / −0 | — |
| 5 | 2026-09-28 07:42（09-27 22:42 UTC） | Demo 2 | `57f9e72` | 每日循环 | 每日循环、营地 Hub、地图、外出、仓库、投掷物、日记 | 120 / 65 / 2 | +6548 / −283 | test_day_loop.gd |
| 6 | 2026-09-28 19:31（09-28 10:31 UTC） | Demo 2 | `87fd895` | 修复：地图点击 | 地区地图 | 0 / 3 / 0 | +37 / −14 | test_day_loop.gd 更新 |
| 7 | 2026-09-28 19:46（09-28 10:46 UTC） | Demo 2 | `a82b34d` | 自动存档与继续游戏 | 存档系统、主菜单、暂停菜单 | 2 / 9 / 0 | +508 / −31 | test_save.gd |
| 8 | 2026-09-28 20:10（09-28 11:10 UTC） | Demo 2 | `d182502` | 手持装备 | 装备、手持栏、拖放、背包 UI、存档 | 7 / 34 / 0 | +1278 / −344 | test_hand_equipment.gd |
| 9 | 2026-09-28 20:32（09-28 11:32 UTC） | Demo 2 | `a8f63af` | 多层光照与前景 | 渲染、光照、前景、图层约定 | 43 / 26 / 0 | +2742 / −239 | test_visual_layers.gd、shoot_scenes.gd |
| 10 | 2026-09-28 21:17（09-28 12:17 UTC） | Demo 2 | `c3b21fc` | 交互修复 + 躲藏战术 + 设置 | 可搜刮物、丧尸死亡、街道通行、剧情跳过、躲藏玩法、设置 | 11 / 43 / 0 | +2291 / −251 | test_round_hide.gd、test_settings.gd |
| 11 | 2026-09-28 22:10（09-28 13:10 UTC） | Demo 2 | `40e3f1e` | 营地仓库成为唯一数据源 | 营地仓库、外出结算、存档 | 4 / 16 / 0 | +1235 / −194 | test_storage.gd |
| 12 | 2026-09-28 22:24（09-28 13:24 UTC） | Demo 2 | `b2430f8` | 回家不再自动入库 | 营地仓库、外出结算、HUD | 0 / 8 / 0 | +164 / −299 | test_storage / day_loop / save 更新 |
| 13 | 2026-09-29 08:57（09-28 23:57 UTC） | Demo 2 · A1.1 | `3826dd1` | 堆叠系统 | 堆叠、右键菜单、物品动作、掉落物 | 5 / 26 / 0 | +1125 / −48 | test_stacking.gd（67 项） |
| 14 | 2026-10-13 01:35（10-12 16:35 UTC） | Demo 2 · 文档 | `ac8ba13` | README 交接手册 | 文档 | 0 / 1 / 0 | +550 / −208 | — |
| 15 | 2026-10-13 02:40（10-12 17:40 UTC） | Demo v2.01 | `370b1ea` | 背包规则 + 用词统一 + 版本号 | 背包 / 装备、物品移动、拾取、存档读取、文案、储藏间美术、地区地图、主菜单、文档 | 2 / 30 / 0 | +607 / −66 | test_backpack.gd（26 项） |
| 16 | 2026-10-13 02:56（10-12 17:56 UTC） | Demo v2.01 | `49439b9` | 日记字体补「间」字 | 日记字体、字体工具、文档 | 0 / 3 / 0 | +11 / −4 | —（相关的 test_full_flow / test_day_loop 重新运行通过） |
| 17 | 2026-10-13 03:20（10-12 18:20 UTC） | Demo v2.01 | `89d9428` | 终端同步工具 | git 流程、文档 | 0 / 1 / 0 | +1 / −0 | — |
| 18 | 2026-10-14 09:28（10-14 00:28 UTC） | Demo v2.01 | `cab2852` | 终端同步：可选推送 GitHub | git 流程、文档 | 0 / 1 / 0 | +1 / −1 | — |
| 19 | 2026-10-21 17:22（10-21 08:22 UTC） | Demo v2.01 | `c3ff4f3` | PNG 编码对齐 | 美术文件（仅编码） | 0 / 2 / 0 | +0 / −0 | — |
| 20 | 2026-10-24 16:32（10-24 07:32 UTC） | Demo v2.01 | `df87285` | README 日语简介 + main 分支 | 文档、git 流程 | 0 / 1 / 0 | +12 / −1 | — |

## 详细内容（按时间倒序）

### 2026-10-24

#### 16:32 · Demo v2.01 · `df87285` · README 日语简介 + main 分支

- 提交信息：README: Japanese overview at the top; note that main mirrors the work branch
- README 开头加一段日语简介（故事、分工、运行方法），方便日本的读者看懂
- 仓库改为公开，GitHub 默认分支设为 main，与工作分支保持同一个提交，「终端同步.bat」推送时两边一起更新
- README 补充说明
- 涉及系统：文档、git 流程
- 新增测试：—
- 改动：新增 0 个文件，修改 1 个，删除 0 个；+12 / −1 行

### 2026-10-21

#### 17:22 · Demo v2.01 · `c3ff4f3` · PNG 编码对齐

- 提交信息：Store art: keep the PNG encoding found on the user's machine (pixels unchanged)
- 便利店后墙和储藏间门两张 PNG：文件传到你电脑时会被重新编码，导致 git 一直显示这两张图「已修改」
- 这次直接提交你电脑上的版本，画面逐像素不变，只为让 git 状态干净
- 涉及系统：美术文件（仅编码）
- 新增测试：—
- 改动：新增 0 个文件，修改 2 个，删除 0 个；+0 / −0 行

### 2026-10-14

#### 09:28 · Demo v2.01 · `cab2852` · 终端同步：可选推送 GitHub

- 提交信息：README: terminal sync bat now offers to push the branch to GitHub (asks Y/N)
- 「终端同步.bat」最后会询问是否推送到 GitHub，按 Y 才推送，按 N 跳过
- 推送结果写进 sync_log.txt，失败不会影响本地仓库
- 同时修正本地两张 PNG（便利店后墙、储藏间门）的文件编码，使其与提交一致（画面不变）
- README 补充说明
- 涉及系统：git 流程、文档
- 新增测试：—
- 改动：新增 0 个文件，修改 1 个，删除 0 个；+1 / −1 行

### 2026-10-13

#### 03:20 · Demo v2.01 · `89d9428` · 终端同步工具

- 提交信息：README: how commits reach the user's repo while the local terminal is unavailable (terminal sync bat + bundle)
- 新增「终端同步.bat」（放在更新日志 Excel 同一文件夹）：你电脑上的终端不可用时，Claude 在云端提交并把提交打成补丁包 LateReturn_sync.bundle 放在同一文件夹，双击这个 bat 就能装进仓库
- 它只更新 git 记录、不改文件，会先检查不会丢掉你自己的提交，结果写进 sync_log.txt
- 旧的「迟归_同步.bat」已作废，可以删除
- README 补充这套流程
- 涉及系统：git 流程、文档
- 新增测试：—
- 改动：新增 0 个文件，修改 1 个，删除 0 个；+1 / −0 行

#### 02:56 · Demo v2.01 · `49439b9` · 日记字体补「间」字

- 提交信息：Diary font: rebuild the LXGW WenKai subset (adds 间); build script accepts the v1.250 TTF
- 日记手写字体（霞鹜文楷 v1.250）重新裁剪，补上「储藏间」的「间」字，日记里不再用系统字体顶替
- 字体脚本 build_hand_font.py 现在也可以直接用原版 TTF 文件生成
- README 删除对应的已知问题
- 涉及系统：日记字体、字体工具、文档
- 新增测试：—（相关的 test_full_flow / test_day_loop 重新运行通过）
- 改动：新增 0 个文件，修改 3 个，删除 0 个；+11 / −4 行

#### 02:40 · Demo v2.01 · `370b1ea` · 背包规则 + 用词统一 + 版本号

- 提交信息：Demo v2.01: backpack is the only bag capacity; wording unified; version number
- 背包改为塔科夫式：角色本身 0 格，背包提供全部格数（旧背包 10 格，工装服 +5 不变）
- 背包不能放进背包，只能穿在背包栏或放进营地仓库等容器
- 背包里还有东西时不能取下（提示「背包里还有东西，先拿出来才能取下。」）
- 地上的背包不能捡进背包
- 旧存档里放在背包内的背包读档时自动穿上或放进营地仓库
- 用词统一：「僵尸」改为「丧尸」
- 便利店后面的「仓库」改为「储藏间」（门牌美术、进入提示、钥匙名称与说明）
- 所有省略号统一为英文六点「......」
- 「附近的便利店」改为「学校旁边的便利店」
- 「这次什么也没带回来」加句号
- 地图上的地点名字下面加了一块纸色底，道路线不再穿过文字
- 删除未使用的 CAMP_TAGS 常量及其过时注释
- 版本号定为 Demo v2.01，主菜单右下角显示
- README 补充新规则、用词规范和提醒事项
- 新增 test_backpack.gd（26 项），12 套测试全部通过
- 涉及系统：背包 / 装备、物品移动、拾取、存档读取、文案、储藏间美术、地区地图、主菜单、文档
- 新增测试：test_backpack.gd（26 项）
- 改动：新增 2 个文件，修改 30 个，删除 0 个；+607 / −66 行

#### 01:35 · Demo 2 · 文档 · `ac8ba13` · README 交接手册

- 提交信息：README: detailed project handbook (Chinese) for handing work to other agents
- README 重写为详细的中文项目手册，用于交接给其他开发 Agent
- 涉及系统：文档
- 新增测试：—
- 改动：新增 0 个文件，修改 1 个，删除 0 个；+550 / −208 行

### 2026-09-29

#### 08:57 · Demo 2 · A1.1 · `3826dd1` · 堆叠系统

- 提交信息：A1.1: stack limits by item type, right-click item menu (use / split / discard), whole-stack pickups
- ItemData.stack_limit() 按类型限制堆叠（武器 / 装备 / 钥匙 / 剧情 1，投掷物 20，材料 / 杂物 67）
- InventoryActions 上下文层
- 右键菜单：使用 / 拆分 / 丢弃（仓库红字销毁确认，背包丢到地上为一个整组掉落物）
- 地面掉落物整组拾取或不拾取
- 涉及系统：堆叠、右键菜单、物品动作、掉落物
- 新增测试：test_stacking.gd（67 项）
- 改动：新增 5 个文件，修改 26 个，删除 0 个；+1125 / −48 行

### 2026-09-28

#### 22:24 · Demo 2 · `b2430f8` · 回家不再自动入库

- 提交信息：Storage: no automatic storing on return; the player stores / takes anything
- end_expedition() 不再移动物品，只记录「本次带回：」和日记内容
- 仓库界面显示仓库、背包、3 个手持栏和全部装备栏，任何物品都可以存取
- 外出花费仍只从仓库的食物 / 水扣除
- 涉及系统：营地仓库、外出结算、HUD
- 新增测试：test_storage / day_loop / save 更新
- 改动：新增 0 个文件，修改 8 个，删除 0 个；+164 / −299 行

#### 22:10 · Demo 2 · `40e3f1e` · 营地仓库成为唯一数据源

- 提交信息：Camp storage: single source of truth for all camp supplies
- 40 格 GameState.storage 取代营地食物 / 水计数器
- HUD、外出花费、地图检查、仓库角落外观都读真实物品
- 回家时自动入库、溢出进入待整理区
- 仓库实体与仓库界面
- 存档格式 v3
- 涉及系统：营地仓库、外出结算、存档
- 新增测试：test_storage.gd
- 改动：新增 4 个文件，修改 16 个，删除 0 个；+1235 / −194 行

#### 21:17 · Demo 2 · `c3b21fc` · 交互修复 + 躲藏战术 + 设置

- 提交信息：Searchables always checkable, corpse fix, passable street props, story skip, hide tactics, settings
- 修复：搜过的容器不能再互动、丧尸尸体滑动
- 街道汽车 / 路障改为只挡视线和瓶子
- 长剧情长按 Space 跳过
- 新增 4 个躲藏点
- 躲藏中投瓶、敲击引诱、小刀暗杀（镜头拉近）
- 设置菜单（显示模式、分辨率 15 秒确认、主音量 / 音乐 / 音效）
- 涉及系统：可搜刮物、丧尸死亡、街道通行、剧情跳过、躲藏玩法、设置
- 新增测试：test_round_hide.gd、test_settings.gd
- 改动：新增 11 个文件，修改 43 个，删除 0 个；+2291 / −251 行

#### 20:32 · Demo 2 · `a8f63af` · 多层光照与前景

- 提交信息：Layered smooth lighting, gameplay exposure, foreground layers with fade
- 光照贴图改为平滑衰减（精灵仍为 Nearest），新增 soft_wide / sky_wash / floor_spill / halo，阴影 PCF
- 每张地图多层光源
- LightZone.exposure 玩法曝光与视觉光照分离
- Foreground 与 ForegroundBlur 前景层及遮挡淡出
- z_index 图层约定与 rendering_layers.md
- 涉及系统：渲染、光照、前景、图层约定
- 新增测试：test_visual_layers.gd、shoot_scenes.gd
- 改动：新增 43 个文件，修改 26 个，删除 0 个；+2742 / −239 行

#### 20:10 · Demo 2 · `d182502` · 手持装备

- 提交信息：Hand equipment: three HAND quick slots, active hand item, drag & drop
- ItemData 新增 equippable / equipment_category / usable_in_hand / hand_behavior / weapon
- 装备栏 hand1~3 + 头盔 / 护甲 / 服装 / 背包
- move_item（移动 / 合并 / 交换、dry-run、不丢物品）
- 1/2/3 切换手持栏，HandBehavior（武器、投掷）
- HUD 快捷栏
- 背包拖放与绿 / 红 / 中性框
- 存档格式 v2
- 涉及系统：装备、手持栏、拖放、背包 UI、存档
- 新增测试：test_hand_equipment.gd
- 改动：新增 7 个文件，修改 34 个，删除 0 个；+1278 / −344 行

#### 19:46 · Demo 2 · `a82b34d` · 自动存档与继续游戏

- 提交信息：Add autosave and continue
- SaveSystem：单槽 user://savegame.dat，二进制、禁止对象、先写后改名、带版本号、损坏文件忽略
- 在街道检查点、营地 Hub、外出检查点自动存档
- 主菜单「继续游戏」（显示日期与地点）、「新游戏」覆盖前确认
- 测试使用独立存档文件
- 涉及系统：存档系统、主菜单、暂停菜单
- 新增测试：test_save.gd
- 改动：新增 2 个文件，修改 9 个，删除 0 个；+508 / −31 行

#### 19:31 · Demo 2 · `87fd895` · 修复：地图点击

- 提交信息：Fix region map ignoring left clicks; new remark for locked locations
- 地图的全屏 GUI 节点吃掉了鼠标点击，改为在 _input 中处理
- 锁定地点台词改为「后面的区域以后再来探索吧......」
- 测试改用真实鼠标事件
- 涉及系统：地区地图
- 新增测试：test_day_loop.gd 更新
- 改动：新增 0 个文件，修改 3 个，删除 0 个；+37 / −14 行

#### 07:42 · Demo 2 · `57f9e72` · 每日循环

- 提交信息：Demo 2: day loop, camp hub, region map, expeditions, warehouse, throwables, diary
- 第 1 天结局改为 9月28日手写日记 + 新任务「寻找能够治疗哮喘病的药」
- 营地 Hub、食物 / 水 HUD、结算提示
- 手绘地区地图与花费（只有便利店可去）
- 外出区域与外出检查点（不重复扣费、不复制物品）
- 持久世界掉落与刷新、随机仓库钥匙、仓库门与黑暗仓库、工装服（+5 格）
- 空瓶投掷（抛物线、噪音、丧尸冲向噪音点）
- 丧尸搜查范围逐渐扩大、躲藏点绿色视觉语言
- 妹妹闲聊池、结束今天确认、按真实日历生成日记、每日手枪子弹重置为 10
- 涉及系统：每日循环、营地 Hub、地图、外出、仓库、投掷物、日记
- 新增测试：test_day_loop.gd
- 改动：新增 120 个文件，修改 65 个，删除 2 个；+6548 / −283 行

#### 05:20 · Demo 1 · `abd1216` · 打磨

- 提交信息：Polish: positional zombie footsteps, hiding vignette
- 丧尸脚步声改为 2D 定位
- 躲藏时的暗角效果
- 涉及系统：音效、躲藏 UI
- 新增测试：—
- 改动：新增 0 个文件，修改 3 个，删除 0 个；+27 / −0 行

#### 05:18 · Demo 1 · `96b76ef` · 学校营地结局

- 提交信息：School camp ending, dialogue system, Demo End, full-flow test, docs
- 营地美术（教室、黑板计数、路线图、药与吸入器、灯、蜡烛、铺盖）
- 妹妹精灵
- DialogueData 对话脚本格式 + DialoguePlayer（打字机气泡、可跳过）
- 结局对话、黑边、拉远、Logo、Demo End
- README、素材清单、字体许可
- 涉及系统：对话系统、营地、妹妹、结局、文档
- 新增测试：test_full_flow.gd
- 改动：新增 51 个文件，修改 14 个，删除 0 个；+2542 / −2 行

#### 04:39 · Demo 1 · `12d19c8` · 街道潜行

- 提交信息：Street stealth slice: zombie AI, noise/vision/presence, hide spots, death & checkpoint
- 街道美术（路面、7 段立面、汽车、垃圾箱、草丛、火桶、路灯、城市背景）
- 3 种丧尸精灵
- 丧尸状态机与视觉 / 听觉 / 寻路 / 巡逻 / 攻击组件
- 吼叫连锁引怪
- 躲藏点、草丛、光照区、躲藏时呼吸减弱
- 死亡啃食、GAME OVER、Street Checkpoint 重来
- 关卡自有计时器
- 涉及系统：丧尸 AI、潜行、噪音、躲藏、死亡与检查点、街道
- 新增测试：test_street.gd（36 项）
- 改动：新增 169 个文件，修改 8 个，删除 0 个；+7285 / −11 行

#### 04:15 · Demo 1 · `908f697` · 便利店 Vertical Slice

- 提交信息：Store vertical slice: project setup, pixel art pipeline, player, lighting, loot loop
- 项目搭建（480×270、GL Compatibility）、InputMap 与 4 个 Autoload
- Python 像素美术与程序化音效生成管线
- 组件化玩家（移动、血量、呼吸、潜行、手电、武器、互动）
- 便利店关卡（瓦片、道具、遮挡、光照、前景视差、醒来开场与任务）
- 数据驱动物品 / 掉落表 / 容器、保底掉落、10 格背包、出口锁
- 主菜单、HUD、头顶气泡、暂停菜单
- 涉及系统：项目框架、美术管线、音频管线、玩家、便利店、库存、UI
- 新增测试：test_store.gd
- 改动：新增 458 个文件，修改 0 个，删除 0 个；+15363 / −0 行
