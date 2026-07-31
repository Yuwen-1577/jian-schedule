# 简课表 Android 发布检查清单

## 代码与版本

- [ ] 从最新 `master` 创建 `codex/` 分支，确认没有混入 `AGENTS.md`、签名文件、APK、真实网页或其他无关文件。
- [ ] `pubspec.yaml` 的版本名和构建号均已递增。
- [ ] README 的功能说明、APK 路径、升级说明和更新日志已同步。
- [ ] `flutter pub get`、`flutter analyze`、`flutter test` 全部通过。
- [ ] GitHub Actions 在目标提交上通过。

## Android 构建与安全

- [ ] 使用 JDK 17 和项目要求的 Android SDK 构建正式 APK。
- [ ] Release 构建使用当前正式签名，不使用 Debug 签名。
- [ ] 核对包名、版本名、版本号、签名证书指纹和 APK SHA-256。
- [ ] Release 清单不允许 HTTP 明文流量，Debug 的 HTTP 警告逻辑仍有效。
- [ ] 仓库、日志和构建输出中不包含账号、Cookie、原始 HTML、完整教务网址或签名密码。

## 模拟器验收

- [ ] 在 MuMu 中从上一个正式版本覆盖安装，原有课表集、课程、学期日期和节次时间均保留。
- [ ] JSON 备份可通过系统文件界面保存到 Download，并能通过普通文件选择器恢复。
- [ ] 用户手动登录真实强智系统，完成预览、仅新增、重复跳过和必要的替换隔离验证。
- [ ] 安全结构报告与深度脱敏页面均可保存，人工检查不包含敏感值。
- [ ] 退出教务导入页后，网址、Cookie、HTML 和登录状态没有持久化。
- [ ] 验收结束后关闭 ADB root，并清理临时数据库、截图和诊断文件。

## GitHub 发布

- [ ] 修复分支已推送并快进合入 `master`，没有强制推送或改写历史。
- [ ] 正式标签指向通过验收的 `master` 提交。
- [ ] Release 标题、说明、兼容性警告、APK 名称和摘要正确。
- [ ] 新版本设为 Latest；上一版本的标签、Release 和附件按计划保留。
- [ ] 签名备份目录已记录提交、标签、Release URL、证书指纹、APK SHA-256 和验收结果。
