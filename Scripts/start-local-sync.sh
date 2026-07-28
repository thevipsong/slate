#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"

if ! command -v supabase >/dev/null 2>&1; then
  echo "缺少 Supabase CLI。macOS 可运行：brew install supabase/tap/supabase" >&2
  exit 1
fi

cd "$project_root"
supabase start \
  -x realtime,storage-api,imgproxy,mailpit,postgres-meta,studio,edge-runtime,logflare,vector,supavisor

echo "Slate 本地同步后端已启动。"
echo "运行 ./Scripts/run-sync-integration.sh 可验证 Auth、RLS 和版本冲突流程。"
