#!/bin/bash
# bin/claude-usage-refresh と bin/tmux-claude-usage のテスト。実行: tests/claude-usage-refresh.test.sh

cd "$(dirname "$0")/.." || exit 1
bin="$PWD/bin"
failures=0

# setup が作るフォルダは1つのフォルダの下に置き、終わるときにまとめて消す
tmp_root=$(mktemp -d)
trap 'rm -rf "$tmp_root"' EXIT

assert_eq() {
  if [ "$2" = "$3" ]; then
    echo "ok   $1"
  else
    echo "FAIL $1"
    echo "  expected: $2"
    echo "  actual:   $3"
    failures=$((failures + 1))
  fi
}

setup() {
  tmp=$(mktemp -d "$tmp_root/XXXXXX")
  export XDG_CACHE_HOME="$tmp"
  cache="$tmp/claude-rate-limits.json"
}

api_response='{
  "five_hour": {"utilization": 5.0, "resets_at": "2026-11-16T04:50:00.368943+00:00"},
  "seven_day": {"utilization": 45.0, "resets_at": "2026-11-21T12:00:00.368963+00:00"}
}'

# API の結果をキャッシュの形式（used_percentage と UNIX 時刻の resets_at）に直して書き込む
setup
CLAUDE_USAGE_FETCH="echo '$api_response'" "$bin/claude-usage-refresh"
assert_eq "API の結果をキャッシュ形式で書き込む" \
  '{"five_hour":{"used_percentage":5,"resets_at":1794804600},"seven_day":{"used_percentage":45,"resets_at":1795262400}}' \
  "$(cat "$cache" 2>/dev/null)"

# モデルごとの週の枠（limits の weekly_scoped）のうち、Fable の枠を seven_day_fable として書き込む
api_response_fable='{
  "five_hour": {"utilization": 5.0, "resets_at": "2026-11-16T04:50:00.368943+00:00"},
  "seven_day": {"utilization": 45.0, "resets_at": "2026-11-21T12:00:00.368963+00:00"},
  "limits": [
    {"kind": "weekly_all", "percent": 45, "resets_at": "2026-11-21T12:00:00.368963+00:00", "scope": null},
    {"kind": "weekly_scoped", "percent": 35, "resets_at": "2026-11-21T12:00:00.687188+00:00",
     "scope": {"model": {"id": null, "display_name": "Fable"}, "surface": null}}
  ]
}'
setup
CLAUDE_USAGE_FETCH="echo '$api_response_fable'" "$bin/claude-usage-refresh"
assert_eq "Fable の週の枠もキャッシュに書き込む" \
  '{"five_hour":{"used_percentage":5,"resets_at":1794804600},"seven_day":{"used_percentage":45,"resets_at":1795262400},"seven_day_fable":{"used_percentage":35,"resets_at":1795262400}}' \
  "$(cat "$cache" 2>/dev/null)"

# --print では、キャッシュに書くのに加えて、記録用の要約を1行で出す。
# 週の枠の内訳（seven_day_breakdown）は使った場所ごとの枠に対する割合、Fable の割合（weekly_scoped_shares）は週の枠に対する割合
api_response_full='{
  "five_hour": {"utilization": 5.0, "resets_at": "2026-11-16T04:50:00.368943+00:00"},
  "seven_day": {"utilization": 45.0, "resets_at": "2026-11-21T12:00:00.368963+00:00"},
  "limits": [
    {"kind": "session", "percent": 5, "resets_at": "2026-11-16T04:50:00.368943+00:00", "scope": null},
    {"kind": "weekly_all", "percent": 45, "resets_at": "2026-11-21T12:00:00.368963+00:00", "scope": null},
    {"kind": "weekly_scoped", "percent": 35, "resets_at": "2026-11-21T12:00:00.687188+00:00",
     "scope": {"model": {"id": null, "display_name": "Fable"}, "surface": null}}
  ],
  "seven_day_breakdown": {"rows": [
    {"key": "claude_code", "percent": 92, "percent_of_limit": 41},
    {"key": "cowork", "percent": 8, "percent_of_limit": 4}
  ]},
  "weekly_scoped_shares": [{"limit_index": 2, "used_percent_of_weekly": 17, "allowance_percent_of_weekly": 50}]
}'
setup
out=$(CLAUDE_USAGE_FETCH="echo '$api_response_full'" "$bin/claude-usage-refresh" --print)
assert_eq "--print で、記録用の要約を出す" \
  '{"five_hour":{"used_percentage":5,"resets_at":1794804600},"seven_day":{"used_percentage":45,"resets_at":1795262400},"seven_day_fable":{"used_percentage":35,"resets_at":1795262400},"breakdown":{"claude_code":41,"cowork":4},"fable_share_of_week":17}' \
  "$(jq -c 'del(.at)' <<< "$out")"
