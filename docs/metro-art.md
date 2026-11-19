# Preview：华新站与深圳街景

仅用于仓库根目录的 Preview 工程；本轮没有修改 wallpaper 或桌面宿主。

## 美术与参考

场景把华新站元素与深圳海滨城市组合为侧视模拟画面，不是华新站的地理布局或建筑测绘。站内参考浅色格栅吊顶、灯带、全高屏蔽门、浅灰地砖、蓝色三号线标识和花纹立柱。建筑、人物和车辆保持独立图层。

- [华新站三号线站台实景](https://commons.wikimedia.org/wiki/File:Platform_of_Hua_Xin_Station.jpg)：寿司猫，2011-07-05，原照片为 CC BY-SA 3.0；参考建筑构件与色彩，照片未作为贴图分发，花纹为重新生成的设计。
- [华新站入口参考](https://www.gaode.com/place/BV10249910)：玻璃顶棚、站口标识和结构参考，未使用原照片贴图。
- [深圳市交通运输局：三号线新型列车上线](https://jtys.sz.gov.cn/ydmh/jtcx/dtcx_180970/cxtx/content/post_11701791.html)：蓝绿车身、六节编组参考。
- [深圳市政府：华强北地区规划文本](https://pnr.sz.gov.cn/attachment/0/392/392299/5835706.pdf)：红荔路、华强北路文字参考。
- [深圳市城管局：簕杜鹃](https://cgj.sz.gov.cn/xsmh/gysz/shhd/content/post_10774341.html)：深圳市花及其道路绿化应用参考。
- 既有公交、汽车及开源项目参考见 [vehicle-art.md](vehicle-art.md)。本轮没有新增第三方代码。

所有新增 PNG 使用内置 imagegen 生成或编辑，没有使用 CLI/API 回退。完整提示词见 [art-prompts/2026-11-19-huaxin.json](art-prompts/2026-11-19-huaxin.json)。

| 素材 | 实际使用部分 |
| --- | --- |
| assets/huaxin-platform.png | 地下吊顶、墙面、玻璃材质、花纹立柱、站台地面 |
| assets/huaxin-entrances.png | 两座站口轮廓及留空的内部，清除了多余扶梯头和栏杆 |
| assets/metro-escalator.png | 金属材质与两端踏板；直线扶手和玻璃框由程序绘制 |
| assets/shenzhen-shelter.png | 近侧候车亭、长椅及显示屏边框；玻璃是程序透明层 |
| assets/shenzhen-bougainvillea.png | 簕杜鹃花箱，花叶轻微摆动，石材底座固定 |

## 空间和行为

- 两个入口内留出通道，单条连续扶梯穿过楼板开口直达站台，左下行、右上行；没有中间站厅或第二段楼梯。
- station_routes.gd 是入口、扶梯、人物路径的共同几何来源。扶梯图像上下锚点也来自这套坐标，24 秒乘梯时间同时控制人物和踏步。
- 两位现有居民执行完整进出站行程，不新增重复角色；雨天入站先收伞。其他角色继续候车、乘车、散步等活动。
- 站台地面、屏蔽门门槛和车厢地板分开定位。列车在门后，行人在门前；仅停靠位置对应的十二扇门开启。
- 上下客只有在门全开、且能在开始关门前完成时才启动，公交两侧和地铁共用这一规则。
- 接绿色汽车的乘客在靠海人行道上下车，避免横穿两条车道及站口。
- 地面昼夜调色不影响地下电照明；雨雪止于地面。路牌、站名和到站屏由程序绘字。
- 到站倒计时为模拟数据，不是实时交通接口。人物行程与真实线路、设备位置没有一一对应关系。

## 验证与复现

使用项目内 Godot 4.6：

```powershell
& '.tools/godot/Godot_v4.6-stable_win64_console.exe' --headless --path . --editor --import
foreach ($case in 'smoke','residents','citizen_simulation','station_logic','weather_preview') {
  & '.tools/godot/Godot_v4.6-stable_win64_console.exe' --headless --path . --script "tests/$case.gd" --quit-after 600
}
```

每个脚本都应输出各自的 TEST_PASSED 标志，不能只凭退出码判定通过。station_logic 检查不同缩放布局的入口对接、图像与人物锚点、完整进出站、收伞、角色数量，以及连续多个班次的开门/上下客约束。

实际渲染检查需要图形环境：

```powershell
& '.tools/godot/Godot_v4.6-stable_win64_console.exe' --path . --script tests/capture_station.gd -- --after
& '.tools/godot/Godot_v4.6-stable_win64_console.exe' --path . --script tests/capture_station.gd -- --record-route
ffmpeg -y -framerate 30 -i .tools/route-frames/%04d.png -frames:v 1020 -c:v libx264 -crf 20 -pix_fmt yuv420p -movflags +faststart .tools/huaxin-route.mp4
```

截图覆盖原比例、1600×1000 紧凑视图、空站、进站、停站、驶离和雨天；34 秒录屏展示同一角色走进入口、踏上连续扶梯、抵达站台。产物保存在 Git 忽略的 .tools/，不进入壁纸程序。
