# 居民目的地与乘车模拟 Implementation Plan

> **For agentic workers:** Implement the steps in order and validate the shared Preview scene; this plan is executed in the current session.

**Goal:** 在预览中让每位现有角色按时间和个人行程选择目的地，步行、候车或乘地铁，并保持乘车状态与画面车辆同步。

**Architecture:** 保留现有 18 个唯一角色和渲染、天气及车辆循环；新增纯计算行程规划，居民状态机负责移动、等待、乘车及回到站台，不将不可见乘客提前传送回街道。出行仅覆盖现有两条人行空间和两个公交站、单个地铁站，是轻量二维模拟。

**Tech Stack:** Godot 4 / GDScript，现有 Preview 场景与 headless 测试。

**Spec:** 本次对话，参考 Cities: Skylines 公开的日程与交通概念，不使用其源码。

## Global Constraints

- 仅修改预览和测试；不改 wallpaper 快照。
- 每个角色形象只能有一个模拟实例；保留天气、互动与公交站显示。
- 公交与地铁上车、下车仅在对应车辆开门且停站时发生。

### Task 1: 行程规划与步行

**Files:** Create `scripts/citizen_planner.gd`; modify `scripts/residents.gd`, `scripts/city.gd`.

- [x] 按人物、昼夜和行程次数确定居家、工作或休闲目的地；原速率平滑移动并停留。
- [x] 有雨时保留避雨逻辑；空闲后继续原目的地，避免每帧重新规划。
- [x] 合适的行程选择本侧公交或地铁；与现有站台、时间及唯一角色模型衔接。

### Task 2: 真实车辆状态与回归

**Files:** Modify `scripts/residents.gd`, `scripts/city.gd`, `tests/residents.gd`, `tests/smoke.gd`, `README.md`.

- [x] 乘客上车后保持不可见，直到对应车辆下一次停站开门，过渡下车并继续目的地。
- [x] 验证多角色日程、长时间运行、站台同步、天气恢复、无重复和原地铁/公交行为。
- [x] 运行 Godot 回归与实际画面截图，复核 wallpaper 未变并提交本轮文件。
