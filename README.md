# Thought Mosaic · iOS Demo

依据 [Group05 Figma 原型](https://www.figma.com/design/Pjx45Twyn7aJrEpjT4hqSE/Group05?node-id=35-716) 实现的 SwiftUI 原生 iOS 灵感记录应用。最低 iOS 17，无第三方运行依赖，无后端账号。

## 运行

1. 安装完整 Xcode，并在 **Xcode → Settings → Components** 安装一个 iOS Simulator runtime。
2. 打开 `ThoughtMosaic.xcodeproj`，选择 `ThoughtMosaic` scheme 和任意 iPhone 模拟器，按 `⌘R`。
3. 真机运行时，在 app 与 widget 两个 target 的 **Signing & Capabilities** 中选择自己的 Team，并使用自己可用的 Bundle ID（widget ID 需以 app ID 加 `.` 开头）。模拟器不需要 Apple Developer 付费会员。

命令行构建、安装到可用模拟器：

```sh
bash scripts/run-simulator.sh
```

## 可以体验

- 启动直接进入快速记录页；空内容不能保存。
- 真实文字编辑、相册选图、真机拍照，多份素材可移除。
- 麦克风录音、计时、停止、播放；纯语音也可以保存。
- 标签搜索、多选、新建和取消修改。
- 保存确认、继续记录；返回可保留草稿、放弃或继续编辑。
- 记录与草稿写入 Application Support；重启 App 后仍保留。
- 保存列表支持文字与标签搜索，点击记录可继续编辑。
- 桌面小组件点击后进入相机；URL scheme 支持 `thoughtmosaic://direct`、`thoughtmosaic://camera`、`thoughtmosaic://screenshot`。
- 列表中的“体验 Figma 示例”加载原型的示例文字和灰色素材图形，方便在没有相机的模拟器里演示。

数据仅保存于当前设备，未实现云同步。录音保存为音频，不包含语音转文字。卸载应用会移除本地记录。

## iOS 与原型的对应

| 原型 | 实现 |
| --- | --- |
| 直接打开 App | 启动进入空白记录页，存在草稿则恢复 |
| 拍照组件 | WidgetKit 桌面组件 → URL scheme → 相机 |
| 截图后记录 | 相册选择截图 → 记录页；第三方 App 无法在系统截图浮窗添加自定义按钮 |
| 三指上滑 | iOS 不允许跨 App 监听全局手势；可用“打开 URL”快捷指令绑定辅助功能中的“轻点背面” |
| 黑白灰视觉 | 保留主色、卡片、按钮和标签层级；采用用户确认的 iOS 系统字体与 Dynamic Type |
| 设备外框与模拟状态栏 | 由真实 iPhone / 模拟器系统提供，不绘制在 App 内 |

标签使用原生 sheet，相机与相册使用系统界面；界面适应安全区、键盘、小屏与文字缩放。原图没有外部照片或 SVG 资源；灰色示意素材是 Figma 中的基本图形，使用 SwiftUI 圆角形状实现。

## 验证

```sh
swift test
bash scripts/test-ios.sh
```

核心测试涵盖保存与重新加载、草稿、空内容校验、音频记录、去重更新、损坏文件保留和素材路径边界。UI 测试覆盖输入→新建标签→保存→重启、草稿恢复/放弃、Figma 示例与弹层，并保存截图到 `.xcresult`。GitHub Actions 运行同一套测试并提供模拟器构建产物。

`ThoughtMosaic.xcodeproj` 已提交，无需安装 XcodeGen。添加 Swift 源文件后运行 `python3 scripts/generate_project.py` 更新工程。

## 目录

- `ThoughtMosaic/` — SwiftUI 页面、相机、录音、状态管理
- `ThoughtMosaicWidget/` — 桌面与锁屏组件
- `Sources/MosaicCore/` — 数据模型与原子文件持久化
- `Tests/`、`ThoughtMosaicUITests/` — 核心与交互测试
- `scripts/` — 工程生成、环境诊断、模拟器运行与测试

设计参考节点：记录 `36:771` / `36:1291`，标签 `36:1500`，录音 `36:1567`，退出 `36:1606`，保存 `36:1650`，组件 `36:908`。
