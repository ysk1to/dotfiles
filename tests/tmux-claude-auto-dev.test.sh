#!/bin/bash
# bin/tmux-claude-auto-dev のテスト。実行: tests/tmux-claude-auto-dev.test.sh
# claude-auto-dev-status は偽物に差し替え、呼ばれたかを記録する。

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

# 偽の claude-auto-dev-status は FAKE_STATUS を出す
setup() {
  tmp=$(mktemp -d)
  export XDG_CACHE_HOME="$tmp" FAKE_LOG="$tmp/fake.log" FAKE_STATUS='[]' CLAUDE_AUTO_DEV_STATE_DIR="$tmp/state"
  cache="$tmp/claude-auto-dev-status.json"
  cat > "$tmp/status" <<'EOF'
#!/bin/bash
echo "status $*" >> "$FAKE_LOG"
if [ "$1" = --json ]; then echo "$FAKE_STATUS"; else echo "状況の全文"; fi
EOF
  chmod +x "$tmp/status"
  export TMUX_AUTO_DEV_STATUS="$tmp/status"
}
calls() { if [ -f "$FAKE_LOG" ]; then grep -c '^status --json' "$FAKE_LOG"; else echo 0; fi; }
# 裏で取り直すので、キャッシュができるまで少し待つ
wait_cache() { for _ in 1 2 3 4 5 6 7 8 9 10; do [ -s "$cache" ] && return; sleep 0.2; done; }

# リポジトリ1つ分の集計。引数の jq の式で項目を上書きする（例: repo '.decisions = [1, 2]'）
repo() {
  jq -cn "{name: \"my-app\", label: \"app\", decisions: [], prs: [], in_progress: [], ready: 0, running: null,
    schedule: {next_at: null, missed_at: null}, runs: {today: {count: 0, cost: 0}}, notices: []} | ${1:-.}"
}
show() { "$bin/tmux-claude-auto-dev"; }
# 実行中の回は、キャッシュでなく claude-auto-dev のロックを毎回読む（すぐ変わるため）。使い方: running <名前> <run の JSON>
running() {
  mkdir -p "$CLAUDE_AUTO_DEV_STATE_DIR/locks/$1"
  echo $$ > "$CLAUDE_AUTO_DEV_STATE_DIR/locks/$1/pid"
  echo "$2" > "$CLAUDE_AUTO_DEV_STATE_DIR/locks/$1/run"
}
# 時刻は固定する（2026-11-18 16:30、この Mac のタイムゾーン）
now=$(date -j -f '%Y-%m-%d %H:%M:%S' '2026-11-18 16:30:00' +%s)
export CLAUDE_AUTO_DEV_NOW="$now"

# ---- 表示 ----
setup
echo "[$(repo '.decisions = [1, 2] | .prs = [1] | .ready = 19')]" > "$cache"
assert_eq "略称のあとに件数を絵文字で出す" "🛠 app 🙋2 🔀1 📥19" "$(show)"

setup
echo "[$(repo)]" > "$cache"
assert_eq "何もなければ ✓ だけ" "🛠 app ✓" "$(show)"

setup
echo "[$(repo '.ready = 3'), $(repo '.name = "foo" | .label = "foo" | .decisions = [1]')]" > "$cache"
assert_eq "リポジトリごとに区切って並べる" "🛠 app 📥3 │ foo 🙋1" "$(show)"

setup
echo "[$(repo)]" > "$cache"
running my-app '{"mode":"implement","issue":14,"started_at":'"$((now - 750))"'}'
assert_eq "実行中の回は、Issue と経過時間を出す" "🛠 app 🏃#14 12m" "$(show)"
running my-app '{"mode":"plan","issue":null,"started_at":'"$((now - 3900))"'}'
assert_eq "企画の回は 🏃企画（1時間を超えたら時間も）" "🛠 app 🏃企画 1h05m" "$(show)"
running my-app '{"mode":"review","issue":null,"started_at":'"$now"'}'
assert_eq "精査の回は 🏃精査" "🛠 app 🏃精査 0m" "$(show)"

setup
echo "[$(repo)]" > "$cache"
running my-app '{"mode":"implement","issue":14,"started_at":1}'
sleep 30 & dead=$!
kill "$dead"; wait "$dead" 2>/dev/null
echo "$dead" > "$CLAUDE_AUTO_DEV_STATE_DIR/locks/my-app/pid"
assert_eq "落ちてロックだけ残っていれば 🏃 を出さない" "🛠 app ✓" "$(show)"

setup
echo "[$(repo '.in_progress = [{number: 8}]')]" > "$cache"
assert_eq "作業中のラベルだけで実行中でなければ 🏃 を出さない" "🛠 app ✓" "$(show)"

