## sky-tv

sky-tv 是一个现代化跨平台视频播放器空壳应用，支持导入用户自己的影视源和 IPTV 直播源，用于搜索、分类、播放、收藏和继续观看。


### 演示截图
<details>
  <summary>点击预览截图</summary>

<div style="display:inline-block">
<img src="docs/img/1.jpg" alt="demo1" width="230">
<img src="docs/img/2.jpg" alt="demo2" width="230">
<img src="docs/img/3.jpg" alt="demo3" width="230">
</div>

</details>

### 声明

sky-tv 只是个空壳播放器：

- 不内置任何影视、直播、频道、节目单或解析服务。
- 不提供任何视频内容、下载内容或版权资源。
- 项目开发者不对用户的使用行为承担任何法律责任。
- 用户应在遵守其所在国家或地区法律法规的前提下使用本软件。
- 本项目是基于技术学习和交流为目开发的开源软件。

## 主要功能

- 影视源订阅导入，支持 maccms V10 常见接口与 drpy-node（DS/T4）接口。
- 可直接导入 TVBox 配置：`sites` 转为影视源，`lives` 转为 IPTV 订阅。
- IPTV 订阅导入，支持 M3U、M3U8、TXT 和 JSON 订阅。
- 视频搜索、分类浏览、详情页、选集播放。
- 直播频道分组、搜索、播放和换台。
- 收藏、观看历史、继续观看。
- 自定义 User-Agent 请求头。
- 浅色、深色和跟随系统主题。
- Android、iOS、Windows、macOS、Linux 多平台支持。

## 订阅格式

影视源 JSON 示例：

```json
[
  {
    "name": "示例影视源1",
    "api_url": "https://example.com/api.php/provide/vod"
  },
  {
    "name": "示例影视源2",
    "api_url": "https://example.com/api.php/provide/vod"
  },
  {
    "name": "示例影视源3",
    "api_url": "https://example.com/api.php/provide/vod"
  }
]
```

IPTV JSON 示例：

```json
{
  "iptv": [
    {
      "name": "示例直播源1",
      "url": "https://example.com/live.m3u"
    },
    {
      "name": "示例直播源2",
      "url": "https://example.com/live.m3u8"
    },
    {
      "name": "示例直播源3",
      "url": "https://example.com/live.txt"
    }
  ]
}
```

IPTV 也可以直接导入公开 M3U、M3U8 或 TXT 订阅地址。

DS 源（drpy-node / T4）也可以直接填写接口地址，例如
`http://192.168.1.10:5757/api/我的源?pwd=xxx`：规则由服务端执行，
播放地址在播放时由服务端解析。TVBox 配置（含 `sites`、`lives`、`parses`）可整段粘贴导入，
其中 `parses` 会作为第三方解析服务保存，用于播放需要解析的线路。

## 本地运行

```bash
flutter pub get
flutter run
```
