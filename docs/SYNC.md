# 序事双端同步设计

## 安全边界

- 使用 Supabase Email/Password Auth，不在客户端保存 `service_role` 或 secret key。
- 客户端只使用可公开分发的 publishable key。
- 正式版已预置序事云同步项目地址与 publishable key，用户只需注册或登录同步账户。
- `slate_archives` 开启 RLS；每个用户只能读取和修改 `auth.uid()` 对应的一行。
- 会话令牌在 macOS Keychain 和 Android Keystore 中保存。

## 一致性

云端记录包含单调递增的 `revision`。上传必须携带客户端最后看到的版本：

1. 版本一致：数据库原子更新并将版本加一。
2. 版本不一致：RPC 返回最新云端数据，不执行覆盖。
3. 客户端使用上次同步的基线做三方合并，再按新版本重试。

三方合并以任务和分组 UUID 为单位：

- 只有本地修改：保留本地。
- 只有云端修改：采用云端。
- 一端删除、另一端未修改：删除生效。
- 两端同时修改同一实体：记录冲突，并按较新的设备修改时间选择。

每次成功同步后保存新的本地基线。最多自动重试三次，仍冲突时保留本地数据并提示用户重试。

两端在本地修改后会先防抖再自动上传；Android 应用处于前台时，每 5 秒只读取一次
远端 `revision`，仅在版本变化时下载完整档案并进入三方合并和写回流程。这样另一端
的修改通常会在约 5 秒内出现，同时避免空轮询反复传输完整档案或增加云端版本号。

## API

数据库迁移位于：

```text
supabase/migrations/20260728000000_create_slate_sync.sql
```

客户端通过 Supabase Auth REST API 登录，通过 `sync_slate_archive` RPC 完成
compare-and-swap，不直接执行无条件覆盖。

## 本地集成验证

需要 Docker 与 Supabase CLI。启动仅包含 Auth、Postgres、REST 和网关的精简环境：

```bash
./Scripts/start-local-sync.sh
./Scripts/run-sync-integration.sh
```

集成脚本会创建两个隔离测试账户，验证：

- 注册与访问令牌；
- 用户间 RLS 数据隔离；
- 首次上传生成 `revision 1`；
- 陈旧客户端不能覆盖远端；
- 客户端取得最新版本后可以安全重试。

macOS 调试构建允许连接 `http://127.0.0.1`，Android 调试构建允许连接
`http://10.0.2.2`。发布构建始终要求 HTTPS。
