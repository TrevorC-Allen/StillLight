# StillLight

中文文档 | [English](README.md)

StillLight 是一个 iOS-only 的胶片相机 MVP，使用 SwiftUI、AVFoundation、CoreImage
和 Photos 构建。它面向作品集展示：不是普通滤镜 App，而是一个能真实拍摄、能批量冲洗、
能讲清楚图像管线的个人胶片暗房。

```text
选择胶卷
-> 用自定义相机拍摄，或把已有照片放进暗房
-> 通过胶片管线冲洗
-> 保存到本地胶卷和系统照片
-> 浏览、对比和分享成片
```

## 产品重点

- 原生相机体验：实时预览、点按对焦 / 测光、曝光补偿、闪光灯、镜头变焦按钮、触感、
  网格线、水平仪和比例取景框。
- Dazz-like 相机库：27 个原创胶片 / 机型风格以独立相机 profile 呈现，每个风格都有
  独立相机名、机身形态、镜头年代、附件标签、样张方向和渲染参数。
- 当前主推方向：
  - `Human Warm 400`：人文、咖啡馆、室内和街头日常。
  - `Shadow Walk 800`：街道、展馆、建筑和更强暗角氛围。
  - `Soft Muse 400`：柔和人像、暖肤色、轻抬阴影和稳定高光。
- 真实样张方向：作品集验收应使用真实 iPhone 样张，覆盖咖啡馆 / 室内、人像窗边光、
  夜间街道、博物馆、建筑走廊、拍立得桌面和 CCD 校园 / 日光场景；胶卷缩略图要让用户
  先看到成片氛围，而不是只看到数字和图标。
- 中文文档模式：`README.zh-CN.md` 和 `docs/zh-CN/` 面向演示、面试讲解和后续维护，
  以中文说明 MVP 范围、架构、胶卷、性能、真机运行、AI 推荐和演示脚本。

## 技术亮点

StillLight 的出片不是单纯套 LUT。每个胶卷都会驱动一套确定性的胶片渲染管线：

```text
拍摄 JPEG / 导入图片
-> 方向修正、降采样或归一化
-> 3200px 高质量处理路径
-> 按比例中心裁切
-> 曝光、色温、Tint、对比度、饱和度
-> Tone Curve
-> 高光 / 阴影调整
-> Film Rendering Profile
-> Tone Separation 和胶卷色彩响应
-> 高光遮罩暖色 Halation
-> 柔和径向镜头落光
-> 稳定 seed 漏光
-> 带肤色保护的亮度相关颗粒和 finishing texture
-> 日期戳、纸框 / 拍立得 / 白框和机型标注
-> JPEG 导出并写入 StillLight 胶片元数据
```

录像导出复用同一套管线中适合逐帧运行的 Core Image 阶段：曝光、白平衡、曲线、
局部渲染、色彩响应、halation、暗角和漏光会通过 `AVVideoComposition` 作用到视频帧，
再保存到本地和系统照片。

作品集讲解重点：

- `Film Rendering Profile`：用局部微对比、中间调柔化、高光恢复和肤色保护，让胶卷像
  被“渲染”出来，而不是只改变色相。
- `Tone Separation`：阴影、中间调和高光在颜色、反差和保护策略上分开处理，再进入颗粒、
  边框和机型标注。
- 相机拍摄、Import Lab 和录像导出共用胶片响应阶段，保证直拍、导入冲洗和视频的风格一致。
- Import Lab 会显示总耗时、输入 / 输出像素和阶段耗时，便于 QA 和性能讲解。

## MVP 范围

- AVFoundation 拍照和原生录像，录像支持音频、计时、胶片调色导出和保存到系统照片。
- 拍摄页相机附件：双重曝光带第一张预览和混合模式，长曝光带多帧进度和时长档位，
  星芒强度滑杆，Kelvin 色温、闪光灯、自拍计时、暗房导入入口和前后摄像头切换。
- 前后摄像头、闪光灯 off / on / auto、曝光补偿、点按对焦 / 测光和对焦动画。
- 类原生变焦：捏合缩放，多摄 iPhone 上显示 0.5x / 1x / 3x 等镜头按钮。
- 比例：3:2、4:3、1:1、16:9、Half。
- 拍照后不强制弹结果页，只更新左下角最近照片缩略图。
- 胶卷剩余张数、本地 JSON 照片记录、相册详情左右滑动，以及不干扰翻页的长按原图对比。
- Import Lab 支持多图导入、冲洗当前 / 全部、取消批量、失败重试、保存当前 / 全部。
- 本地可解释 Top 3 胶卷推荐：基于亮度、颜色、冷暖和反差。
- 中文 / 英文 UI 切换、分享、可选保存原图。

