# 癫影 (m.dian115.com) 中转网关接口文档

## 一、服务部署与网络信息

- **服务部署环境**：极空间 NAS（Z4 Pro）Docker 容器
- **局域网服务地址**：http://192.168.50.81:8924
- **Web 管理控制台**：http://192.168.50.81:8924/
- **宿主机代码路径**：/tmp/zfsv3/nvme12/17786467800a/data/docker/omnihubapi
- **容器名称**：omnihubapi-server
- **网络特性**：内建局域网代理出口转发（http://192.168.50.239:63322），底层采用真实 Chromium 浏览器内核常驻通信，已持久化登录态并完成 ECDSA P-256 动态签名与服务器时间对齐。

---

## 二、接口规范

### 1. 影视检索接口
- **请求方式**：GET
- **请求路径**：/api/search
- **请求参数**：
  - `q`（string，必填）：影视搜索关键词，如“都铎王朝”或“流浪地球”。
  - `page`（int，选填，默认 1）：页码。
- **返回字段**：
  - `query`：原始搜索词。
  - `page`：当前页码。
  - `total_results`：结果总数。
  - `results`（数组）：影视条目列表，包含：
    - `tmdb_id`（int）：TMDB 编号（查资源时必传）。
    - `title`（string）：中文标题。
    - `original_title`（string）：原名。
    - `year`（int）：上映年份。
    - `media_type`（string）：类型，电影为 `movie`，剧集为 `tv`。
    - `poster_url`（string）：海报图链接。
    - `backdrop_url`（string）：横幅剧照链接。
    - `vote_average`（float）：评分。
    - `overview`（string）：剧情简介。

### 2. 候选分享列表查询接口（核心展示）
- **请求方式**：GET
- **请求路径**：/api/media/shares
- **请求参数**：
  - `tmdb_id`（int，必填）：TMDB ID。
  - `media_type`（string，选填，默认 `movie`）：`movie` 或 `tv`。
  - `season`（int，选填）：剧集季数（例如第 1 季传 1，特别篇传 0；不传返回全季度相关分享）。
- **返回字段**：
  - `tmdb_id`、`title`、`original_title`、`year`、`poster_url`、`backdrop_url`、`overview`
  - `available_seasons`（数组）：剧集全部分季概况，包含 `season` 与 `share_count`。
  - `shares_count`（int）：当前筛选后返回的候选分享数。
  - `total_shares_count`（int）：该影视所有季度的总分享数。
  - `shares`（数组）：候选分享明细列表，包含：
    - `id`（int）：分享唯一编号（解锁时必传）。
    - `share_kind`（string）：`115` 或 `magnet`。
    - `share_kind_label`（string）：`115网盘` 或 `离线磁力`。
    - `season`（int）：季度。
    - `seasons`（string）：涵盖季度（如 `1` 或 `1,2,3,4`）。
    - `episode_count`（int）：分集数。
    - `episodes`（string）：分集范围（如 `1-10`）。
    - `resolution`（string）：画质分辨率（如 `1080P`、`4K`、`2160P`）。
    - `source`（string）：片源（如 `BluRay REMUX`、`BluRay`、`WEB-DL`）。
    - `video_codec`（string）：视频编码（如 `H.265`、`H.264`、`HEVC 10bit`）。
    - `audio_codec`（string）：音频编码（如 `TrueHD 5.1`、`DTS`、`AC3`）。
    - `hdr`（string）：HDR 类型。
    - `has_chinese_subtitle`（bool）：是否内封/提供中文字幕。
    - `total_size_human`（string）：可读体积（如 `105.99 GB`）。
    - `total_size_bytes`（int）：字节大小（便于客户端排序）。
    - `unlock_cost`（int）：解锁所需积分（如 4、7 积分）。
    - `file_name`（string）：首要文件名。
    - `file_list`（string 数组）：包含的具体分集完整文件名列表。
    - `tag_raw`（string）：站点原始标签串。
    - `sharer_name`（string）：发布者昵称。
    - `sharer_role`（string）：发布者角色（如 `vip`）。
    - `is_vip_sharer`（bool）：发布者是否为 VIP。
    - `created_at`（string）：发布时间。
    - `use_count`（int）：历史转存与热度。

### 3. 资源解锁与链接提取接口
- **请求方式**：POST
- **请求路径**：/api/shares/unlock
- **请求头**：`Content-Type: application/json`
- **请求体（JSON）**：
  - `share_id`（int，必填）：选中的资源唯一编号。
  - `resource_id`（int，选填）：关联资源 ID。
- **返回字段**：
  - `code`（string）：`ok` 表示成功。
  - `share_url`（string）：115 网盘分享链接（针对 115 资源）。
  - `receive_code`（string）：115 提取码。
  - `magnet_url`（string）：离线磁力链接或 Hash（针对磁力资源）。
  - `points_cost`（int）：消耗积分数。

### 4. 服务与账号运行状态接口
- **请求方式**：GET
- **请求路径**：/api/status
- **返回字段**：
  - `service`（string）：`online`。
  - `is_authenticated`（bool）：是否具备有效登录态。
  - `points`（int）：当前账号可用积分余额（实测 1,419 积分）。
  - `is_vip`（bool）：是否为 VIP。
  - `account`（object）：当前用户详细资料。
  - `proxy`（string）：代理出口地址。

### 5. 每日签到接口
- **请求方式**：POST
- **请求路径**：/api/signin
- **请求参数**：
  - `mode`（string，选填，默认 `normal`）：`normal` 为常规模式，`lucky` 为抽奖模式。
- **返回字段**：
  - `code`（string）：`ok` 或 `already_signed`。
  - `points_added`（int）：增加的积分数。

### 6. 健康检测接口
- **请求方式**：GET
- **请求路径**：/health
- **返回字段**：
  - `status`（string）：`healthy`。
  - `initialized`（bool）：浏览器内核是否已就绪。
