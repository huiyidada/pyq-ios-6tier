# 奇趣大菠萝 · iOS 6 档商城云端编译（GitHub Actions）

无需 Mac、无需 Cursor。在 GitHub 免费 macOS 虚拟机上编译 **与安卓一致** 的 6 档钻石商城 + H5 收银台 `mallPayCashier`。

---

## 一、你要准备什么

1. **GitHub 账号**（免费注册 https://github.com/signup ）
2. 能上网的电脑（Windows / 老 Mac / 手机浏览器都行）
3. 本文件夹全部内容（或下载 `ios-github-build.tar.gz`）

---

## 二、第一次使用（约 10 分钟）

### 步骤 1：在 GitHub 新建仓库

1. 登录 GitHub → 右上角 **+** → **New repository**
2. 仓库名建议：`pyq-ios-6tier`（任意英文名即可）
3. 选 **Private** 或 Public 均可
4. **不要**勾选 “Add a README”（我们本地已有）
5. 点 **Create repository**

### 步骤 2：把本文件夹推上去

在 **你自己的电脑** 上（已解压 `ios-github-build` 后）打开终端，执行：

```bash
cd ios-github-build

git init
git add .
git commit -m "init iOS 6-tier cloud build"
git branch -M main
git remote add origin https://github.com/你的用户名/pyq-ios-6tier.git
git push -u origin main
```

> 推送时 GitHub 会要求登录；按提示用浏览器授权或 Personal Access Token 即可。

**不会 git？** 也可用 GitHub 网页 **Upload files**，把本目录下所有文件（含 `.github` 隐藏文件夹）拖进去上传。

### 步骤 3：运行云端编译

1. 打开你的仓库页面
2. 点顶部 **Actions**
3. 左侧选 **iOS 6-tier LbShopLayer**
4. 右侧 **Run workflow** → 分支选 `main` → **Run workflow**
5. 等约 **5～15 分钟**（黄点变绿勾）

### 步骤 4：下载编译结果

1. 点进刚跑完的那次 workflow
2. 页面底部 **Artifacts** → 下载 **pyq64-ios-6tier**（zip）
3. 解压后得到：
   - `pyq64.zip` ← **打进 IPA 用这个**
   - `app.module.lobby.view.layer.LbShopLayer` ← 单模块备份
   - `build_report.txt` ← 验证报告（发助手排查用）

---

## 三、装进 iOS 包（重签名前）

把下载的 `pyq64.zip` 替换进：

```
Payload/奇趣大菠萝.app/res/pyq64.zip
```

然后按你平时的方式 **重签名** 安装（企业签 / 超级签 / Xcode 等）。

### 自测清单

| 步骤 | 预期 |
|------|------|
| 冷启动 | 不闪退 |
| 登录 | 连 `12345.nikyou.cn` |
| 大厅 | 显示钻石（goldNum） |
| 打开商城 | **6 个钻石档位**横排 |
| 点档位 | 浏览器打开 `mallPayCashier.html` |

---

## 四、改商城逻辑后重新编译

只需改 `client/LbShopLayer.lua`，然后：

```bash
git add client/LbShopLayer.lua
git commit -m "update shop"
git push
```

推送后会 **自动** 再跑一遍 Actions；或到 Actions 页手动 **Run workflow**。

---

## 五、发回助手继续改时请带

1. `build_report.txt` 全文
2. `pyq64.zip` 或整个 `Payload`
3. 安装后现象（闪退时机 / 商城几档 / 能否打开 H5）

---

## 六、仓库目录说明

```
ios-github-build/
├── .github/workflows/ios-lbshop-6tier.yml  # 云端 Mac 流水线
├── client/LbShopLayer.lua                  # 6 档商城源码（与安卓一致）
├── base/pyq64_base.zip                     # iOS 原生底包（LbShopLayer 7143 字节）
├── scripts/
│   ├── build_luajit_ios.sh                 # 编 iOS 版 LuaJIT
│   └── compile_and_pack.sh                 # 编译 + 打 pyq64
└── tools/
    ├── pack_ios_lbshop.py                  # 替换模块 + 鉴权/钻石补丁
    └── validate_pyq64_ios.py               # 校验 0x08 字节码
```

---

## 七、常见问题

**Q：Actions 是红的失败了？**  
点进失败任务看日志。把 `build_report.txt` 或日志末尾发助手。

**Q：没有 Mac 能装包吗？**  
编译不需要 Mac；**重签名安装**仍要你自己的签名渠道（爱思、企业证书等）。

**Q：和安卓 UI 一样吗？**  
源码 `LbShopLayer.lua` 与服务器 `pay-integration/client/` 中安卓版一致：6 档 + `mallPayCashier` H5。

**Q：免费吗？**  
GitHub 公开仓库 Actions 有免费额度；私有仓库每月也有限额，一般够用。