## 胶卷库

当前胶卷库包含 27 个原创预设，覆盖 featured、portrait、color negative、classic
camera、instant、black-and-white、digital 和 experimental。代表胶卷包括：

- Human Warm 400
- Shadow Walk 800
- Soft Muse 400
- Sunlit Gold 200
- Soft Portrait 400
- Silver HP5
- Green Street 400
- Tungsten 800
- Pocket Flash
- CCD 2003
- Instant Square
- HNCS Natural
- M Rangefinder Color
- GR Street Snap
- Medium 500C
- Instant Wide
- Half Frame Diary

完整预设表、胶卷物件映射和真实样张验收方向见 `docs/zh-CN/PRESETS.md`。

## 验收清单

MVP 验收：

- `scripts/build_unsigned.sh` 编译通过。
- 真机打开相机预览，点按对焦 / 测光、变焦、曝光和拍摄都能响应。
- 拍照后生成经过胶片管线处理的成片，并更新最近照片缩略图。
- 切换胶卷会改变图像渲染和边框 / 机型标注。
- `Human Warm 400`、`Shadow Walk 800`、`Soft Muse 400` 用真实咖啡 / 室内、
  街道 / 展馆、人像样张完成验收。
- 使用任意胶卷录制一段短视频，导出后应带同胶卷色彩响应，并且“视频已保存到照片”
  提示会自动消失。
- Import Lab 能处理多张导入照片，支持取消、失败重试、保存当前和保存全部。
- 成片先保存到本地胶卷，Photos 权限允许时再导出到系统照片，并写入 JPEG 胶片元数据。
- 中文文档模式可从 `README.zh-CN.md` 和 `docs/zh-CN/README.md` 顺畅进入。

下一步验收：

- 为三个主推胶卷加入真实 3D LUT / `CIColorCube` 素材，并和当前程序化 profile 对比。
- 将预览安全的 tone、颗粒、暗角阶段迁移到 Metal，服务实时取景。
- 在真机上量化录像导出耗时后，为视频增加帧安全的颗粒和可选日期戳。
- 有足够真实样张后，用 Vision / CoreML 场景标签替代当前启发式推荐。
- 支持用户用 5-10 张参考图生成个人自定义胶卷。

## 项目结构

```text
StillLight/
├── StillLight.xcodeproj
├── StillLight/
│   ├── App/              # App 入口、根 Tab、全局状态和语言
│   ├── Camera/           # AVFoundation 相机、预览、拍摄 UI、录像
│   ├── Film/             # 胶卷预设、胶卷库、胶卷选择器
│   ├── ImagePipeline/    # CoreImage + 颗粒 + 日期戳 + 边框
│   ├── Export/           # 图片 / 视频导出、本地文件和 Photos 保存
│   ├── Gallery/          # 本地胶卷记录、照片详情
│   ├── ImportLab/        # 多图导入暗房
│   ├── AI/               # 本地胶卷推荐启发式
│   ├── Settings/         # 设置页
│   ├── UI/               # 共享 UI
│   └── Supporting/       # Info.plist 和权限说明
├── docs/
│   ├── zh-CN/            # 中文文档模式
│   ├── DEVICE_RUNBOOK.md
│   ├── IOS_ARCHITECTURE.md
│   ├── MVP.md
│   └── PRESETS.md
└── scripts/
    ├── build_unsigned.sh
    ├── check_ios_device.sh
    └── run_on_iphone.sh
```

## 构建和运行

用 Xcode 打开 `StillLight.xcodeproj`，选择真实 iPhone 运行 `StillLight` target。

命令行编译检查：

```sh
scripts/build_unsigned.sh
```

真机检查：

```sh
scripts/check_ios_device.sh
```

签名和信任完成后，可以直接安装并启动：

```sh
scripts/run_on_iphone.sh
```

如果连接了多台设备：

```sh
scripts/run_on_iphone.sh YOUR_DEVICE_ID
```
