#!/bin/bash
# claude/skills/ のスキルの形のテスト。実行: tests/claude-skills.test.sh
# 各スキルの SKILL.md に frontmatter があり、name がディレクトリ名と同じで、description が空でないことを確かめる。
# Bot は frontmatter を除いて読み、対話は frontmatter でスキルを見つけるので、形が崩れるとどちらも動かないため

cd "$(dirname "$0")/.." || exit 1
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

# frontmatter（1行目の --- から次の --- まで）の中の、キーの値を出す。frontmatter がなければ何も出さない
frontmatter_value() {
  awk -v key="$2" -v q="'" '
    NR == 1 { if ($0 != "---") exit; next }
    $0 == "---" { exit }
    index($0, key ":") == 1 {
      v = substr($0, length(key) + 2)
      gsub(/^[ \t]+|[ \t]+$/, "", v)
      if (v ~ /^".*"$/ || (substr(v, 1, 1) == q && substr(v, length(v)) == q && length(v) > 1)) v = substr(v, 2, length(v) - 2)
      print v
      exit
    }
  ' "$1"
}

# スキルのディレクトリを1つ確かめ、問題を1行1つで出す。問題がなければ何も出さない
check_skill() {
  local dir=$1 file="$1/SKILL.md" name
  name=$(basename "$dir")
  if [ ! -f "$file" ]; then
    echo "SKILL.md がない"
    return
  fi
  if [ "$(head -n 1 "$file")" != "---" ] || [ "$(tail -n +2 "$file" | grep -c '^---$')" -eq 0 ]; then
    echo "frontmatter がない"
    return
  fi
  [ "$(frontmatter_value "$file" name)" = "$name" ] || echo "name がディレクトリ名（${name}）と違う"
  [ -n "$(frontmatter_value "$file" description)" ] || echo "description が空"
}

# 確かめ方そのものが、崩れた形を見つけられること
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
make_skill() {
  mkdir -p "$tmp/$1"
  printf '%b' "$2" > "$tmp/$1/SKILL.md"
}
make_skill good '---\nname: good\ndescription: "使う"\n---\n\n# 本文\n'
assert_eq "正しい形なら問題なし" "" "$(check_skill "$tmp/good")"
mkdir -p "$tmp/missing"
assert_eq "SKILL.md がなければ見つける" "SKILL.md がない" "$(check_skill "$tmp/missing")"
make_skill nofm '# 本文だけ\n'
assert_eq "frontmatter がなければ見つける" "frontmatter がない" "$(check_skill "$tmp/nofm")"
make_skill unclosed '---\nname: unclosed\ndescription: 使う\n'
assert_eq "frontmatter が閉じていなければ見つける" "frontmatter がない" "$(check_skill "$tmp/unclosed")"
make_skill other '---\nname: another\ndescription: 使う\n---\n'
assert_eq "name の違いを見つける" "name がディレクトリ名（other）と違う" "$(check_skill "$tmp/other")"
make_skill nodesc '---\nname: nodesc\ndescription:\n---\ndescription: 本文の中の行は見ない\n'
assert_eq "空の description を見つける" "description が空" "$(check_skill "$tmp/nodesc")"

# リポジトリのスキルのすべて
for dir in claude/skills/*/; do
  dir=${dir%/}
  assert_eq "$dir の形" "" "$(check_skill "$dir")"
done

# 案や記録を書く役割の手順に、応答を分けて書く決まりがあること。
# 1回の応答（考える時間と書く時間の合計）が5分を超えると、プロンプトキャッシュが切れて、文脈の全部を作り直すため
assert_rule() {
  assert_eq "$1 に、応答を分けて書く決まりがある" "1" "$(grep -c "$2" "$1")"
}
assert_rule claude/skills/planner/SKILL.md '^- Claude: 案のファイルは、応答を分けて書く。読んで考えたあとの最初の応答では1本だけ書き、そのあとは1回の応答で2本までにする'
assert_rule claude/skills/researcher/ideas.md '^- Claude: 案のファイルは、1回の応答で 2〜3本までにする'
assert_rule claude/skills/researcher/judge.md '^- Claude: 結果と記録は、応答を分けて書く。審査を終えたあとの最初の応答では `rejected.md` だけを書き'

if [ "$failures" -ne 0 ]; then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
