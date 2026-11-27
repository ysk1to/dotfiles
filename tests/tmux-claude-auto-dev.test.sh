#!/bin/bash
# bin/tmux-claude-auto-dev のテスト。実行: tests/tmux-claude-auto-dev.test.sh
# claude-auto-dev-status は偽物に差し替え、呼ばれたかを記録する。

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

# 偽の claude-auto-dev-status は FAKE_STATUS を出す。FAKE_DELAY（秒）があれば、出す前にその分だけ待つ
setup() {
  tmp=$(mktemp -d "$tmp_root/XXXXXX")
  export XDG_CACHE_HOME="$tmp" FAKE_LOG="$tmp/fake.log" FAKE_STATUS='[]' FAKE_DELAY=0 CLAUDE_AUTO_DEV_STATE_DIR="$tmp/state"
  cache="$tmp/claude-auto-dev-status.json"
  cat > "$tmp/status" <<'EOF'
#!/bin/bash
echo "status $*" >> "$FAKE_LOG"
sleep "$FAKE_DELAY"
if [ "$1" = --json ]; then echo "$FAKE_STATUS"; else echo "状況の全文"; fi
EOF
  chmod +x "$tmp/status"
  export TMUX_AUTO_DEV_STATUS="$tmp/status"
  # 偽の docker。info は FAKE_DOCKER_INFO（既定 0）で終わり、ps は FAKE_DOCKER_PS（「compose のプロジェクト<TAB>状態」の行）を出す
  export FAKE_DOCKER_INFO=0 FAKE_DOCKER_PS=''
  cat > "$tmp/docker" <<'EOF'
#!/bin/bash
echo "docker $1" >> "$FAKE_LOG"
case "$1" in
  info) exit "$FAKE_DOCKER_INFO" ;;
  ps) [ -n "$FAKE_DOCKER_PS" ] && printf '%b\n' "$FAKE_DOCKER_PS" ;;
esac
exit 0
EOF
  chmod +x "$tmp/docker"
  export TMUX_AUTO_DEV_DOCKER="$tmp/docker"
}
calls() { if [ -f "$FAKE_LOG" ]; then grep -c '^status --json' "$FAKE_LOG"; else echo 0; fi; }
# 裏で取り直すので、キャッシュができるまで少し待つ（最長5秒）
wait_cache() { for _ in $(seq 25); do [ -s "$cache" ] && return; sleep 0.2; done; }

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
assert_eq "略称のあとに件数を絵文字で出す" "🔧 app  🙋 2  🔀 1  📥 19" "$(show)"

setup
echo "[$(repo)]" > "$cache"
assert_eq "何もなければ ✓ だけ" "🔧 app  ✓" "$(show)"

setup
echo "[$(repo '.ready = 3'), $(repo '.name = "foo" | .label = "foo" | .decisions = [1]')]" > "$cache"
assert_eq "リポジトリごとに区切って並べる" "🔧 app  📥 3  │  foo  🙋 1" "$(show)"

setup
echo "[$(repo)]" > "$cache"
running my-app '{"mode":"implement","issue":14,"started_at":'"$((now - 750))"'}'
assert_eq "実行中の回は、Issue と経過時間を出す" "🔧 app  🏃 #14 12m" "$(show)"
running my-app '{"mode":"plan","issue":null,"started_at":'"$((now - 3900))"'}'
assert_eq "企画の回は 🏃 Planner（1時間を超えたら時間も）" "🔧 app  🏃 Planner 1h05m" "$(show)"
running my-app '{"mode":"review","issue":null,"started_at":'"$now"'}'
assert_eq "精査の回は 🏃 Auditor" "🔧 app  🏃 Auditor 0m" "$(show)"
running my-app '{"mode":"explore","issue":null,"started_at":'"$now"'}'
assert_eq "探索の回は 🏃 Researcher" "🔧 app  🏃 Researcher 0m" "$(show)"
running my-app '{"mode":"evaluate","issue":null,"started_at":'"$now"'}'
assert_eq "Evaluator の回は 🏃 Evaluator" "🔧 app  🏃 Evaluator 0m" "$(show)"
running my-app '{"mode":"other","issue":null,"started_at":'"$now"'}'
assert_eq "知らない種類の回は、mode をそのまま出す" "🔧 app  🏃 other 0m" "$(show)"

