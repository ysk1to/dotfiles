#!/bin/bash
# bin/claude-auto-dev のテスト。実行: tests/claude-auto-dev.test.sh
# claude・gh・osascript は偽物に差し替え、呼ばれ方を記録して確かめる。

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

# 偽のリモート（main に1コミット）と、それを clone した作業用のリポジトリを作る
setup() {
  tmp=$(mktemp -d)
  export CLAUDE_AUTO_DEV_CONFIG_DIR="$tmp/config"
  export CLAUDE_AUTO_DEV_STATE_DIR="$tmp/state"
  export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
  export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
  git init -q --bare -b main "$tmp/origin.git"
  git clone -q "$tmp/origin.git" "$tmp/seed" 2>/dev/null
  (cd "$tmp/seed" && echo hello > README.md && git add README.md && git commit -qm init && git push -q origin main)
  git clone -q "$tmp/origin.git" "$tmp/my-app"
  repo="$tmp/my-app"
  mkdir -p "$CLAUDE_AUTO_DEV_CONFIG_DIR"
  echo "Notion のページ: https://example.com/notion" > "$CLAUDE_AUTO_DEV_CONFIG_DIR/my-app.md"
  fake_bin
}

# 偽の claude・gh・osascript。gh は FAKE_ISSUES・FAKE_PRS の JSON を返す。
# claude は FAKE_CLAUDE_BRANCH のブランチを作り、FAKE_CLAUDE_COMMIT=1 ならコミットし、
# FAKE_PR_TEXT があれば PR のファイルに書く
fake_bin() {
  mkdir -p "$tmp/bin"
  export PATH="$tmp/bin:$PATH" FAKE_LOG="$tmp/fake.log"
  export FAKE_ISSUES='[{"number":1,"labels":[{"name":"auto-ready"}]}]' FAKE_PRS='[]' FAKE_CLAUDE_EXIT=0
  export FAKE_CLAUDE_BRANCH=auto-1-test FAKE_CLAUDE_COMMIT=0 FAKE_PR_TEXT=
  cat > "$tmp/bin/claude" <<'EOF'
#!/bin/bash
{ echo "claude pwd=$PWD"; echo "claude head=$(git rev-parse HEAD)"; printf 'claude arg=%s\n' "$@"; } >> "$FAKE_LOG"
git switch -q -c "$FAKE_CLAUDE_BRANCH"
if [ "$FAKE_CLAUDE_COMMIT" = 1 ]; then echo change >> README.md && git commit -qam change; fi
[ -z "$FAKE_PR_TEXT" ] || printf '%s\n' "$FAKE_PR_TEXT" > "$CLAUDE_AUTO_DEV_PR_FILE"
echo "PR を作りました"
exit "$FAKE_CLAUDE_EXIT"
EOF
  cat > "$tmp/bin/gh" <<'EOF'
#!/bin/bash
case "$1 $2" in
  "issue list") echo "$FAKE_ISSUES" ;;
  "pr list") echo "$FAKE_PRS" ;;
  "pr create") printf 'gh pr create arg=%s\n' "$@" >> "$FAKE_LOG"; sed 's/^/gh pr create body=/' >> "$FAKE_LOG" ;;
esac
EOF
  cat > "$tmp/bin/osascript" <<'EOF'
#!/bin/bash
echo "osascript $*" >> "$FAKE_LOG"
EOF
  chmod +x "$tmp/bin/"*
}

claude_calls() {
  if [ -f "$FAKE_LOG" ]; then grep -c '^claude pwd=' "$FAKE_LOG"; else echo 0; fi
}

# 設定ファイルがなければ、何もせずに失敗する
setup
rm "$CLAUDE_AUTO_DEV_CONFIG_DIR/my-app.md"
out=$("$bin/claude-auto-dev" "$repo" 2>&1)
assert_eq "設定ファイルがなければ失敗する" "1" "$?"
assert_eq "設定ファイルの場所を伝える" "yes" "$(echo "$out" | grep -q "my-app.md" && echo yes || echo no)"
assert_eq "設定ファイルがなければ claude を起動しない" "0" "$(claude_calls)"

