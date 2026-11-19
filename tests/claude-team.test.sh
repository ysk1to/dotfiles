#!/bin/bash
# bin/claude-team のテスト。実行: tests/claude-team.test.sh
# tmux は偽物に差し替え、呼ばれ方を記録する。セッションとウィンドウの有無は環境変数で決める。

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
count() { grep -cF -- "$2" <<< "$1"; }

setup() {
  tmp=$(mktemp -d)
  repo="$tmp/Program/private/my.app"
  mkdir -p "$repo" "$tmp/bin"
  export HOME="$tmp" PATH="$tmp/bin:$PATH" FAKE_LOG="$tmp/fake.log" TMUX=
  # FAKE_SESSION=1 で共通のセッションがある状態、FAKE_WINDOWS にそのウィンドウ名を改行区切りで入れる
  export FAKE_SESSION= FAKE_WINDOWS=
  cat > "$tmp/bin/tmux" <<'EOF'
#!/bin/bash
echo "tmux $*" >> "$FAKE_LOG"
case "$1" in
  has-session) [ -n "$FAKE_SESSION" ] ;;
  list-windows) printf '%s' "$FAKE_WINDOWS" ;;
  new-session|new-window) echo %1 ;;
  # 割るたびに %2・%3 と別のペインを返す
  split-window) n=$(($(cat "$FAKE_LOG.split" 2>/dev/null || echo 1) + 1)); echo "$n" > "$FAKE_LOG.split"; echo "%$n" ;;
esac
EOF
  chmod +x "$tmp/bin/tmux"
}
run() { "$bin/claude-team" "$@" > /dev/null 2>&1; cat "$FAKE_LOG"; }

# ---- 共通のセッションがないとき ----
setup
out=$(run private/my.app)
assert_eq "共通のセッションを、リポジトリ名のウィンドウで作る" "yes" "$(has "$out" "tmux new-session -d -s claude -n my_app -c $repo")"
assert_eq "ペインを2回割って3ペインにする" "2" "$(count "$out" 'tmux split-window')"
assert_eq "上の2つのペインで claude を起動する" "2" "$(count "$out" 'claude Enter')"
assert_eq "右下のペインは claude を起動しない" "no" "$(has "$out" 'tmux send-keys -t %3 claude Enter')"
assert_eq "右下のペインで本人待ちの一覧を起動する" "yes" "$(has "$out" 'tmux send-keys -t %3 claude-auto-dev-inbox Enter')"
assert_eq "右下のペインの名前は Inbox" "yes" "$(has "$out" 'tmux select-pane -t %3 -T Inbox')"
assert_eq "tmux の外からはアタッチする" "yes" "$(has "$out" 'tmux attach -t =claude')"

# ---- 共通のセッションはあり、そのリポジトリのウィンドウがないとき ----
setup
export FAKE_SESSION=1 FAKE_WINDOWS=$'other\n'
out=$(run private/my.app)
assert_eq "セッションは作らない" "no" "$(has "$out" 'tmux new-session')"
assert_eq "ウィンドウを足す" "yes" "$(has "$out" "tmux new-window -d -t =claude: -n my_app -c $repo")"
assert_eq "足したウィンドウを選ぶ" "yes" "$(has "$out" 'tmux select-window -t =claude:=my_app')"
assert_eq "上の2つのペインで claude を起動する" "2" "$(count "$out" 'claude Enter')"

# ---- そのリポジトリのウィンドウがすでにあるとき ----
setup
export FAKE_SESSION=1 FAKE_WINDOWS=$'other\nmy_app\n'
out=$(run private/my.app)
assert_eq "ウィンドウは作らない" "no" "$(has "$out" 'tmux new-window')"
assert_eq "ペインも割らない" "0" "$(count "$out" 'tmux split-window')"
assert_eq "あるウィンドウを選ぶ" "yes" "$(has "$out" 'tmux select-window -t =claude:=my_app')"

# ---- 名前の一部が同じウィンドウは、別のものとして扱う ----
setup
export FAKE_SESSION=1 FAKE_WINDOWS=$'my_app2\n'
out=$(run private/my.app)
assert_eq "my_app2 があっても my_app を足す" "yes" "$(has "$out" 'tmux new-window -d -t =claude: -n my_app')"

# ---- 引数 ----
setup
out=$(run private/my.app work:2)
assert_eq "2つめの引数をウィンドウ名にする（. と : は _ に）" "yes" "$(has "$out" "-n work_2 -c $repo")"

setup
out=$(cd "$repo" && run)
assert_eq "ディレクトリを省くとカレントディレクトリ" "yes" "$(has "$out" "-n my_app -c $repo")"

setup
"$bin/claude-team" private/none > /dev/null 2>&1
assert_eq "ディレクトリがなければ失敗する" "1" "$?"

# ---- tmux の中から ----
setup
export TMUX=/tmp/tmux-test,1,0
out=$(run private/my.app)
assert_eq "tmux の中からは switch-client で移る" "yes" "$(has "$out" 'tmux switch-client -t =claude')"
assert_eq "tmux の中からはアタッチしない" "no" "$(has "$out" 'tmux attach')"

[ "$failures" -eq 0 ] || { echo "$failures 件失敗"; exit 1; }
echo "すべて成功"