setup
echo "[$(repo)]" > "$cache"
running my-app '{"mode":"implement","issue":14,"started_at":1}'
sleep 30 & dead=$!
kill "$dead"; wait "$dead" 2>/dev/null
echo "$dead" > "$CLAUDE_AUTO_DEV_STATE_DIR/locks/my-app/pid"
assert_eq "落ちてロックだけ残っていれば 🏃 を出さない" "🔧 app  ✓" "$(show)"

setup
echo "[$(repo '.in_progress = [{number: 8}]')]" > "$cache"
assert_eq "作業中のラベルだけで実行中でなければ 🏃 を出さない" "🔧 app  ✓" "$(show)"

setup
next=$(date -j -f '%Y-%m-%d %H:%M:%S' '2026-11-18 18:00:00' +%s)
later=$(date -j -f '%Y-%m-%d %H:%M:%S' '2026-11-18 20:00:00' +%s)
echo "[$(repo ".schedule.next_at = $later | .runs.today.count = 1 | .runs.today.cost = 0.4 | .runs.today.duration = 1500"),
  $(repo ".name = \"foo\" | .label = \"foo\" | .schedule.next_at = $next | .runs.today.count = 2 | .runs.today.cost = 1.7 | .runs.today.duration = 5220")]" > "$cache"
assert_eq "最後に、いちばん近い次の起動と今日の回数・かかった時間をまとめて出す" "🔧 app  ✓  │  foo  ✓  │  ⏩ 18:00  🔁 3  ⏳ 1h52m" "$(show)"

setup
echo "[$(repo '.schedule.missed_at = 1')]" > "$cache"
assert_eq "起動の見落としは 🚨" "🔧 app  🚨" "$(show)"
echo "[$(repo '.error = "gh で取得できません"')]" > "$cache"
assert_eq "gh の失敗は 🚨" "🔧 app  🚨" "$(show)"
echo "[$(repo '.notices = [{at: 1, title: "が失敗", message: "m"}]')]" > "$cache"
assert_eq "失敗の通知は 🚨" "🔧 app  🚨" "$(show)"
echo "[$(repo '.notices = [{at: 1, title: "が失敗", message: "m", resolved: true}]')]" > "$cache"
assert_eq "後の回が正常に終わった失敗は 🚨 にしない" "🔧 app  ✓" "$(show)"
echo "[$(repo '.notices = [{at: 1, title: "が判断待ち", message: "m"}]')]" > "$cache"
assert_eq "失敗でない通知は 🚨 にしない" "🔧 app  ✓" "$(show)"

# tmux は幅が狭い（East Asian Width が W でない）絵文字を1桁と数え、iTerm2 は2桁で描くので、後ろの文字に重なる。
# 絵文字は幅が広いものだけを使う（✓ と区切りの │ は1桁で描かれるので除く）
setup
echo "[$(repo ".decisions = [1] | .prs = [1] | .ready = 1 | .error = \"e\" | .schedule.next_at = $now | .runs.today.count = 1 | .runs.today.cost = 1")]" > "$cache"
running my-app '{"mode":"implement","issue":14,"started_at":1}'
narrow=$(show | python3 -c 'import sys, unicodedata as u; print("".join(sorted({c for c in sys.stdin.read() if ord(c) > 0x2000 and c not in "✓│…" and u.east_asian_width(c) != "W"})))')
assert_eq "幅が狭い絵文字を使わない" "" "$narrow"

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
# 取り直しに時間がかかるようにする。すぐ終わると、古いキャッシュを読む前に新しいキャッシュに入れ替わることがあり、
# 待たずに出したのかを確かめられない
export FAKE_STATUS FAKE_DELAY=2
assert_eq "古いキャッシュでも、待たずにそれを出す" "🔧 app  📥 1" "$("$bin/tmux-claude-auto-dev")"
for _ in $(seq 35); do grep -q '"ready":7' "$cache" 2>/dev/null && break; sleep 0.2; done
assert_eq "古いキャッシュは裏で取り直す" "🔧 app  📥 7" "$("$bin/tmux-claude-auto-dev")"

