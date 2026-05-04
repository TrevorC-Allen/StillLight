# StillLight

中文文档 | [English](README.md)

StillLight 是一个 iOS-only 的个人作品级胶片相机 MVP，使用 SwiftUI、AVFoundation、CoreImage 和 Photos 框架构建。

它的目标不是做一个普通滤镜 App，而是做一个“数字时代的个人胶片暗房”：打开就能拍，拍完可直出，也可以把一组已有照片放进暗房批量冲洗。

## 当前闭环

```text
选择胶卷
-> 打开自定义相机拍摄
-> 通过模块化胶片管线冲洗
-> 保存到系统照片
-> 保留本地胶卷记录
```

## MVP 功能

- AVFoundation 实时相机预览
- 拍照、前后摄像头切换、闪光灯、曝光补偿、点按对焦
- 类原生相机变焦：支持捏合缩放，并在多摄 iPhone 上显示 0.5x / 1x / 3x 等镜头按钮
- 拍照后不自动弹出结果页，只更新左下角最近照片缩略图，用户点击后再查看
- 原生录像，支持麦克风、录制计时、保存到系统照片
- 网格线、水平仪、比例取景框
- 支持 3:2、4:3、1:1、16:9、Half 比例
- 胶卷剩余张数和本地胶卷记录
- 27 个可切换胶片 / 经典机型风格
- 主推场景卷：Human Warm 400、Shadow Walk 800、Soft Muse 400
- HNCS-inspired、旁轴街拍、GR 街拍、中画幅 500C、CCD、拍立得等风格
- 每个胶卷都有独立设计的封面视觉
- 白框、拍立得纸框、相纸边框，以及机型 / 胶卷标注
- 中文 / 英文 UI 切换
- 暗房支持一次导入多张照片
- 暗房支持冲洗当前 / 冲洗全部、取消批量冲洗、失败项重试、保存当前 / 保存全部
- 暗房冲洗后显示单张处理耗时、输入 / 输出像素和阶段耗时，方便作品集性能讲解
- 本地可解释胶卷推荐：根据亮度、饱和度、冷暖和反差生成 Top 3 候选
- 分享、相册、照片详情、长按原图对比

## 图像处理管线

```text
Captured JPEG / Imported Image
-> 方向修正和降采样
-> 按比例中心裁切
-> 曝光修正
-> 色温 / 色调偏移
-> 对比度 / 饱和度
-> Tone Curve
-> Halation
-> 暗角
-> 漏光
-> 亮度相关颗粒
-> 日期戳
-> 白框 / 相纸 / 拍立得边框
-> 机型和胶卷标注
-> JPEG 导出
-> 写入胶片元数据
-> 本地记录
-> 尝试保存到系统照片
```

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

## 中文文档

- [中文文档索引](docs/zh-CN/README.md)
- [MVP 范围](docs/zh-CN/MVP.md)
- [iOS 技术架构](docs/zh-CN/IOS_ARCHITECTURE.md)
- [胶卷预设系统](docs/zh-CN/PRESETS.md)
- [iPhone 真机运行手册](docs/zh-CN/DEVICE_RUNBOOK.md)
- [AI 胶卷推荐说明](docs/zh-CN/AI_RECOMMENDER.md)
- [中文演示脚本](docs/zh-CN/DEMO_SCRIPT.md)
- [4 周开发路线](docs/zh-CN/ROADMAP.md)

## 下一步

- 在暗房 UI 直接展示 Top 3 推荐候选
- 将 LUT、颗粒、暗角迁移到 Metal，支持实时预览
- 录像接入实时胶片效果
- 用 Vision / CoreML 替代当前启发式推荐
- 增加个人自定义胶卷生成
