#!/usr/bin/env bash
set -euo pipefail

api_url="${SLATE_SUPABASE_URL:-http://127.0.0.1:54321}"
publishable_key="${SLATE_SUPABASE_PUBLISHABLE_KEY:-}"

if [[ -z "$publishable_key" ]] && command -v supabase >/dev/null 2>&1; then
  publishable_key="$(
    supabase status -o env 2>/dev/null \
      | sed -n 's/^PUBLISHABLE_KEY=//p' \
      | tr -d '"'
  )"
fi

if [[ -z "$publishable_key" ]]; then
  echo "请通过 SLATE_SUPABASE_PUBLISHABLE_KEY 提供本地 publishable key。" >&2
  exit 1
fi

for dependency in curl jq; do
  if ! command -v "$dependency" >/dev/null 2>&1; then
    echo "缺少依赖：$dependency" >&2
    exit 1
  fi
done

assert_jq() {
  local payload="$1"
  local expression="$2"
  local message="$3"
  if ! jq -e "$expression" >/dev/null <<<"$payload"; then
    echo "验证失败：$message" >&2
    jq . <<<"$payload" >&2
    exit 1
  fi
}

auth_request() {
  local path="$1"
  local payload="$2"
  curl --fail-with-body --silent --show-error \
    "$api_url/auth/v1/$path" \
    -H "apikey: $publishable_key" \
    -H "Content-Type: application/json" \
    --data "$payload"
}

rpc_request() {
  local access_token="$1"
  local payload="$2"
  curl --fail-with-body --silent --show-error \
    "$api_url/rest/v1/rpc/sync_slate_archive" \
    -H "apikey: $publishable_key" \
    -H "Authorization: Bearer $access_token" \
    -H "Content-Type: application/json" \
    --data "$payload"
}

archive_for() {
  local title="$1"
  local item_id="$2"
  local group_id="$3"
  jq -nc \
    --arg title "$title" \
    --arg itemID "$item_id" \
    --arg groupID "$group_id" \
    '{
      version: 3,
      syncRevision: 0,
      groups: [{
        id: $groupID,
        name: "同步测试",
        sortOrder: 0,
        systemImage: "folder",
        updatedAt: "2026-07-28T12:00:00Z",
        revision: 1,
        isDeleted: false
      }],
      items: [{
        id: $itemID,
        title: $title,
        isCompleted: false,
        createdAt: "2026-07-28T12:00:00Z",
        groupID: $groupID,
        sortOrder: 0,
        updatedAt: "2026-07-28T12:00:00Z",
        revision: 1,
        isDeleted: false
      }]
    }'
}

run_id="$(date +%s)-$RANDOM"
password="Slate-local-$run_id-Aa1!"
email_a="slate-a-$run_id@example.test"
email_b="slate-b-$run_id@example.test"

session_a="$(auth_request "signup" "$(jq -nc --arg email "$email_a" --arg password "$password" \
  '{email: $email, password: $password}')")"
session_b="$(auth_request "signup" "$(jq -nc --arg email "$email_b" --arg password "$password" \
  '{email: $email, password: $password}')")"

assert_jq "$session_a" '.access_token | type == "string" and length > 20' "账户 A 注册令牌"
assert_jq "$session_b" '.access_token | type == "string" and length > 20' "账户 B 注册令牌"

token_a="$(jq -r '.access_token' <<<"$session_a")"
token_b="$(jq -r '.access_token' <<<"$session_b")"
user_a="$(jq -r '.user.id' <<<"$session_a")"
user_b="$(jq -r '.user.id' <<<"$session_b")"

archive_a1="$(archive_for "来自 Mac" "11111111-1111-4111-8111-111111111111" \
  "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")"
archive_a2="$(archive_for "来自 Android" "22222222-2222-4222-8222-222222222222" \
  "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")"

first_upload="$(rpc_request "$token_a" "$(jq -nc --argjson archive "$archive_a1" \
  '{expected_revision: 0, new_archive: $archive, new_device_id: "mac"}')")"
assert_jq "$first_upload" '.[0].accepted == true and .[0].revision == 1' \
  "首次上传应创建 revision 1"

stale_upload="$(rpc_request "$token_a" "$(jq -nc --argjson archive "$archive_a2" \
  '{expected_revision: 0, new_archive: $archive, new_device_id: "android"}')")"
assert_jq "$stale_upload" \
  '.[0].accepted == false and .[0].revision == 1 and .[0].archive.items[0].title == "来自 Mac"' \
  "陈旧设备必须收到云端版本且不能覆盖"

retry_upload="$(rpc_request "$token_a" "$(jq -nc --argjson archive "$archive_a2" \
  '{expected_revision: 1, new_archive: $archive, new_device_id: "android"}')")"
assert_jq "$retry_upload" \
  '.[0].accepted == true and .[0].revision == 2 and .[0].archive.items[0].title == "来自 Android"' \
  "按最新版本重试应成功"

visible_to_b="$(curl --fail-with-body --silent --show-error \
  "$api_url/rest/v1/slate_archives?select=user_id,revision,device_id" \
  -H "apikey: $publishable_key" \
  -H "Authorization: Bearer $token_b")"
assert_jq "$visible_to_b" 'length == 0' "账户 B 不得读取账户 A 的归档"

archive_b="$(archive_for "账户 B" "33333333-3333-4333-8333-333333333333" \
  "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")"
upload_b="$(rpc_request "$token_b" "$(jq -nc --argjson archive "$archive_b" \
  '{expected_revision: 0, new_archive: $archive, new_device_id: "other-user"}')")"
assert_jq "$upload_b" '.[0].accepted == true and .[0].revision == 1' \
  "账户 B 应拥有独立归档"

visible_to_a="$(curl --fail-with-body --silent --show-error \
  "$api_url/rest/v1/slate_archives?select=user_id,revision,device_id" \
  -H "apikey: $publishable_key" \
  -H "Authorization: Bearer $token_a")"
if ! jq -e --arg user_a "$user_a" \
  'length == 1 and .[0].user_id == $user_a and .[0].revision == 2' \
  >/dev/null <<<"$visible_to_a"; then
  echo "验证失败：账户 A 只能读取自己的 revision 2" >&2
  jq . <<<"$visible_to_a" >&2
  exit 1
fi

if [[ "$user_a" == "$user_b" ]]; then
  echo "验证失败：两个测试账户意外获得相同 user ID。" >&2
  exit 1
fi

echo "同步集成测试通过：Auth、RLS、首次上传、陈旧版本拒绝与版本重试均正常。"
