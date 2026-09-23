# sky-tv 协作说明（AGENTS.md）

完整设计文档见 [`docs/docs.md`](docs/docs.md)：架构、数据流、业务边界、UI/性能规范、验收标准、禁止事项都在里面，**改代码前先读**。

## 项目定位

- Flutter 跨平台视频播放器：Android、Android TV（同一 APK）、Windows、macOS、iOS。
- 影视源两种协议：`maccms`（MacCMS V10 JSON，`api.php/provide/vod` 或 `/at/json`）与 `ds`（drpy-node 的 T4 接口 `/api/<名称>`）；直播支持 M3U/M3U8/TXT/JSON。
- 本仓库是 fork：`origin` = `xiaoheiwawa/sky-tv`，`upstream` = `sky22333/sky-tv`。改动统一提交到 `origin/main`。

## 本机环境（Windows）

- Flutter / Dart：`D:\temp\flutter\bin\flutter.bat`、`D:\temp\flutter\bin\dart.bat`（3.47.4 / Dart 3.13.3，与 CI 的 stable 一致）。
- Android SDK：`D:\temp\Android\Sdk`；JDK 17：`D:\temp\jdk17\jdk-17.0.20.1+1`。
- 新增环境一律装到 `D:\temp` 下（现有 `flutter`、`Android`、`jdk17`、`gradle-home`、`dotnet`、`nuget`、`keystore`、`apkchk`）：工具链、SDK、插件、包缓存都别装到 C 盘或仓库目录，仓库里只留源码和已入库文档。
- 命令前先设环境：

```powershell
$env:PUB_CACHE='C:\Users\Administrator\AppData\Local\Pub\Cache'
$env:GRADLE_USER_HOME='D:\temp\gradle-home'
$env:FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn'   # 不加镜像时 Gradle 拉引擎包会中断
```

- 访问 GitHub（推送/拉取）走本机代理：`-c http.proxy=http://127.0.0.1:10808 -c http.schannelCheckRevoke=false`；直连常见 `Connection was reset`。

## 常用命令

```powershell
D:\temp\flutter\bin\dart.bat format --set-exit-if-changed lib test
D:\temp\flutter\bin\flutter.bat analyze
D:\temp\flutter\bin\dart.bat test
D:\temp\flutter\bin\flutter.bat build apk --release --target-platform android-arm,android-arm64 --split-per-abi
```

- CI（`.github/workflows/release.yml` 的 `static-check`）就是上面三步，**改完必须三样全绿**。
- 联调探针：`dart run tool/probe_ds.dart [配置文件] [抽样站点数]`（首页/分类/详情/播放）、`dart run tool/probe_poster.dart [配置文件] [抽样数]`（海报缺失率）。

## 代码地图

| 位置 | 职责 |
| --- | --- |
| `lib/core/upstream/video_api.dart` | 上游请求（MacCMS / DS）+ 播放地址解析，`buildSourceUri` 负责拼 `pwd`/`extend`/动作参数 |
| `lib/core/upstream/parse_resolver.dart` | 第三方解析（jx）调用与 m3u8 嗅探 |
| `lib/core/parser/` | `source_importer`（导入 TVBox/自有格式）、`maccms_parser`、`play_url_parser`、`iptv_parser` |
| `lib/core/models/` | `video_source`、`source_kind`、`media_models`、`parse_rule`、`iptv_models` |
| `lib/data/repositories/` | `app_providers`（Riverpod 装配）、`media_repository`（首页/搜索/分类/详情/播放/缓存/观看记录） |
| `lib/features/` | `home`、`category`、`detail`、`search`、`player`、`live`、`settings`、`sources`（换源/局域网导入） |
| `lib/core/lan/lan_import_server.dart` | 局域网扫码导入 HTTP 服务（9978 起找端口，弹窗关闭即释放） |

## 约定

- 文档、注释、提交信息用中文；改动尽量小、跟随现有风格，别引入没必要的依赖。
- 上游字段只在 `lib/core/parser` 与 `lib/core/upstream` 里归一到 `lib/core/models`，页面不直接解析原始字段。
- 新增协议、导入格式或播放行为时，同步更新 `docs/docs.md`（该文件入库；`docs/开发记录.md` 是本机记录，已被 `.gitignore` 忽略）。
- 播放相关改动要保证：拿不到地址时报可读错误、不静默失败、能自动尝试同影片其他线路。

## 当前状态（2026-09-18）

- 网盘类 DS 源已修：详情缺 `vod_id` 时用请求 id 兜底（`MacCmsParser.parseDetail(fallbackId:)`）；`play` 返回的 `url` 支持 `[名称, 地址, ...]` 数组、去掉 `#isVideo=true#...` 尾巴、过滤 `127.0.0.1` 本机代理并带上服务端 `header`（百度直链需 `netdisk;...` UA）；当前线路失败自动换其他线路。
- 海报：`MediaRepository` 缓存列表海报并在详情缺封面时回退；`PosterImage` 按自定义 UA 下发请求头。
- 换源：全局 `current_source_id` + `SourcePicker`（搜索/列数切换/点击即切）；局域网扫码导入（AppBar 二维码入口）。
- TV：`AndroidManifest.xml` 已加 `touchscreen/leanback required=false`、`android:banner`、`LEANBACK_LAUNCHER`，`res/drawable-xhdpi/tv_banner.png` 为横幅，不需要单独出 TV 包。
- CI：`release.yml` 在缺少签名 Secrets 时只告警并改用 debug 签名出包（正式签名需配 `SIGNING_KEY_BASE64` / `KEY_ALIAS` / `KEY_STORE_PASSWORD` / `KEY_PASSWORD`）；跑工作流用 `workflow_dispatch` + tag。
- 已知不支持：`type 3`（cat / DR2 的 `.js` 规则，需客户端 JS 引擎与 drpy2/catvod 运行时，服务端无等价 `/api/` 接口）；网盘「需要账号解析」的线路（如 `{"parse":1,"jx":1}`）依赖 drpy 网盘 SDK，只能靠同影片直链线路。

## 安全

- 不要把密钥、口令、含 `pwd` 的第三方订阅地址写进仓库或文档。签名库 `android/app/release-key.p12`、其 base64 与口令均已 `.gitignore`，正式签名只经 GitHub Actions Secrets 下发。
