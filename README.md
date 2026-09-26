# lr_extra_gimmicks

给 `vivid/stasis` 补上**原版有、但 Custom Gimmicks 模组没实现**的谱面 gimmick。

当前实现：**`lr_slash` / `lr_slash_color`**（原版 `obj_distortedfate_gimmick` /
`obj_firstbreath_gimmick` 里的竖 slash 效果）。

> 面向作者的使用说明在文末「作者怎么用」一节。

---

## 一、它填的是什么缺口

`lr_slash` 只存在于两个**铺面专属**gimmick 库里，官方谱之外没有任何办法用到：

| 来源 | 位置 |
|---|---|
| DistortedFate 库 | `dump_v2\CodeEntries\gml_Object_obj_distortedfate_gimmick_Create_0.gml:51` |
| FirstBreath 库 | `dump_v2\CodeEntries\gml_Object_obj_firstbreath_gimmick_Create_0.gml:46` |

Custom Gimmicks v1.12.7 里**没有**它：代码搜 `lr_slash` 零命中，官方文档
`documents\Custom Gimmick说明.md` 也没有；它只有 `slash_anycol` / `set_slash_col`。
游戏目录下全部 54 个 `.vsm` 也都没用过 `lr_slash`——所以这是**新功能**，不是修 bug。

**它和 `slash_anycol` 不是一回事**（这是它值得移植的原因）：

| | `slash_anycol`（已有） | `lr_slash`（本模组） |
|---|---|---|
| 画法 | `o_anycol_slash_Draw_0`：`draw_line_width(-6, left_y, 326, right_y, width)` —— **横向**斜线 | `o_lorelei_slash_renderer_Draw_0`：`draw_line_width(top_x, -10, bottom_x, 190, width)` —— **竖向**斜线 |
| 位置 | `left_y` / `right_y` 随机 | `side = 207 * irandom(1)`、`top_x` / `bottom_x` 随机 → **左半屏或右半屏** |
| 混合 | 单遍，`color == 0` 走普通模式 | **分两遍**：`color == 0` 的先用普通模式画完，再切 `bm_inv_dest_color` 画 `color != 0` 的（所以 `color = 0` 是"反相擦除"） |
| 触发密度 | tween 驱动，值 = 每帧生成强度，需要一直挂着 | 回调**一次生成 N 条**，靠 `ms` 自己排程 |

原版两套同名实现语义不同（DF 版 `value1` 无效、颜色靠 `lr_slash_color` 随机换色；
FB 版 `value1` 是条数、生成黑白两批）。本模组**没有逐字复刻**，而是取一套正交语义，见下。

## 二、文件结构

```
mods/lr_extra_gimmicks/
├── codepatches.json                              # 一条：把宿主对象挂到主菜单按钮 Step 末尾
├── codepatches/
│   └── mount.gml                                 # 插入的单行代码
├── codes/
│   ├── gml_Object_o_mod_lrgmk_Create_0.gml        # 注册 gimmick + 日志工具
│   └── gml_Object_o_mod_lrgmk_Step_0.gml          # 消费请求队列、生成 slash
└── objects/
    └── o_mod_lrgmk.json                          # 常驻对象壳（persistent）
```

## 三、工作原理

### 注册（为什么用 `UnlimitedAddGlobalMod`）

本项目选择**只走 Custom Gimmicks**：

* 用 `UnlimitedAddGlobalMod(name, weight, cb, endCb)`（索引 129 起），**不占用原版
  0..127 表里剩下的 54 个名额**；
* 代价：谱面必须写 `!obj: obj_custom_gimmick`，且必须装 Custom Gimmicks；
  官方谱永远看不到这些名字。

注册时机有硬性要求：Custom Songs Mod 的 `load_text_mods()` 在**解析 `.vsm` 时**为每行记

```gml
ms.ig = struct_exists(global.mods, ms.m)      // CustomSongsGmk.gml:89
```

而 Custom Gimmicks 的 `codepatches/updateMod.gml:19` 对 `ig == true` 的行按名字走
`global.mods` / `global.mod_callbacks`。所以**名字必须在谱面解析前就进 `global.mods`**。

宿主对象的挂载点因此选在主菜单按钮：

```json
{
  "Entry": "gml_Object_o_newmainbutton_Step_0",
  "Function": "",
  "ExternalFile": "mount.gml",
  "Type": 3
}
```