setup
next=$(date -j -f '%Y-%m-%d %H:%M:%S' '2026-11-18 18:00:00' +%s)
later=$(date -j -f '%Y-%m-%d %H:%M:%S' '2026-11-18 20:00:00' +%s)
echo "[$(repo ".schedule.next_at = $later | .runs.today.count = 1 | .runs.today.cost = 0.4"),
  $(repo ".name = \"foo\" | .label = \"foo\" | .schedule.next_at = $next | .runs.today.count = 2 | .runs.today.cost = 1.7")]" > "$cache"
assert_eq "最後に、いちばん近い次の起動と今日の回数・費用をまとめて出す" "🛠 app ✓ │ foo ✓ │ ⏭18:00 🔁3 💲2.10" "$(show)"

setup
echo "[$(repo '.schedule.missed_at = 1')]" > "$cache"
assert_eq "起動の見落としは ⚠️" "🛠 app ⚠️" "$(show)"
echo "[$(repo '.error = "gh で取得できません"')]" > "$cache"
assert_eq "gh の失敗は ⚠️" "🛠 app ⚠️" "$(show)"
echo "[$(repo '.notices = [{at: 1, title: "が失敗", message: "m"}]')]" > "$cache"
assert_eq "失敗の通知は ⚠️" "🛠 app ⚠️" "$(show)"
echo "[$(repo '.notices = [{at: 1, title: "が判断待ち", message: "m"}]')]" > "$cache"
assert_eq "失敗でない通知は ⚠️ にしない" "🛠 app ✓" "$(show)"

setup
echo "[]" > "$cache"
assert_eq "自動開発のリポジトリがなければ何も出さない" "" "$(show)"

# ---- キャッシュ ----
setup
echo "[$(repo '.ready = 1')]" > "$cache"
"$bin/tmux-claude-auto-dev" >/dev/null
sleep 0.5
assert_eq "キャッシュが新しければ取り直さない" "0" "$(calls)"

setup
echo "[$(repo '.ready = 1')]" > "$cache"
touch -t 202601010000 "$cache"
FAKE_STATUS="[$(repo '.ready = 7')]"
export FAKE_STATUS
assert_eq "古いキャッシュでも、待たずにそれを出す" "🛠 app 📥1" "$("$bin/tmux-claude-auto-dev")"
for _ in 1 2 3 4 5 6 7 8 9 10; do grep -q '"ready":7' "$cache" 2>/dev/null && break; sleep 0.2; done
assert_eq "古いキャッシュは裏で取り直す" "🛠 app 📥7" "$("$bin/tmux-claude-auto-dev")"

setup
FAKE_STATUS="[$(repo '.decisions = [1]')]"
export FAKE_STATUS
assert_eq "キャッシュがなければ、取り直している間は … を出す" "🛠 …" "$("$bin/tmux-claude-auto-dev")"
wait_cache
assert_eq "取り直したら件数を出す" "🛠 app 🙋1" "$("$bin/tmux-claude-auto-dev")"

setup
cat > "$tmp/status" <<'EOF'
#!/bin/bash
echo "status $*" >> "$FAKE_LOG"
exit 1
EOF
echo "[$(repo '.ready = 1')]" > "$cache"
touch -t 202601010000 "$cache"
"$bin/tmux-claude-auto-dev" >/dev/null
sleep 0.5
assert_eq "取り直しに失敗したら、前のキャッシュを残す" "🛠 app 📥1" "$("$bin/tmux-claude-auto-dev")"

# ---- ポップアップ ----
setup
popup=$("$bin/tmux-claude-auto-dev" --popup)
assert_eq "ポップアップに凡例を出す" "yes" "$(echo "$popup" | grep -q '🙋 判断待ちの Issue' && echo yes || echo no)"
assert_eq "凡例に次の起動と今日の回数・費用も出す" "yes" "$(echo "$popup" | grep -q '⏭ 次の起動' && echo "$popup" | grep -q '💲' && echo yes || echo no)"
assert_eq "ポップアップに状況の全文を出す" "yes" "$(echo "$popup" | grep -q '状況の全文' && echo yes || echo no)"

# ---- 実行中の回だけ出す（claude-auto-dev-watch が使う） ----
setup
running my-app '{"mode":"plan","issue":null,"started_at":1}'
assert_eq "--running で実行中の回を名前ごとに JSON で出す" '{"my-app":{"mode":"plan","issue":null,"started_at":1}}' "$("$bin/tmux-claude-auto-dev" --running)"
assert_eq "--running では gh を呼ばない" "0" "$(calls)"

[ "$failures" -eq 0 ] || exit 1