# auto-ready の Issue があれば、origin/main の worktree で claude を起動する
setup
(cd "$tmp/seed" && echo more >> README.md && git commit -qam second && git push -q origin main)
main_sha=$(git -C "$tmp/seed" rev-parse HEAD)
"$bin/claude-auto-dev" "$repo" >/dev/null 2>&1
assert_eq "Issue があれば成功する" "0" "$?"
assert_eq "Issue があれば claude を1回起動する" "1" "$(claude_calls)"
assert_eq "origin/main の最新で起動する（手元の clone は古いまま）" "$main_sha" "$(grep '^claude head=' "$FAKE_LOG" | cut -d= -f2)"
assert_eq "手元のリポジトリの外の worktree で起動する" "no" "$(grep '^claude pwd=' "$FAKE_LOG" | grep -q "^claude pwd=$repo\$" && echo yes || echo no)"
prompt=$(sed -n '/^claude arg=-p$/{n;p;}' "$FAKE_LOG")
assert_eq "プロンプトで手順のファイルを読ませる" "yes" "$(echo "$prompt" | grep -q '.claude/auto-dev.md' && echo yes || echo no)"
assert_eq "プロンプトに設定ファイルの中身を入れる" "yes" "$(grep -q 'https://example.com/notion' "$FAKE_LOG" && echo yes || echo no)"

# やることがない回は、claude を起動しない（使用量を消費しない）
setup
FAKE_ISSUES='[]' "$bin/claude-auto-dev" "$repo" >/dev/null 2>&1
assert_eq "Issue がなくても成功する" "0" "$?"
assert_eq "Issue がなければ claude を起動しない" "0" "$(claude_calls)"
assert_eq "Issue がなければ worktree を作らない" "1" "$(git -C "$repo" worktree list | wc -l | tr -d ' ')"

setup
FAKE_ISSUES='[{"number":1,"labels":[{"name":"auto-ready"},{"name":"needs-decision"}]},{"number":2,"labels":[{"name":"auto-ready"},{"name":"auto-in-progress"}]}]' \
  "$bin/claude-auto-dev" "$repo" >/dev/null 2>&1
assert_eq "判断待ちと作業中の Issue だけなら claude を起動しない" "0" "$(claude_calls)"

setup
FAKE_PRS='[{"number":10},{"number":11}]' "$bin/claude-auto-dev" "$repo" >/dev/null 2>&1
assert_eq "auto-dev の PR が2件あれば claude を起動しない" "0" "$(claude_calls)"

setup
FAKE_PRS='[{"number":10}]' "$bin/claude-auto-dev" "$repo" >/dev/null 2>&1
assert_eq "auto-dev の PR が1件なら claude を起動する" "1" "$(claude_calls)"

# 終わったら worktree と、claude が作った手元のブランチを片付ける
setup
"$bin/claude-auto-dev" "$repo" >/dev/null 2>&1
assert_eq "終わったら worktree を消す" "1" "$(git -C "$repo" worktree list | wc -l | tr -d ' ')"
assert_eq "claude が作った手元のブランチを消す" "" "$(git -C "$repo" branch --list 'auto-*')"
"$bin/claude-auto-dev" "$repo" >/dev/null 2>&1
assert_eq "続けてもう1回動かせる" "0" "$?"
assert_eq "2回目も claude を起動する" "2" "$(claude_calls)"

# claude が本人の既存のブランチに切り替えても、そのブランチは消さない
setup
git -C "$repo" branch feature
cat > "$tmp/bin/claude" <<'EOF'
#!/bin/bash
echo "claude pwd=$PWD" >> "$FAKE_LOG"
git switch -q feature
EOF
"$bin/claude-auto-dev" "$repo" >/dev/null 2>&1
assert_eq "auto- で始まらないブランチは消さない" "feature" "$(git -C "$repo" branch --list feature | tr -d ' *+')"

# 前の回がまだ動いていれば、何もしない
setup
mkdir -p "$CLAUDE_AUTO_DEV_STATE_DIR/locks/my-app"
sleep 30 &
running=$!
echo "$running" > "$CLAUDE_AUTO_DEV_STATE_DIR/locks/my-app/pid"
"$bin/claude-auto-dev" "$repo" >/dev/null 2>&1
assert_eq "前の回が動いていれば成功として終わる" "0" "$?"
assert_eq "前の回が動いていれば claude を起動しない" "0" "$(claude_calls)"
kill "$running"
wait "$running" 2>/dev/null

# 前の回が落ちてロックだけ残っていれば、引き継いで動く
"$bin/claude-auto-dev" "$repo" >/dev/null 2>&1
assert_eq "残ったロックを引き継いで claude を起動する" "1" "$(claude_calls)"
assert_eq "終わったらロックを外す" "no" "$([ -e "$CLAUDE_AUTO_DEV_STATE_DIR/locks/my-app" ] && echo yes || echo no)"