`mount.gml` 只有一行 `if (!instance_exists(o_mod_lrgmk)) instance_create_depth(...)`，
用 **`Type 3` + 空 `Function` = 插到条目末尾**，所以原版那 12 行 Step 逻辑**不被覆盖**
（对比：`custom_episodes` 是整条目覆盖，维护负担更大）。VML 的 `InsertAtPosition` 会自己
在插入内容前后补换行，所以 `mount.gml` **必须是单行**，否则后半截会被塞进注释里。

### 回调 → Step 的分层

回调跑在 gimmick 实例的 scope 里，**只能碰 `global.*`**（读自己的实例变量会
`Variable ... not set`）。所以回调只做一件事：往 `global.mod_lr_queue` 里 push 一条请求，
真正的工作由 `o_mod_lrgmk` 的 Step 事件做（那里有真实实例和 `cc`）。

### `ms` 为什么是"排程"而不是"现在"

`o_lorelei_slash` 自带的机制（这是它比 `slash_anycol` 省的地方）：

```gml
// PreCreate_0: self.color = 0; self.ms = cc.currentms;
// Create_0:    timer = (cc.currentms - ms) / 1000;
// Step_0:      timer += cc.timediff; width = EaseOutQuad(timer, 12, -12, 1);
//              if (timer >= 1) instance_destroy();
```

传一个**未来**的 `ms`，`timer` 就是负的 → 这条 slash 先不可见，到点才淡入。
所以回调把 `start`（该拍的时间）直接当 `ms` 传下去即可，**不需要每帧生成**。

### 全局状态与快重开

| 全局 | 作用 |
|---|---|
| `global.mod_lr_queue` | 待处理请求（数组） |
| `global.mod_lr_color` | 当前颜色，`lr_slash` 的 value2 留空时用它 |
| `global.mod_lr_renderer` | 共享的 `o_lorelei_slash_renderer` 实例 |
| `global.mod_lr_cc` | 当前 `cc` 实例 id，用来识别快重开 |
| `global.mod_lr_ready` | Create 跑完的标志 |

快重开是 `room_restart()`（`cc_Step_1:18`）：**房间号和索引都不变，只重建 `cc`**，
所以判重开只能比较 `cc` 实例 id——`global.mod_lr_cc != cc` 时清空队列并复位颜色。
渲染器**故意不重置**：它是一次全局绘制，新旧 slash 共用。

## 四、作者怎么用

```vsm
!obj:obj_custom_gimmick
62,0,linear,_,16777215,lr_slash_color,-1     ; 设定后续 slash 的颜色（value2）
66,0,linear,3,_,lr_slash,-1                  ; 这一拍生成 3 条，用当前颜色
70,0,linear,_,_,lr_slash,-1                  ; 这一拍生成 1 条，用当前颜色
74,0,linear,2,255,lr_slash,-1                ; 这一拍生成 2 条，颜色 255（黑/擦除）
```

| gimmick | value1 | value2 |
|---|---|---|
| `lr_slash` | 生成条数（`_` = 1，超过 64 按 64 处理） | 颜色（`_` = 用当前色） |
| `lr_slash_color` | 忽略 | 颜色（`_` 时整条忽略并写日志） |

* **颜色格式**：GameMaker 的打包颜色值，也就是 `make_color_rgb(r, g, b)` 的返回值
  （`c_white = 16777215`、`c_red = 255`）。写 RGB 十六进制**不会**被自动换序——
  本模组刻意不做 Custom Gimmicks `col_convertion` 那种 R/B 互换，避免和 `set_slash_col`
  的语义打架。
* **每拍只写一行**：到点触发一次；同一条 slash 的动画由 `o_lorelei_slash` 自己按 `ms` 推进。
* **`braces`（beat 区间）**：`66:70:0.5` 这种写法会展开成多个 beat，每次触发各生成一批，
  效果就是"每半拍一条"，符合直觉。
* 官方谱无效，未写 `!obj` 的谱面也无效。

## 五、日志（排查第一步）

作者没法给谱面内功能开 `debuglog`，所以本模组**无条件**写日志：

```
C:\Users\<你>\AppData\Local\vividstasis\lr_extra_gimmicks.log
```

