# iOS Mac 云端编译说明（游客登录 + 房间人数 + 商城）

## 为什么必须 Mac 编译

Linux 服务器上对 iOS 字节码做**变长补丁**（插字节、改 proto 长度）会导致真机**闪退**。  
安卓端已改好的 `LoginScene` / `HFCreateRoomLayer` **不能**直接拷进 `pyq64.zip`（架构标志不同也会闪退）。

必须在 **GitHub Actions macOS** 或真 Mac 上，用 `luajit -bg` 从 **.lua 源码** 编译出第 5 字节为 `0x08` 的模块。

## 你需要准备的源码（从 client_qqdbl 工程）

从原工程路径（字节码里可见）：

```
/Users/conglinwen/Documents/jenkins/client_qqdbl/...
```

复制以下文件到本仓库 `client/` 目录（文件名必须一致）：

| 文件 | zip 内模块名 | 安卓已做修改 |
|------|-------------|-------------|
| `LoginScene.lua` | `app.scenes.LoginScene` | 游客登录、左右按钮、隐藏协议条 |
| `HFCreateRoomLayer.lua` | `app.module.lobby.view.createRoom.HFCreateRoomLayer` | 人数 2/4/6/7/8 |
| `CreateRoomLayer_Sss.lua` | `app.module.lobby.view.createRoom.CreateRoomLayer_Sss` | 人数 2/4/6/7/8 |
| `LbShopLayer.lua` | `app.module.lobby.view.layer.LbShopLayer` | 六档商城（可选） |

## LoginScene.lua 需改的 Lua 逻辑（参考安卓效果）

1. **显示快速游戏按钮**：`btnFastLogin:setVisible(true)`
2. **横排布局**（`setLoginBtn` 或 ctor 里）：
   - 左：快速游戏 `cx - 250`
   - 右：微信登录 `cx + 250`
3. **保持隐藏**：`loadView`、`tipDialogView` 初始 `setVisible(false)`
4. **协议**：`checkBoxState = "on"`（可隐藏底部协议 UI）

## HFCreateRoomLayer.lua 需改

将玩家人数下拉从 `{6,7,8}` 改为 `{2,4,6,7,8}`（共 3 处 chioce 表，与安卓一致）。

## GitHub Actions 步骤

1. 上传本目录到 GitHub 仓库
2. 把 `client/*.lua` 源码放进仓库
3. Actions → **iOS final sync (Mac compile)** → Run workflow
4. 下载 Artifact `pyq64-ios-final`
5. 替换 `Payload/奇趣大菠萝.app/res/pyq64.zip` 与 `res/pyq64/` 目录
6. 重签名 IPA 安装

## 本地 Mac 验证（编完必做）

```bash
xxd -l 6 build/LoginScene
# 期望：1b 4c 4a 02 08 ...

luajit -bl build/LoginScene | head
# 不能报 incompatible bytecode

python3 tools/validate_pyq64_ios.py dist/pyq64.zip
```

## 当前服务器安全底包

`base/pyq64_base.zip` 为**未改游客登录/人数**的 iOS 原生包，可正常进游戏，避免闪退。
