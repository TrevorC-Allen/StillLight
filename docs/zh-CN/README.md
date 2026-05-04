# StillLight 中文文档

这是 StillLight 的中文文档模式，面向作品集展示、面试讲解和后续开发维护。

## 文档入口

- [MVP 范围](MVP.md)
- [iOS 技术架构](IOS_ARCHITECTURE.md)
- [胶卷预设系统](PRESETS.md)
- [iPhone 真机运行手册](DEVICE_RUNBOOK.md)
- [中文演示脚本](DEMO_SCRIPT.md)
- [4 周开发路线](ROADMAP.md)

## 项目一句话

StillLight 是一个 iOS 胶片相机 App：用真实相机交互承载模块化胶片模拟管线，让用户可以拍完即直出，也可以把多张已有照片放进暗房统一冲洗。

## 当前版本重点

- 原生 iOS 相机体验
- 拍照直出
- 原生录像
- 27 个胶片 / 机型风格
- 多图导入暗房
- 胶片颗粒、暗角、漏光、Halation、边框和日期戳
- 中文 / 英文 UI
- 可讲清楚的图像处理 pipeline

## 面试讲解主线

```text
产品目标
-> 胶片不是滤镜，而是一套可解释的影像管线
-> iOS 原生相机和 Photos 工作流
-> CoreImage MVP 管线
-> 本地数据记录和导出
-> 暗房批量冲洗
-> 后续 Metal 实时预览和 AI 胶卷生成
```