assert_eq "--print の要約に、取得した時刻を入れる" "yes" \
  "$(jq -e '.at | type == "number" and . > 1794000000' <<< "$out" > /dev/null && echo yes || echo no)"
assert_eq "--print でも、キャッシュには内訳を書かない" \
  '{"five_hour":{"used_percentage":5,"resets_at":1794804600},"seven_day":{"used_percentage":45,"resets_at":1795262400},"seven_day_fable":{"used_percentage":35,"resets_at":1795262400}}' \
  "$(cat "$cache" 2>/dev/null)"
setup
assert_eq "--print がなければ、何も出さない" "" "$(CLAUDE_USAGE_FETCH="echo '$api_response_full'" "$bin/claude-usage-refresh")"

# 取得に失敗したときは既存のキャッシュを残す
setup
echo '{"five_hour":{"used_percentage":1,"resets_at":1}}' > "$cache"
CLAUDE_USAGE_FETCH="false" "$bin/claude-usage-refresh"
assert_eq "取得に失敗したらキャッシュを変えない" \
  '{"five_hour":{"used_percentage":1,"resets_at":1}}' "$(cat "$cache")"

# 想定外の応答（エラー JSON など）でも既存のキャッシュを残す
setup
echo '{"five_hour":{"used_percentage":1,"resets_at":1}}' > "$cache"
CLAUDE_USAGE_FETCH="echo '{\"error\":{\"type\":\"authentication_error\"}}'" "$bin/claude-usage-refresh"
assert_eq "想定外の応答ならキャッシュを変えない" \
  '{"five_hour":{"used_percentage":1,"resets_at":1}}' "$(cat "$cache")"

# 前回の確認から時間が経っていれば、バックグラウンドで更新を起動する
setup
marker="$tmp/refreshed"
CLAUDE_USAGE_REFRESH="touch $marker" "$bin/tmux-claude-usage" > /dev/null
sleep 0.5
assert_eq "初回は更新を起動する" "yes" "$([ -f "$marker" ] && echo yes || echo no)"

# 前回の確認から間もなければ、更新を起動しない
rm -f "$marker"
CLAUDE_USAGE_REFRESH="touch $marker" "$bin/tmux-claude-usage" > /dev/null
sleep 0.5
assert_eq "直後の呼び出しでは更新しない" "no" "$([ -f "$marker" ] && echo yes || echo no)"

# 確認の間隔は1時間。10分前に確認済みなら起動しない
rm -f "$marker"
touch -t "$(date -v-10M +%Y%m%d%H%M.%S)" "$cache.checked"
CLAUDE_USAGE_REFRESH="touch $marker" "$bin/tmux-claude-usage" > /dev/null
sleep 0.5
assert_eq "10分前に確認済みなら更新しない" "no" "$([ -f "$marker" ] && echo yes || echo no)"

# 1時間を過ぎていれば起動する
touch -t "$(date -v-61M +%Y%m%d%H%M.%S)" "$cache.checked"
CLAUDE_USAGE_REFRESH="touch $marker" "$bin/tmux-claude-usage" > /dev/null
sleep 0.5
assert_eq "61分前の確認なら更新する" "yes" "$([ -f "$marker" ] && echo yes || echo no)"

# キャッシュに Fable の枠があれば、7d の後ろに表示する
setup
echo '{"seven_day_fable":{"used_percentage":35,"resets_at":9999999999}}' > "$cache"
assert_eq "Fable の使用率を表示する" \
  '⏳ 5h -- 📆 7d -- 🐉 Fable #[fg=colour120]▰▱▱▱▱ #[bold]35%#[nobold,fg=default]' \
  "$(CLAUDE_USAGE_REFRESH=true "$bin/tmux-claude-usage")"

# Fable の枠がなければ、区画を出さない
setup
echo '{}' > "$cache"
assert_eq "Fable の枠がなければ表示しない" '⏳ 5h -- 📆 7d --' \
  "$(CLAUDE_USAGE_REFRESH=true "$bin/tmux-claude-usage")"

# リセットの時刻を過ぎた Fable の枠は表示しない
setup
echo '{"seven_day_fable":{"used_percentage":35,"resets_at":1}}' > "$cache"
assert_eq "期限の過ぎた Fable の枠は表示しない" '⏳ 5h -- 📆 7d --' \
  "$(CLAUDE_USAGE_REFRESH=true "$bin/tmux-claude-usage")"

if [ "$failures" -ne 0 ]; then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
