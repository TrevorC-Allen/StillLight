# iOS 技术架构

StillLight 当前只做 iOS，目标是用原生能力把相机体验、图像处理、系统相册和作品集展示串成一个完整闭环。

## 技术栈

- SwiftUI：界面、导航、状态绑定
- AVFoundation：相机预览、对焦、曝光、拍照、录像、多摄虚拟设备和变焦
- CoreImage：MVP 胶片模拟管线
- Photos / PhotosUI：系统照片保存、多图选择
- CoreMotion：水平仪
- JSON Documents：MVP 阶段本地照片记录和胶卷状态
- UIKit：图片绘制、边框、日期戳、分享面板
- Metal：后续实时预览和 GPU 胶片效果

## 模块结构

```text
SwiftUI App
-> RootView
-> CameraScreen
-> CameraService
-> CameraViewModel
-> VideoExporter
-> FilmPreset / FilmLibrary / FilmRollStore
-> FilmImagePipeline
-> PhotoExporter
-> PhotoStore
-> GalleryScreen
-> ImportLabScreen
-> FilmRecommender
-> SettingsScreen
```

## 相机拍照链路

```text
AVCaptureSession
-> 优先选择三摄 / 双广角 / 双摄 / 广角设备
-> AVCaptureVideoPreviewLayer 实时预览
-> 点按对焦和曝光
-> 捏合缩放，以及可用时的 0.5x / 1x / 3x 镜头按钮
-> AVCapturePhotoOutput 拍照
-> 左下角最近照片缩略图，不自动弹窗
-> JPEG Data
-> FilmImagePipeline
-> PhotoExporter
-> PhotoStore
-> Photos
```

## 录像链路

```text
AVCaptureMovieFileOutput
-> 临时 .mov
-> Documents/StillLight/Videos
-> 尝试保存到系统照片
```

当前录像是稳定优先的原生视频。胶片视频需要实时渲染和编码链路，后续应放到 Metal / AVAssetWriter 路线中实现。

## 暗房链路

```text
PhotosPicker 多选
-> LabFrame 队列
-> 每张图生成本地推荐胶卷
-> 当前图预览和横向缩略图队列
-> 冲洗当前或冲洗全部
-> 保存当前或保存全部
-> PhotoExporter
-> PhotoStore
-> Photos
```

## 图像处理管线

```text
Input Image
-> orientation-aware downsample
-> center crop
-> exposure correction
-> temperature / tint
-> contrast / saturation
-> tone curve
-> halation
-> vignette
-> light leak
-> luminance-aware grain
-> timestamp
-> border
-> camera/model label
-> JPEG metadata
-> export
```

## 本地数据

- `PhotoRecord`：保存处理图路径、原图路径、胶卷 ID、胶卷名、比例、时间、尺寸、收藏状态
- `FilmRoll`：保存当前胶卷、总张数、已用张数、状态和时间
- 当前使用 JSON，是为了 MVP 速度快、易调试
- 后续可以迁移到 SwiftData 或 SQLite

## 性能策略

- 输入图片先降采样到可控尺寸
- CoreImage 负责大部分色彩和曲线处理
- 颗粒在 CPU 上做 MVP 版本
- 导出异步执行，避免阻塞 UI
- 批量暗房逐张处理，避免一次性占用过高内存
- 低端机后续可降低最大处理尺寸和颗粒强度

## 后续架构升级

- `CIColorCube` 加载 3D LUT
- Metal 实时预览
- Metal shader 实现颗粒、暗角、LUT、Halation
- AVAssetWriter 做胶片视频导出
- Vision / CoreML 做场景识别
- 自定义胶卷参数持久化
