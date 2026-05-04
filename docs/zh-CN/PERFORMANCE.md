# StillLight 图像处理性能记录

StillLight 当前把性能记录放在图像处理管线旁边，而不是散落在 UI 调用侧。目标是让作品集讲解能说清楚“测了什么、为什么这样测、下一步怎么优化”，同时保持实现轻量。

## 当前策略

- 输入降采样：相机照片和导入照片进入管线前会限制最长边为 2400px，避免直接把完整传感器照片送进滤镜、颗粒和边框绘制。
- 逐张批处理：暗房导入仍按单张照片依次冲洗，进度、取消和失败重试交给 ImportLab 工作流处理，图像管线只负责一张图的确定性输出。
- Core Image 主链路：裁切、曝光、色温、颜色控制、曲线、Halation、暗角、漏光和强度混合仍走 Core Image，并在 `CIContext.createCGImage` 时发生主要渲染同步。
- CPU 收尾：颗粒目前在 `CGImage` 像素缓冲上生成，边框和日期戳使用 `UIGraphicsImageRenderer` 绘制。这是当前最清晰的 CPU/GPU 边界。

## 记录能力

现有 API 保持不变：

```swift
let image = try FilmImagePipeline.process(...)
```

需要记录时使用可选入口：

```swift
let result = try FilmImagePipeline.processWithTiming(...)
let image = result.image
let timing = result.timing
```

`ProcessingTiming` 会记录：

- `maxInputPixelSize`：当前降采样上限，默认为 2400。
- `inputPixelSize`：进入滤镜链路的像素尺寸。
- `croppedPixelSize`：按拍摄比例裁切后的像素尺寸。
- `outputPixelSize`：加颗粒、边框和日期戳后的像素尺寸。
- `stages`：各阶段耗时，单位毫秒。
- `totalMilliseconds`：所有记录阶段的合计耗时。

当前阶段名称：

- `downsample` 或 `normalize`
- `crop`
- `coreImageRender`
- `grain`
- `decorate`

时间测量使用 Swift 标准库 `ContinuousClock`，没有引入第三方依赖，也没有默认写日志。

暗房当前已经接入这个 timing 入口：用户冲洗当前照片或批量冲洗后，选中已有成片的照片时，会看到一个克制的“处理耗时”摘要，包括总耗时、输入 / 输出像素，以及 `normalize`、`crop`、`coreImageRender`、`grain`、`decorate` 等阶段耗时。相机拍照路径仍保持普通直出体验，不显示性能信息。

## 如何测试

建议用同一台真机、同一组照片做三轮记录：

1. 选择 5-10 张代表性照片：日光、夜景、高 ISO、人物、复杂纹理各至少一张。
2. 固定胶卷预设、画幅比例、时间戳开关和强度，避免把参数变化混入性能波动。
3. 首张作为预热样本，后续样本可直接在暗房“处理耗时”摘要里记录 `totalMilliseconds` 和各 `stage.milliseconds`。
4. 分别记录相机 `photoData` 输入和相册 `UIImage` 输入，因为前者有 `downsample`，后者有 `normalize`。
5. 对比 `coreImageRender`、`grain`、`decorate` 占比，判断优化优先级。

记录时建议保留设备型号、系统版本、照片原始分辨率、降采样后分辨率和胶卷预设名称。作品集里不需要追求实验室级 benchmark，但需要保证样本、设备和参数可复现。

## 后续 Metal 路线

- 实时预览：把预览链路迁移到 Metal 或 Metal-backed Core Image，优先服务取景器实时反馈。
- 颗粒 GPU 化：当前颗粒是最明显的 CPU 像素循环候选，可用 Metal kernel 或噪声纹理混合替代。
- LUT / 曲线合并：把部分颜色变换合并，减少滤镜链路中的中间图像和渲染开销。
- 批处理调度：暗房批量冲洗可继续保持逐张输出，但在后台任务、内存水位和取消响应之间做更细的调度。
- 性能基线：在 Metal 改造前固定一组照片和预设，保留 Core Image 版本的耗时表，作为优化前后对照。