# claude の出力はログに残し、成功したら通知しない
setup
"$bin/claude-auto-dev" "$repo" >/dev/null 2>&1
assert_eq "claude の出力をログに残す" "yes" "$(cat "$CLAUDE_AUTO_DEV_STATE_DIR"/logs/my-app-*.log 2>/dev/null | grep -q 'PR を作りました' && echo yes || echo no)"
assert_eq "成功したら通知しない" "0" "$(grep -c '^osascript' "$FAKE_LOG")"

# claude が失敗したら、通知して失敗で終わる。片付けはする
setup
FAKE_CLAUDE_EXIT=3 "$bin/claude-auto-dev" "$repo" >/dev/null 2>&1
assert_eq "claude が失敗したら失敗で終わる" "3" "$?"
assert_eq "失敗したら通知する" "1" "$(grep -c '^osascript' "$FAKE_LOG")"
assert_eq "通知にリポジトリ名を入れる" "yes" "$(grep '^osascript' "$FAKE_LOG" | grep -q 'my-app' && echo yes || echo no)"
assert_eq "失敗しても worktree を消す" "1" "$(git -C "$repo" worktree list | wc -l | tr -d ' ')"

# claude に渡したオプションのうち、flag の後ろに続く値（次の -- まで）を1行ずつ出す
args_after() {
  awk -v flag="claude arg=$1" '
    $0 == flag { on = 1; next }
    on && /^claude arg=--/ { on = 0 }
    on && /^claude arg=/ { sub(/^claude arg=/, ""); print }
  ' "$FAKE_LOG"
}
has_line() {
  if printf '%s\n' "$1" | grep -qxF -- "$2"; then echo yes; else echo no; fi
}

# モデルと1回の上限を渡す。既定は Opus、環境変数で変えられる
setup
"$bin/claude-auto-dev" "$repo" >/dev/null 2>&1
assert_eq "既定のモデルは opus" "opus" "$(args_after --model)"
assert_eq "1回のターン数に上限をかける" "yes" "$([ -n "$(args_after --max-turns)" ] && echo yes || echo no)"
setup
CLAUDE_AUTO_DEV_MODEL=sonnet CLAUDE_AUTO_DEV_MAX_TURNS=30 "$bin/claude-auto-dev" "$repo" >/dev/null 2>&1
assert_eq "モデルを環境変数で変えられる" "sonnet" "$(args_after --model)"
assert_eq "ターン数の上限を環境変数で変えられる" "30" "$(args_after --max-turns)"

# 使ってよいツールを絞る。マージと force push は禁止する
setup
printf '%s\n' 'Bash(go test:*)' 'Bash(npm run test:unit)' > "$CLAUDE_AUTO_DEV_CONFIG_DIR/my-app.tools"
"$bin/claude-auto-dev" "$repo" >/dev/null 2>&1
allowed=$(args_after --allowedTools)
disallowed=$(args_after --disallowedTools)
assert_eq "Notion を読める" "yes" "$(has_line "$allowed" 'mcp__claude_ai_Notion__notion-fetch')"
assert_eq "Todoist に登録できる" "yes" "$(has_line "$allowed" 'mcp__claude_ai_Todoist__add-tasks')"
assert_eq "リポジトリごとのツールを足せる" "yes" "$(has_line "$allowed" 'Bash(npm run test:unit)')"
assert_eq "PR のマージを禁止する" "yes" "$(has_line "$disallowed" 'Bash(gh pr merge:*)')"
assert_eq "プロンプトは先頭に渡す（後ろのオプションに飲み込まれない）" "yes" "$(sed -n '2p;3p' "$FAKE_LOG" | grep -q '^claude arg=-p$' && echo yes || echo no)"

