#!/bin/bash
# bin/claude-auto-dev-watch のテスト。実行: tests/claude-auto-dev-watch.test.sh
# 状況のキャッシュとできごとのファイルは一時ディレクトリに作る。tmux は偽物に差し替え、呼ばれ方を記録する。

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
has() { if grep -qF -- "$2" <<< "$1"; then echo yes; else echo no; fi; }

# 時刻は固定する（2026-11-18 16:30、この Mac のタイムゾーン）
now=$(date -j -f '%Y-%m-%d %H:%M:%S' '2026-11-18 16:30:00' +%s)
at() { date -j -f '%Y-%m-%d %H:%M:%S' "$1" +%s; }

setup() {
  tmp=$(mktemp -d)
  state="$tmp/state"
  cache="$tmp/claude-auto-dev-status.json"
  mkdir -p "$state" "$tmp/bin"
  export XDG_CACHE_HOME="$tmp" CLAUDE_AUTO_DEV_STATE_DIR="$state" CLAUDE_AUTO_DEV_NOW="$now" LINES=40 COLUMNS=60
  export TMUX_AUTO_DEV_STATUS=/usr/bin/true TMUX_AUTO_DEV_TTL=100000 FAKE_LOG="$tmp/fake.log" TMUX_PANE=
  export PATH="$tmp/bin:$PATH"
  export FAKE_PANES=
  cat > "$tmp/bin/tmux" <<'EOF'
#!/bin/bash
echo "tmux $*" >> "$FAKE_LOG"
[ "$1" != list-panes ] || printf '%s' "$FAKE_PANES"
EOF
  chmod +x "$tmp/bin/tmux"
  echo '[]' > "$cache"
}
# リポジトリ1つ分の集計。引数の jq の式で項目を上書きする
repo() {
  jq -cn "{name: \"my-app\", label: \"app\", decisions: [], prs: [], in_progress: [], ready: 0, running: null,
    schedule: {next_at: null, missed_at: null}, runs: {today: {count: 0, cost: 0}}, notices: []} | ${1:-.}"
}
running() { # 名前 run の JSON
  mkdir -p "$state/locks/$1"
  echo $$ > "$state/locks/$1/pid"
  echo "$2" > "$state/locks/$1/run"
}
event() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" >> "$state/events.tsv"; }
frame() { "$bin/claude-auto-dev-watch" --once 2>&1; }

# ---- リポジトリごとの状況 ----
setup
echo '[]' > "$cache"
assert_eq "リポジトリがなければ、そう伝える" "yes" "$(has "$(frame)" 'まだ動いていません')"

setup
echo "[$(repo)]" > "$cache"
assert_eq "何もなければ略称と ✓" "yes" "$(has "$(frame)" 'app  ✓')"

setup
echo "[$(repo '.decisions = [{number: 15}, {number: 18}] | .prs = [{number: 36}] | .ready = 5')]" > "$cache"
out=$(frame)
assert_eq "判断待ちは番号を出す" "yes" "$(has "$out" '🙋 #15 #18')"
assert_eq "開いている PR は番号を出す" "yes" "$(has "$out" '🔀 #36')"
assert_eq "着手できる Issue は件数を出す" "yes" "$(has "$out" '📥 5')"

setup
echo "[$(repo)]" > "$cache"
running my-app '{"mode":"implement","issue":14,"log":"/x.log","started_at":'"$((now - 750))"'}'
assert_eq "実行中の回は、Issue と経過時間を出す" "yes" "$(has "$(frame)" '🏃 #14 の実装 12m')"

setup
next=$(at '2026-11-18 18:00:00')
echo "[$(repo ".schedule.next_at = $next | .runs.today.count = 3 | .runs.today.cost = 2.1")]" > "$cache"
assert_eq "次の起動と今日の回数・費用を出す" "yes" "$(has "$(frame)" '⏭ 18:00  🔁 3  💲 2.10')"

