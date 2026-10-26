# Thought Mosaic · iOS 与浏览器 Demo

[打开浏览器 Demo](https://thought-mosaic-demo.fastlime130.chatgpt.site) · Windows、Mac 和手机均可使用，无需安装。源代码与本地启动说明见 [`web/README.md`](web/README.md)。记录保存在访问者自己的浏览器中，不与 iOS 数据或其他测试者同步。

依据 [Group05 Figma 原型](https://www.figma.com/design/Pjx45Twyn7aJrEpjT4hqSE/Group05?node-id=35-716) 实现的 SwiftUI 原生 iOS 灵感记录应用。最低 iOS 17，无第三方运行依赖，无后端账号。

## 运行

1. 安装完整 Xcode，并在 **Xcode → Settings → Components** 安装一个 iOS Simulator runtime。
2. 打开 `ThoughtMosaic.xcodeproj`，选择 `ThoughtMosaic` scheme 和任意 iPhone 模拟器，按 `⌘R`。
3. 真机运行时，在 app、widget 与 share 三个 target 的 **Signing & Capabilities** 中选择自己的 Team，并使用自己可用的 Bundle ID（widget ID 需以 app ID 加 `.` 开头）。模拟器不需要 Apple Developer 付费会员。

命令行构建、安装到可用模拟器：

```sh
bash scripts/run-simulator.sh
```

Xcode 27 的模拟器窗口位于 **Xcode → Open Developer Tool → Device Hub**。使用 Mac 键盘时，打开窗口顶部的 **Capture Keyboard** 后，再点击 App 输入区；长按 Esc 可以退出键盘捕获。App 输入区提供“完成输入”，键盘上方也有“收起键盘”按钮。

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

## 四种快捷唤醒怎么用

浏览器：点击[打开四方案体验](https://thought-mosaic-demo.fastlime130.chatgpt.site/?entry=a1)，可切换 A1 / A2 / B / C。iOS：退出当前记录页，在灵感库点击“快捷唤醒体验 · A1 / A2 / B / C”。

- **A1**：浏览场景点“模拟截图”，再点“记录灵感”，截图会自动带入编辑器。
- **A2**：点“拍照记录”组件，拍下示例画面；真机也可以打开系统相机。
- **B**：在灰色区域三指上滑。浏览器桌面端可鼠标向上拖；模拟器可点“模拟三指上滑”。
- **C**：点 TM 图标，进入空白记录页。

四个方案都接到同一个可输入、加标签和保存的记录流程。

### 真机系统入口

- **截图分享**：截图 → 打开预览 → 分享 → Thought Mosaic → 写想法/标签 → 保存。随后打开主 App，记录会自动进入灵感库。首次找不到时，在分享列表的“更多”中启用。分享扩展不会强行跳转主 App。
- **桌面组件**：长按桌面 → 编辑/添加小组件 → Thought Mosaic → 添加。点击“拍照记录”打开相机。
- **快捷指令**：App 内“快捷入口使用说明”可打开系统快捷指令；也可在“快捷指令”中搜索 Thought Mosaic，选择“记录灵感”“拍照记录”“导入截图”。
- **轻点背面**：保存一个上述快捷指令后，设置 → 辅助功能 → 触控 → 轻点背面 → 轻点两下/三下 → 选择快捷指令。支持操作按钮的 iPhone 也能在设置中绑定同一快捷指令。
- **URL 兼容入口**：若系统索引尚未完成，在快捷指令中使用“URL”+“打开 URL”，填写 `thoughtmosaic://direct`、`thoughtmosaic://camera` 或 `thoughtmosaic://screenshot`。

分享扩展与主 App 使用同一 App Group：`group.com.mosnagant.thoughtmosaic`。真机签名时，为 **ThoughtMosaic 与 ThoughtMosaicShare** 选择同一开发团队，并在两个 target 启用该 App Group。若使用自己的 Group ID，同时更新两个 entitlements 文件与 `MosaicShareInbox.appGroup`。App Group 能力需要支持该能力的开发团队；模拟器可直接运行。

## iOS 与原型的对应

| 原型 | 实现 |
| --- | --- |
| 直接打开 App | 启动进入空白记录页，存在草稿则恢复 |
| 拍照组件 | WidgetKit 桌面组件 → URL scheme → 相机 |
| 截图后记录 | 原型完整浮窗演示；真机使用 Share Extension 或相册导入，不修改系统截图浮窗 |
| 三指上滑 | 演示区识别三指上滑；真机跨 App 唤醒使用 App Shortcuts、轻点背面或操作按钮 |
| 黑白灰视觉 | 保留主色、卡片、按钮和标签层级；采用用户确认的 iOS 系统字体与 Dynamic Type |
| 设备外框与模拟状态栏 | 由真实 iPhone / 模拟器系统提供，不绘制在 App 内 |

标签使用原生 sheet，相机与相册使用系统界面；界面适应安全区、键盘、小屏与文字缩放。原图没有外部照片或 SVG 资源；灰色示意素材是 Figma 中的基本图形，使用 SwiftUI 圆角形状实现。

## 验证

```sh
swift test
bash scripts/test-ios.sh
```

另外已在独立模拟器通过系统分享面板实际发送 UIImage，验证分享扩展接收、保存、主 App 冷启动导入和重新编辑。当前 iOS 27.1 模拟器未提供“快捷指令”系统 App；三个 App Shortcut 的动作元数据与中英文唤醒语料已成功生成，轻点背面/操作按钮仍需在支持的真机上配置与验证。

分享收件箱测试覆盖图片迁移、保留已有记录/草稿、幂等导入、损坏项保留与失败重试。UI 测试还覆盖四个入口逐一进入编辑器并保存。

核心测试涵盖保存与重新加载、草稿、空内容校验、音频记录、去重更新、损坏文件保留和素材路径边界。UI 测试覆盖输入→新建标签→保存→重启、键盘收起、取消退出后继续输入、长文本、草稿恢复/放弃/清空、标签取消与 Figma 示例，并保存截图到 `.xcresult`。每个 UI 用例使用独立 UUID 测试目录，重启复用同一目录验证持久化，不重置正式记录。GitHub Actions 运行同一套测试并提供模拟器构建产物。

`ThoughtMosaic.xcodeproj` 已提交，无需安装 XcodeGen。添加 Swift 源文件后运行 `python3 scripts/generate_project.py` 更新工程。

## 目录

- `web/` — 可静态托管的跨平台浏览器 Demo、说明与模型测试
- `ThoughtMosaic/` — SwiftUI 页面、相机、录音、状态管理
- `ThoughtMosaicWidget/` — 桌面与锁屏组件
- `ThoughtMosaicShare/` — 系统分享扩展，接收图片与文字
- `ThoughtMosaic/QuickCaptureIntents.swift` — 三个系统快捷指令与路由
- `Sources/MosaicCore/` — 数据模型与原子文件持久化
- `Tests/`、`ThoughtMosaicUITests/` — 核心与交互测试
- `scripts/` — 工程生成、环境诊断、模拟器运行与测试

设计参考节点：记录 `36:771` / `36:1291`，标签 `36:1500`，录音 `36:1567`，退出 `36:1606`，保存 `36:1650`，组件 `36:908`。