setup
FAKE_STATUS="[$(repo '.decisions = [1]')]"
# 上と同じ理由で、取り直しに時間がかかるようにする
export FAKE_STATUS FAKE_DELAY=2
assert_eq "キャッシュがなければ、取り直している間は … を出す" "🔧 …" "$("$bin/tmux-claude-auto-dev")"
wait_cache
assert_eq "取り直したら件数を出す" "🔧 app  🙋 1" "$("$bin/tmux-claude-auto-dev")"

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
assert_eq "取り直しに失敗したら、前のキャッシュを残す" "🔧 app  📥 1" "$("$bin/tmux-claude-auto-dev")"

# ---- ポップアップ ----
setup
popup=$("$bin/tmux-claude-auto-dev" --popup)
assert_eq "ポップアップに凡例を出す" "yes" "$(echo "$popup" | grep -q '🙋 判断待ちの Issue' && echo yes || echo no)"
assert_eq "凡例に次の起動と今日の回数・かかった時間も出す" "yes" "$(echo "$popup" | grep -q '⏩ 次の起動' && echo "$popup" | grep -q '⏳ 今日のかかった時間' && echo yes || echo no)"
assert_eq "凡例の実行中の回は、役割の名前で出す" "yes" "$(echo "$popup" | grep -qF '🏃 実行中の回（#Issue・Planner・Researcher・Auditor・Evaluator と経過時間）' && echo yes || echo no)"
assert_eq "凡例の Eco は、Engineer だけを2時間おきと出す" "yes" "$(echo "$popup" | grep -qF '（Engineer だけを2時間おき）' && echo yes || echo no)"
assert_eq "凡例に費用は出さない" "no" "$(echo "$popup" | grep -q '💰' && echo yes || echo no)"
assert_eq "ポップアップに状況の全文を出す" "yes" "$(echo "$popup" | grep -q '状況の全文' && echo yes || echo no)"

# ---- ペース配分の段階 ----
# claude-auto-dev が起動のたびに残す段階（pace/<名前>）のうち、いちばん新しいものを全体の欄に出す。Normal は出さない
pace() { mkdir -p "$CLAUDE_AUTO_DEV_STATE_DIR/pace"; echo "$2" > "$CLAUDE_AUTO_DEV_STATE_DIR/pace/$1"; }
setup
echo "[$(repo '.ready = 3')]" > "$cache"
pace my-app boost
assert_eq "Boost の段階なら 🚀 Boost を出す" "🔧 app  📥 3  │  🚀 Boost" "$(show)"
pace my-app eco
assert_eq "Eco の段階なら 🍃 Eco を出す" "🔧 app  📥 3  │  🍃 Eco" "$(show)"
pace my-app normal
assert_eq "Normal の段階では何も出さない" "🔧 app  📥 3" "$(show)"
pace my-app ''
assert_eq "段階が決まっていなければ何も出さない" "🔧 app  📥 3" "$(show)"
setup
echo "[$(repo '.schedule.next_at = '"$((now + 1800))"' | .runs.today = {count: 4, duration: 600}')]" > "$cache"
pace my-app boost
assert_eq "段階は、次の起動の前に出す" "🔧 app  ✓  │  🚀 Boost  ⏩ 17:00  🔁 4  ⏳ 10m" "$(show)"
setup
echo "[$(repo)]" > "$cache"
pace my-app boost
sleep 1
pace foo eco
assert_eq "リポジトリが複数あれば、いちばん新しい段階を出す" "🔧 app  ✓  │  🍃 Eco" "$(show)"
setup
echo "[$(repo)]" > "$cache"
pace my-app boost
touch -t 202601010000 "$CLAUDE_AUTO_DEV_STATE_DIR/pace/my-app"
assert_eq "3時間より古い段階は出さない（起動が止まっているとき）" "🔧 app  ✓" "$(show)"
setup
pace my-app boost
assert_eq "凡例に段階を出す" "yes" "$("$bin/tmux-claude-auto-dev" --popup | grep -q '🍃 Eco.*🚀 Boost' && echo yes || echo no)"

