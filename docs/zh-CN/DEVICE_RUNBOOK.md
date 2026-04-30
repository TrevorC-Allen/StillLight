# iPhone 真机运行手册

StillLight 已经可以走真实 iPhone 调试流程。机器相关的关键点是 Apple 账号、签名证书、设备信任和 Developer Mode。

## 1. 检查本机环境

在仓库根目录运行：

```sh
scripts/check_ios_device.sh
```

脚本会检查：

- Xcode 版本
- 是否检测到真实 iPhone / iPad
- `devicectl` 是否能看到设备
- Apple Development 签名身份
- iPhone SDK 无签名编译是否通过

如果没有检测到设备，请用 USB 连接 iPhone，解锁手机，并在手机上点击“信任此电脑”。

## 2. 在 Xcode 中配置签名

1. 打开 `StillLight.xcodeproj`。
2. 打开 Xcode 设置里的 Accounts，添加 Apple ID。
3. 选择 StillLight target。
4. 打开 Signing & Capabilities。
5. 勾选 Automatically manage signing。
6. 选择个人或付费 Apple Developer Team。
7. Bundle Identifier 当前是 `com.trevorcui.StillLight`，如果 Xcode 提示冲突，可以改成自己的唯一 ID。

免费 Apple ID 也可以安装到自己的设备，但证书有效期会更短。

## 3. 用 Xcode 跑到 iPhone

1. 在 Xcode 顶部设备菜单选择连接的 iPhone。
2. 点击 Run。
3. 第一次安装后，iOS 可能要求信任开发者：
   `设置 -> 通用 -> VPN 与设备管理`。
4. 打开 StillLight 后允许相机、麦克风和照片权限。

## 4. 用命令行安装并启动

签名和设备信任完成后：

```sh
scripts/run_on_iphone.sh
```

如果连接了多台设备，传入设备 ID：

```sh
scripts/run_on_iphone.sh YOUR_DEVICE_ID
```

如果提示 Developer Mode 没开：

1. 打开 iPhone 设置。
2. 进入 `隐私与安全性`。
3. 打开 `开发者模式`。
4. 按提示重启手机。
5. 重启后解锁并确认开发者模式。
6. 再运行 `scripts/run_on_iphone.sh`。

## 5. 当前冒烟测试

在手机上依次检查：

1. 打开 StillLight。
2. 选择一个胶卷。
3. 拍照。
4. 确认冲洗预览出现。
5. 保存到系统照片。
6. 打开胶卷 / 相册页，确认本地记录出现。
7. 切到录像模式，录一段短视频并确认保存。
8. 打开暗房，一次选择多张照片。
9. 使用冲洗全部。
10. 使用保存全部。

## 常见问题

### 只能编译，不能安装

仓库可以通过以下命令无签名编译：

```sh
scripts/build_unsigned.sh
```

但真机安装必须有：

- 已连接并信任的 iPhone
- Xcode Accounts 里可用的 Apple Development 签名身份

### 设备锁屏导致启动失败

解锁 iPhone，再重新运行：

```sh
scripts/run_on_iphone.sh
```

### App 图标相关

仓库里准备了 App Icon 资源。当前 MVP 重点是相机功能和真机运行，如果本机 Xcode 缺 iOS simulator runtime，资产编译可能会受影响。需要时可在 `Xcode -> Settings -> Components` 安装 iOS runtime。
