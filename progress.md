# 对话进展 · 深圳像素城市：第八轮第 1 批（P0 白点 / P1 删路 / P6.1 星星）已完成待验收
更新时间：2026-11-20 20:20 · 来源会话：第八轮实现会话

## 已完成（全部未 commit；旧状态在 git 引用 refs/backup/round5-start；第八轮前的三张图层素材备份在 .tools/genbak/）
- 第 6/7 轮全部内容（见 git 未提交改动）：中央护栏烘焙纹理、地标优化、窗灯按房间开关、天气动态背景、地铁停运关灯、线路预设、书店咖啡馆、星月闪电、删对面 B 口。
- P0 高楼周围白点根治（判别结论：渲染为主、素材为辅）：
  - 主因①（夜）：city-windows.png 导入开着 fix_alpha_border，把地标灯光秀像素的 RGB 渗进 alpha=0 的天空纹素（2913 个天空纹素带窗户类）→ emissive 在地标周围点亮天空。修：city-windows/city-base 的 .import 设 fix_alpha_border=false，city-base mipmaps=false；导入后三张图与 PNG 逐纹素一致（.tools/import_audit.gd）。
  - 主因②（昼）：backdrop.gdshader 云的边缘/明暗用逐像素 bayer 抖动 + 逐行 h 阈值 → 塔边孤立白像素。修：云明暗改 2×2 块内整块分档、去抖动、h 按块取；塔轮廓 2px 环带内的云块须经天空连通到“完整可见”的云块，被塔遮一半的块最亮只到中间调（cloud_at，backdrop.gdshader:161 起）。
  - 次因：飞机尾迹碰到塔即整团不画（city.gd:1371 _trail_in_sky）；素材 10 个孤立亮纹素由 tools/gen_city.py:487 despeckle() 生成期去除（航空灯除外）；白天玻璃提亮 0.22→0.12（:315）。
  - R1：sample_base 缩小时改整纹素 box 平均，删除 base_smooth uniform 与 city.gd 绑定。实验 A/B 结论：2880×1800 下 sky/fill/fit 的 scene_scale 均 ≥0.95，本就走 texelFetch；像素网格 pixel2=off（用户实际配置 mode=fill）。
  - 验收：.tools/whitedot.py（10 组天气×昼夜，环带孤立亮点占比）sky/fill/fit@2880×1800 全 0.0000%，10 个时间点扫描全过。人物/水面/远塔贴图 mipmap 未动。
- P1：删除 park.gd draw_city_road 及调用；gen_city 背景本无此路。原路区沥青色像素 3295→0，白字 1→0。
- P6.1：星星只在天空 mask 且离塔 ≥3px；改整数哈希 hash_u（旧 hash 的“零星星星”其实排成 y=63 每 50px 一条虚线）；三种模式可见 9–12 颗。
- run_tests.sh 8 项全 PASSED。perf6 实测 dt p50=16.67ms（59.4fps，vsync 锁 60），与 progress 旧记录 70ms 差异原因未查明。

## 关键决策（用户明确表达，勿重议）
- 公园保持原布局在对侧草坪（第八轮用户澄清“之前是我理解错了”），P2“搬到近侧”取消；对侧草坪按原方案保留全部设施。
- 雷声不做；湖里加克制的可见游鱼（喂鱼/钓鱼者附近偶尔 2–3px 鱼影或跃出涟漪）。
- 目标屏 2880×1800 16:10；用户本机实际保存的是 fill 模式（%APPDATA%\PixelCity\preview-display.cfg）。
- 海改湖、精细栏杆；书店西式可进店有顾客；壁纸版 wallpaper/ 与 scripts/desktop-host.ps1 冻结；素材只经 tools/ 脚本生成；agent 无图像输入只靠像素统计；用户双击 Preview.cmd 确认后才 commit。
- 已有硬约束 .learnings/LEARNINGS.md：入口侧视、扶梯上端被侧墙遮、地下一层站台、两个公交站、中央隔离栏无斑马线。

## 未完成的待办（按优先级，均可直接动手）
- [ ] 用户 Preview.cmd 验收第 1 批（白点、删路、星星）。
- [ ] 第 2 批：P7 帧率（先在同机复测基线确认 16.67ms 是否属实，再看 lowres_layers 挂死）+ bus_shimmer；P3 fill 等裁切模式下地铁口补偿（_station_shift 推广，入口左缘 ≥8px）。
- [ ] 第 3 批：P2 仅保留“湖岸对齐”（park.gd SHORE=404 与水面 362–382 未贴合）+ 湖中游鱼。
- [ ] 第 4 批：P4 书店（屋顶线脚/可进门/顾客入座）、P5 地铁人流闭环、P6.3 受惊反应 2–3 种。
- [ ] 已知残留：fit 模式小窗（1600×1000，scene_scale≈0.74）阴/雾/雪白天环带占比 0.30–0.48%（程序云在缩小时混叠，非贴图路径）；雨/雪夜的雨滴雪花被统计计入（粒子层，设计如此）。
- [ ] 全部完成后跑 run_tests.sh、更新 README，用户验收后才 commit。

## 统计脚本用法
- 截图：`.tools/godot/Godot_v4.6-stable_win64_console.exe --path . -s .tools/whitedot_capture.gd -- <tag> [sky|fill|fit] [WxH] [noweather t=<秒> noair noclouds nomoon nostars noemissive noambient]`
- 统计：`python .tools/whitedot.py <tag>`（WHITEDOT_PASSED/STARS_OK）；对照：`python .tools/whitedot.py --diff base <tag>`；定位：`--dump <tag> <shot>`
- 导入核对：`... --headless --path . -s .tools/import_audit.gd`

## 恢复方式
新开对话第一条提示词：「读取 progress.md，先复述进度，再从未完成的待办继续」。