# push と PR の作成は claude に許さず、起動スクリプトが行う（push 先を auto- のブランチに限るため）
work="$CLAUDE_AUTO_DEV_STATE_DIR/worktrees/my-app"
assert_eq "claude には push を許さない" "no" "$(printf '%s\n' "$allowed" | grep -q '^Bash(git push' && echo yes || echo no)"
assert_eq "claude には PR の作成を許さない" "no" "$(has_line "$allowed" 'Bash(gh pr create:*)')"
assert_eq "push を禁止する" "yes" "$(has_line "$disallowed" 'Bash(git push:*)')"
assert_eq "PR の作成を禁止する" "yes" "$(has_line "$disallowed" 'Bash(gh pr create:*)')"
assert_eq "ファイルの編集は worktree の中に限る" "yes" "$(has_line "$allowed" "Edit(/$work/**)")"
assert_eq "パスを絞らない Edit は許さない" "no" "$(has_line "$allowed" 'Edit')"
assert_eq "パスを絞らない Write は許さない" "no" "$(has_line "$allowed" 'Write')"

# claude がコミットして PR のファイルを書いたら、スクリプトが push して PR を作る
setup
FAKE_CLAUDE_COMMIT=1 FAKE_PR_TEXT=$'🤖 [fix] 直した\n## 概要\n直した内容' "$bin/claude-auto-dev" "$repo" >/dev/null 2>&1
assert_eq "PR にするときも成功する" "0" "$?"
assert_eq "auto- のブランチをリモートに push する" "yes" "$(git -C "$tmp/origin.git" rev-parse -q --verify refs/heads/auto-1-test >/dev/null && echo yes || echo no)"
assert_eq "main には push しない" "$(git -C "$tmp/seed" rev-parse HEAD)" "$(git -C "$tmp/origin.git" rev-parse refs/heads/main)"
pr_args=$(sed -n 's/^gh pr create arg=//p' "$FAKE_LOG")
assert_eq "PR の元のブランチを指定する" "yes" "$(printf '%s\n' "$pr_args" | grep -qxF 'auto-1-test' && echo yes || echo no)"
assert_eq "PR に auto-dev ラベルを付ける" "yes" "$(printf '%s\n' "$pr_args" | grep -qxF 'auto-dev' && echo yes || echo no)"
assert_eq "ファイルの1行目を PR のタイトルにする" "yes" "$(printf '%s\n' "$pr_args" | grep -qxF '🤖 [fix] 直した' && echo yes || echo no)"
assert_eq "ファイルの2行目以降を PR の本文にする" "## 概要
直した内容" "$(sed -n 's/^gh pr create body=//p' "$FAKE_LOG")"
assert_eq "プロンプトで PR のファイルの場所を伝える" "yes" "$(grep -qF "$CLAUDE_AUTO_DEV_STATE_DIR/pr/my-app.md" "$FAKE_LOG" && echo yes || echo no)"
assert_eq "PR のファイルは書けるようにする" "yes" "$(has_line "$(args_after --allowedTools)" "Edit(/$CLAUDE_AUTO_DEV_STATE_DIR/pr/my-app.md)")"
assert_eq "PR を作ったらファイルを消す" "no" "$([ -e "$CLAUDE_AUTO_DEV_STATE_DIR/pr/my-app.md" ] && echo yes || echo no)"

# PR のファイルがなければ（判断待ちで止まったなど）、push しない
setup
FAKE_CLAUDE_COMMIT=1 "$bin/claude-auto-dev" "$repo" >/dev/null 2>&1
assert_eq "PR のファイルがなければ push しない" "no" "$(git -C "$tmp/origin.git" rev-parse -q --verify refs/heads/auto-1-test >/dev/null && echo yes || echo no)"
assert_eq "PR のファイルがなければ PR を作らない" "0" "$(grep -c '^gh pr create' "$FAKE_LOG")"

# claude が失敗したら、PR のファイルがあっても push しない
setup
FAKE_CLAUDE_EXIT=1 FAKE_CLAUDE_COMMIT=1 FAKE_PR_TEXT=$'タイトル\n本文' "$bin/claude-auto-dev" "$repo" >/dev/null 2>&1
assert_eq "claude が失敗したら push しない" "no" "$(git -C "$tmp/origin.git" rev-parse -q --verify refs/heads/auto-1-test >/dev/null && echo yes || echo no)"

# auto- で始まらないブランチや、コミットのないブランチは PR にせず、失敗として知らせる
setup
FAKE_CLAUDE_BRANCH=feature FAKE_CLAUDE_COMMIT=1 FAKE_PR_TEXT=$'タイトル\n本文' "$bin/claude-auto-dev" "$repo" >/dev/null 2>&1
assert_eq "auto- で始まらないブランチは失敗で終わる" "1" "$?"
assert_eq "auto- で始まらないブランチは push しない" "no" "$(git -C "$tmp/origin.git" rev-parse -q --verify refs/heads/feature >/dev/null && echo yes || echo no)"
assert_eq "auto- で始まらないブランチは通知する" "1" "$(grep -c '^osascript' "$FAKE_LOG")"
setup
FAKE_PR_TEXT=$'タイトル\n本文' "$bin/claude-auto-dev" "$repo" >/dev/null 2>&1
assert_eq "コミットがなければ失敗で終わる" "1" "$?"
assert_eq "コミットがなければ PR を作らない" "0" "$(grep -c '^gh pr create' "$FAKE_LOG")"

[ "$failures" -eq 0 ] || exit 1
