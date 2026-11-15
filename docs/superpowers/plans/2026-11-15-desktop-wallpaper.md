# 深圳桌面壁纸原型 Implementation Plan

**Goal:** 以已选定效果图为基础，交付可预览的 Godot 原型和可单独启用的 Windows 桌面壁纸入口。

**Architecture:** Godot 负责按屏幕比例绘制场景、真实时间光照、天气与交互；独立 Windows 启动脚本负责尝试将窗口置于桌面图标下方，失败时结束壁纸窗口并保留预览入口。天气状态独立缓存，并清楚区分实时数据与模拟画面。

**Tech Stack:** Godot 4.6、GDScript、PowerShell、Win32 API、本地 PNG 和 JSON。

**Spec:** `像素城市模拟游戏策划案.md` 和用户确认的 `assets/shenzhen-reference.png`。

## Global Constraints

- 使用用户指定的 `exec-27c3a240` 画面；不重画天际线或改变布局。
- 默认预览不替换现有壁纸。实验性桌面集成必须可退出、可恢复。
- 不把静态车辆、场景或推算显示成实时交通信息；真实线路数据需核实来源后再接入。
- 天气使用深圳地点，失败时明确提示；不生成假实时数据。
- 人物、公交、地铁、地标与光照的效果需要分离素材后才能成为完整动态模拟；不得声称静态图已经实现真实模拟。

## Tasks

1. 将原图复制到 `assets/shenzhen-reference.png`，创建 `project.godot`、`main.tscn` 和 `scripts/city.gd`，绘制按比例适配的场景并在预览中支持全屏切换、状态面板与退出。
2. 在 `scripts/city.gd` 中使用系统时间控制昼夜光照，使用 `HTTPRequest` 获取 Open-Meteo 深圳天气并标注状态；缓存成功结果到 `user://weather.json`，离线时提示缓存时间。
3. 创建 `启动预览.ps1` 和 `启动桌面壁纸.ps1`，后者调用 `scripts/desktop-host.ps1` 和 Win32 API 检测壁纸层，不能定位时退出并提示。
4. 使用 Godot `--headless --editor --quit` 导入素材、`--headless --quit-after` 验证脚本启动；通过桌面句柄探测与窗口预览验证 Windows 环境，并记录未完成能力。