注意落点是**存档目录**，不是游戏目录。会记录：

```
[time]  gimmick registered: lr_slash
[time]  gimmick registered: lr_slash_color
[time]  chart started (cc 5)
[time]  lr_slash_color=16777215 rgb=255/255/255
[time]  lr_slash count=3 colour=16777215 rgb=255/255/255 ms=21063 currentms=21063
[time]  lr_slash count=1 colour=16777215 rgb=255/255/255 ms=22340 currentms=22340
```

`rgb=` 三个分量用来确认颜色到底被解释成什么（`color_get_red/green/blue` 的结果）——
"颜色看起来反了"这类问题看这一行就够。

注册失败也会写清楚原因（缺 Custom Gimmicks / `global.mods` 不存在 / 抛异常）。

### 踩坑：这个 build 没有 `function_exists()`

排查"依赖的模组装了没"时**不要**用 `function_exists`：

```gml
if (!function_exists("UnlimitedAddGlobalMod"))   // ✗ 进主界面就崩
```

这个 build 里**根本没有这个函数**，编译器会把它编译成实例变量读取，游戏直接死在

```
ERROR in action number 1 of Create Event for object o_mod_lrgmk:
Variable o_mod_lrgmk.function_exists(109615, -2147483648) not set before reading it.
```

游戏自己的 4842 个代码条目里也**一次都没用过** `function_exists`。本模组现在的守卫用 VML
自己的握手全局（和 `custom_episodes` 同一套，实机验证过），里面每个函数都是原版用过的原生：

```gml
_cg = (variable_global_exists("vml_mods") && is_struct(global.vml_mods)
    && variable_struct_exists(global.vml_mods, "custom_gimmicks_mod"));
```

`global.vml_mods.*` 由各模组的 `codepatches/mod_info.gml` 写入（Custom Gimmicks 的是
`mod_info.gml:1-2`）。加上 `try/catch` 兜底，即使这个判断假阳性，代价也只是多一行日志。

**通用教训**：往这个 build 里写任何"原版从没用过"的函数都是在赌；写完用
`grep <函数名> dump_v2\CodeEntries` 对一遍，比事后实机崩一次便宜得多。

## 六、验证状态

已完成：

1. `gml-lint` / `check-recursion` / `check-scope` 全过（具名函数全部在事件顶层）
2. VML 打包成功，日志出现 `处理模组：./mods\lr_extra_gimmicks` + `代码修补完成`
3. UTMT dump 复核：`gml_Object_o_mod_lrgmk_Create_0` / `_Step_0` 都已编译进 `data.win`，
   且 `gml_Object_o_newmainbutton_Step_0` 末尾确实多了挂载那一行（原版 12 行逻辑完好）
4. `data.win` 体积 2,777,863,398 → **2,777,870,694** 字节（+7 KB，纯代码增量，无异常）

**未验证（需要实机）**：`o_lorelei_slash` 在自定义曲里是否真的画得出来。
`o_lorelei_slash` / `o_lorelei_slash_renderer` / `o_lorelei_sidething` 都在原版
`data.win` 里且事件完整，理论上任何房间都能用；但因为没有现成谱面用过它，
**必须靠测试谱确认**。测试谱：`Custom Songs\Self\ENCORE.vsm`（已写入上面示例）。

看日志 grep 关键词：`gimmick registered` / `chart started` / `lr_slash count`。

## 七、已知边界 / 没做的事

* 只实现了 `lr_slash` / `lr_slash_color`。同源但同样缺失的
  `lr_sides_blue` / `lr_sides_red` / `lr_sides_rev_blue` / `lr_sides_rev_red` /
  `lr_mountain_bg` **没有做**（其中 `lr_mountain_bg` 在原版里也没有回调，只是纯数值型，
  要用得先查原版谁读 `cc.mod_lr_mountain_bg`）。
* 官方谱、以及没写 `!obj: obj_custom_gimmick` 的自定义谱无效（设计如此）。
* 一层 codepatch 打在 `gml_Object_o_newmainbutton_Step_0` 上：如果游戏本体更新后那个条目
  变动到让 `Find` 失配，VML 只会跳过这条 patch（不报错），后果是宿主对象不被创建 →
  gimmick 静默无效。**谱面没反应时先看日志里有没有 `gimmick registered`**。