# ---- セルフホストランナー ----
# compose のプロジェクトが「<リポジトリ名>-runner」のコンテナを、動いていないときだけ出す。docker は裏で呼び、結果を使い回す
runners() { "$bin/tmux-claude-auto-dev" --runners; }
setup
FAKE_DOCKER_PS='keibai-archive-runner\trunning\nakiya-archive-runner\trunning'
assert_eq "ランナーがすべて動いていれば何も出さない" "" "$(runners)"
FAKE_DOCKER_PS='keibai-archive-runner\trunning\nakiya-archive-runner\texited'
assert_eq "止まっているランナーは、リポジトリ名を出す" "⚠ runner: akiya-archive" "$(runners)"
FAKE_DOCKER_PS='keibai-archive-runner\trestarting\nakiya-archive-runner\texited'
assert_eq "再起動を繰り返しているものも出し、複数なら並べる" "⚠ runner: keibai-archive akiya-archive" "$(runners)"
FAKE_DOCKER_PS='keibai-archive\texited\n\texited'
assert_eq "ランナーでないコンテナは見ない" "" "$(runners)"
setup
FAKE_DOCKER_PS='keibai-archive-runner\trunning'
runners > /dev/null
FAKE_DOCKER_INFO=1
assert_eq "Docker に届かず、前にランナーがあったなら ⚠ Docker を出す" "⚠ Docker" "$(runners)"
setup
FAKE_DOCKER_INFO=1
assert_eq "ランナーを一度も見ていなければ、Docker に届かなくても出さない" "" "$(runners)"

setup
echo "[$(repo '.schedule.next_at = '"$((now + 1800))"'')]" > "$cache"
pace my-app eco
echo "⚠ runner: akiya-archive" > "$tmp/claude-auto-dev-runners"
assert_eq "ランナーの警告は、全体の欄の先頭に出す" "🔧 app  ✓  │  ⚠ runner: akiya-archive  🍃 Eco  ⏩ 17:00" "$(show)"
setup
echo "[$(repo)]" > "$cache"
echo "⚠ Docker" > "$tmp/claude-auto-dev-runners"
assert_eq "全体の欄にほかに何もなくても出す" "🔧 app  ✓  │  ⚠ Docker" "$(show)"
setup
echo "[$(repo)]" > "$cache"
show > /dev/null
for _ in $(seq 25); do [ -f "$tmp/claude-auto-dev-runners" ] && break; sleep 0.2; done
assert_eq "ランナーの状況は、裏で取り直してキャッシュする" "yes" "$([ -f "$tmp/claude-auto-dev-runners" ] && echo yes || echo no)"
setup
assert_eq "凡例にランナーの警告を出す" "yes" "$("$bin/tmux-claude-auto-dev" --popup | grep -q '⚠ runner' && echo yes || echo no)"

# ---- 実行中の回だけ出す（claude-auto-dev-watch が使う） ----
setup
running my-app '{"mode":"plan","issue":null,"started_at":1}'
assert_eq "--running で実行中の回を名前ごとに JSON で出す" '{"my-app":{"mode":"plan","issue":null,"started_at":1}}' "$("$bin/tmux-claude-auto-dev" --running)"
assert_eq "--running では gh を呼ばない" "0" "$(calls)"

[ "$failures" -eq 0 ] || exit 1
