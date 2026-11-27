#!/bin/bash
# bin/claude-skill-install のテスト。実行: tests/claude-skill-install.test.sh
# ネットワークは使わず、手元に作った Git リポジトリを取得元にする

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

# 取得元のリポジトリを作る。1つ目のコミットには old.txt があり、2つ目のコミットで消える
setup() {
  tmp=$(mktemp -d "$tmp_root/XXXXXX")
  src="$tmp/src"
  export CLAUDE_SKILLS_DIR="$tmp/skills"
  mkdir -p "$src/skills/demo"
  git -C "$src" init -q
  # コミットを指定した取得を、手元のリポジトリでも許す（GitHub は初めから許している）
  git -C "$src" config uploadpack.allowAnySHA1InWant true
  echo v1 > "$src/skills/demo/SKILL.md"
  echo old > "$src/skills/demo/old.txt"
  echo readme > "$src/README.md"
  commit "1つ目"
  first=$(git -C "$src" rev-parse HEAD)
  echo v2 > "$src/skills/demo/SKILL.md"
  rm "$src/skills/demo/old.txt"
  commit "2つ目"
  second=$(git -C "$src" rev-parse HEAD)
  url="file://$src"
}

commit() {
  git -C "$src" add -A
  git -C "$src" -c user.name=test -c user.email=test@example.com commit -q -m "$1"
}

install() {
  "$bin/claude-skill-install" "$@" >/dev/null 2>&1
  echo $?
}

# 指定したコミットの、指定したフォルダの中身だけを置く
setup
assert_eq "新しく置くと 0 で終わる" "0" "$(install demo "$url" "$first" skills/demo)"
assert_eq "指定したコミットの中身が置かれる" "v1" "$(cat "$CLAUDE_SKILLS_DIR/demo/SKILL.md")"
assert_eq "フォルダの外のファイルは置かない" "no" "$([ -e "$CLAUDE_SKILLS_DIR/demo/README.md" ] && echo yes || echo no)"
assert_eq "置いたコミットを記録する" "$first" "$(cat "$CLAUDE_SKILLS_DIR/demo/.source-commit")"

# 同じコミットがもう置いてあれば、取得しない（取得元がなくなっていても成功する）
setup
install demo "$url" "$first" skills/demo >/dev/null
rm -rf "$src"
assert_eq "同じコミットなら取得せずに 0 で終わる" "0" "$(install demo "$url" "$first" skills/demo)"
assert_eq "同じコミットなら中身はそのまま" "v1" "$(cat "$CLAUDE_SKILLS_DIR/demo/SKILL.md")"

# コミットを変えたら、中身をまるごと入れ替える
setup
install demo "$url" "$first" skills/demo >/dev/null
assert_eq "コミットを変えると 0 で終わる" "0" "$(install demo "$url" "$second" skills/demo)"
assert_eq "新しいコミットの中身になる" "v2" "$(cat "$CLAUDE_SKILLS_DIR/demo/SKILL.md")"
assert_eq "新しいコミットにないファイルは残らない" "no" "$([ -e "$CLAUDE_SKILLS_DIR/demo/old.txt" ] && echo yes || echo no)"
assert_eq "記録が新しいコミットになる" "$second" "$(cat "$CLAUDE_SKILLS_DIR/demo/.source-commit")"

# このスクリプトが置いたのではないフォルダは、消さない
setup
mkdir -p "$CLAUDE_SKILLS_DIR/demo"
echo mine > "$CLAUDE_SKILLS_DIR/demo/SKILL.md"
assert_eq "記録のないフォルダがあれば 1 で終わる" "1" "$(install demo "$url" "$first" skills/demo)"
assert_eq "記録のないフォルダはそのまま" "mine" "$(cat "$CLAUDE_SKILLS_DIR/demo/SKILL.md")"

# 取得に失敗したら、前の中身を残す
setup
install demo "$url" "$first" skills/demo >/dev/null
assert_eq "ないコミットを指定すると 1 で終わる" "1" "$(install demo "$url" 0000000000000000000000000000000000000000 skills/demo)"
assert_eq "取得に失敗したら前の中身のまま" "v1" "$(cat "$CLAUDE_SKILLS_DIR/demo/SKILL.md")"
assert_eq "取得に失敗したら記録も前のまま" "$first" "$(cat "$CLAUDE_SKILLS_DIR/demo/.source-commit")"

# リポジトリにないフォルダを指定したら、何も置かない
setup
assert_eq "ないフォルダを指定すると 1 で終わる" "1" "$(install demo "$url" "$first" skills/none)"
assert_eq "ないフォルダを指定したら何も置かない" "no" "$([ -e "$CLAUDE_SKILLS_DIR/demo" ] && echo yes || echo no)"

# 引数が足りなければ、何もしない
setup
assert_eq "引数が足りなければ 2 で終わる" "2" "$(install demo "$url" "$first")"

# --check は、置いてあるコミットが指定と同じかだけを見る（取得しない）
setup
assert_eq "置いていなければ --check は 1" "1" "$(install --check demo "$first")"
install demo "$url" "$first" skills/demo >/dev/null
assert_eq "同じコミットなら --check は 0" "0" "$(install --check demo "$first")"
assert_eq "違うコミットなら --check は 1" "1" "$(install --check demo "$second")"

if [ "$failures" -ne 0 ]; then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