setup
echo "[$(repo ".schedule.missed_at = $(at '2026-11-18 16:00:00')")]" > "$cache"
assert_eq "起動の見落としを出す" "yes" "$(has "$(frame)" '⚠️ 16:00 の起動が記録されていません')"
echo "[$(repo '.error = "gh で Issue と PR を取得できません"')]" > "$cache"
assert_eq "gh の失敗を出す" "yes" "$(has "$(frame)" '⚠️ gh で Issue と PR を取得できません')"

# ---- できごと ----
setup
echo "[$(repo)]" > "$cache"
event "$(at '2026-11-18 14:00:00')" my-app start '#14 に着手'
event "$(at '2026-11-18 15:00:00')" my-app pr '#36 🤖 [add] 一覧を足す'
event "$(at '2026-11-17 10:00:00')" other fail '#3: 止まりました'
out=$(frame)
assert_eq "できごとに時刻・略称・種類の絵文字・本文を出す" "yes" "$(has "$out" '15:00 app 🔀 #36 🤖 [add] 一覧を足す')"
assert_eq "今日でないできごとは日付を出す" "yes" "$(has "$out" '11/17 oth ⚠️ #3: 止まりました')"
assert_eq "できごとは新しいものが上" "15:00,14:00,11/17" "$(sed -n '/できごと/,$p' <<< "$out" | grep -oE '^[0-9]{2}[:/][0-9]{2}' | paste -sd, -)"

setup
echo "[$(repo)]" > "$cache"
event "$now" my-app pr "#36 $(printf 'あ%.0s' $(seq 1 60))"
line=$(frame | grep '#36')
width=$(printf '%s' "$line" | perl -CS -ne 'my $w = 0; $w += /[\x{1100}-\x{FFFF}]/ ? 2 : 1 for split //; print $w')
assert_eq "長いできごとはペインの幅で切る" "yes" "$([ "$width" -le 60 ] && echo yes || echo no)"

setup
echo "[$(repo)]" > "$cache"
for i in $(seq 1 100); do event "$((now - 1000 + i))" my-app start "#$i に着手"; done
assert_eq "できごとはペインの高さに収まる分だけ出す" "yes" "$([ "$(frame | wc -l)" -le 40 ] && echo yes || echo no)"

# ---- ペインの枠 ----
setup
echo "[$(repo '.decisions = [{number: 15}]')]" > "$cache"
TMUX_PANE=%9 frame >/dev/null
assert_eq "判断待ちがあれば、ペインを待機中（赤い枠）にする" "yes" "$(has "$(cat "$FAKE_LOG")" 'tmux set -p -t %9 @claude_state waiting')"

setup
echo "[$(repo)]" > "$cache"
TMUX_PANE=%9 frame >/dev/null
assert_eq "何もなければ、ペインの待機中を外す" "yes" "$(has "$(cat "$FAKE_LOG")" 'tmux set -p -t %9 -u @claude_state')"
assert_eq "自分のペインに印を付ける（C-q + M で閉じるため）" "yes" "$(has "$(cat "$FAKE_LOG")" 'tmux set -p -t %9 @auto_dev_watch 1')"

# ---- C-q + M で開け閉めする ----
setup
FAKE_PANES=$'%1 \n%2 \n' "$bin/claude-auto-dev-watch" --toggle
assert_eq "監視のペインがなければ、右下のペインを左右に割って開く" "yes" "$(has "$(cat "$FAKE_LOG")" "tmux split-window -d -h -l 60 -t {bottom-right} $bin/claude-auto-dev-watch")"

setup
FAKE_PANES=$'%1 \n%7 1\n' "$bin/claude-auto-dev-watch" --toggle
assert_eq "監視のペインがあれば閉じる" "yes" "$(has "$(cat "$FAKE_LOG")" 'tmux kill-pane -t %7')"
assert_eq "閉じるときは新しく開かない" "no" "$(has "$(cat "$FAKE_LOG")" 'split-window')"

[ "$failures" -eq 0 ] || exit 1
