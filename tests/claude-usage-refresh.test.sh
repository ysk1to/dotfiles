#!/bin/bash
# bin/claude-usage-refresh と bin/tmux-claude-usage のテスト。実行: tests/claude-usage-refresh.test.sh

cd "$(dirname "$0")/.." || exit 1
bin="$PWD/bin"
failures=0

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
  tmp=$(mktemp -d)
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

if [ "$failures" -ne 0 ]; then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
