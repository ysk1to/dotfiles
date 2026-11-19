#!/bin/bash
# bin/claude-auto-dev-inbox のテスト。実行: tests/claude-auto-dev-inbox.test.sh
# 状況のキャッシュとリポジトリは一時ディレクトリに作る。

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

setup() {
  tmp=$(mktemp -d)
  cache="$tmp/claude-auto-dev-status.json"
  export XDG_CACHE_HOME="$tmp" CLAUDE_AUTO_DEV_STATE_DIR="$tmp/state" CLAUDE_AUTO_DEV_NOW="$now" COLUMNS=60
  export TMUX_AUTO_DEV_STATUS=/usr/bin/true TMUX_AUTO_DEV_TTL=100000
  # リポジトリ2つ。my-app は GitHub の origin を持ち、other は origin がない
  git init -q "$tmp/my-app"
  git -C "$tmp/my-app" remote add origin git@github.com:someone/my-app.git
  git init -q "$tmp/other"
  echo '[]' > "$cache"
}
# リポジトリ1つ分の集計。1つめの引数が名前、2つめの jq の式で項目を上書きする
repo() {
  jq -cn --arg name "$1" --arg repo "$tmp/$1" "{name: \$name, label: \$name[0:3], repo: \$repo, decisions: [], prs: []} | ${2:-.}"
}
cache() { jq -cs . > "$cache"; }
frame() { "$bin/claude-auto-dev-inbox" --once "$@" 2>&1; }

# ---- 状況がないとき ----
setup
assert_eq "リポジトリがなければ、そう伝える" "yes" "$(has "$(frame)" 'まだ動いていません')"

# ---- 絞ったリポジトリは、番号・タイトル・URL まで出す ----
setup
{
  repo my-app '.decisions = [{number: 32, title: "規約の扱いを決める"}, {number: 26, title: "システムを見分ける"}]
    | .prs = [{number: 40, title: "一覧を足す", labels: ["no-auto-merge"]}]'
  repo other '.decisions = [{number: 5, title: "ほかの判断"}] | .prs = [{number: 7, title: "ほかの PR", labels: []}]'
} | cache
out=$(frame --repo my-app)
assert_eq "見出しに時刻を出す" "本人待ち  16:30" "$(head -1 <<< "$out")"
assert_eq "判断待ちの件数を出す" "yes" "$(has "$out" '🙋 判断待ち 2')"
assert_eq "判断待ちの番号とタイトルを出す" "yes" "$(has "$out" '#32 規約の扱いを決める')"
assert_eq "判断待ちの Issue の URL を出す" "yes" "$(has "$out" 'https://github.com/someone/my-app/issues/32')"
assert_eq "開いている PR の件数を出す" "yes" "$(has "$out" '🔀 開いている PR 1')"
assert_eq "PR のタイトルにラベルを添える" "yes" "$(has "$out" '#40 一覧を足す（no-auto-merge）')"
assert_eq "PR の URL を出す" "yes" "$(has "$out" 'https://github.com/someone/my-app/pull/40')"
assert_eq "絞ったリポジトリを先に出す" "my- my-app" "$(sed -n 3p <<< "$out")"

# ---- ほかのリポジトリは、1行に番号だけを出す ----
assert_eq "ほかのリポジトリは番号だけを1行で出す" "yes" "$(has "$out" '  oth  🙋 #5   🔀 #7')"
assert_eq "ほかのリポジトリのタイトルは出さない" "no" "$(has "$out" 'ほかの判断')"

# ---- 待ちがないとき ----
setup
{ repo my-app; repo other; } | cache
out=$(frame --repo my-app)
assert_eq "判断待ちがなければ、なしと出す" "yes" "$(has "$out" '🙋 判断待ち なし')"
assert_eq "開いている PR がなければ、なしと出す" "yes" "$(has "$out" '🔀 開いている PR なし')"
assert_eq "ほかのリポジトリに待ちがなければ ✓ を出す" "yes" "$(has "$out" '  oth  ✓')"

# ---- リポジトリの決め方 ----
setup
{ repo my-app '.decisions = [{number: 32, title: "規約の扱いを決める"}]'; repo other '.decisions = [{number: 5, title: "ほかの判断"}]'; } | cache
git -C "$tmp/other" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m init
git -C "$tmp/other" worktree add -q "$tmp/other-wt" -b wt
assert_eq "--repo を省くと、今のディレクトリのリポジトリに絞る" "yes" "$(has "$(cd "$tmp/my-app" && frame)" '#32 規約の扱いを決める')"
assert_eq "今のリポジトリでないものは1行にする" "no" "$(has "$(cd "$tmp/my-app" && frame)" 'ほかの判断')"
assert_eq "worktree の中では、元のリポジトリに絞る" "yes" "$(has "$(cd "$tmp/other-wt" && frame)" '#5 ほかの判断')"
out=$(cd "$tmp" && frame)
assert_eq "リポジトリの外では、すべてのリポジトリを番号とタイトルまで出す" "yes yes" "$(has "$out" '#32 規約の扱いを決める') $(has "$out" '#5 ほかの判断')"

# ---- URL と幅 ----
assert_eq "GitHub の origin がないリポジトリは URL を出さない" "no" "$(has "$out" 'https://github.com//')"
setup
repo my-app '.decisions = [{number: 32, title: ("長" * 60)}]' | cache
out=$(frame --repo my-app)
# 幅 60 から字下げと番号の9桁を引いた 51 桁に、全角 25 字と … が入る
assert_eq "長いタイトルは幅に収めて … を付ける" "yes" "$(has "$out" "     #32 $(printf '長%.0s' {1..25})…")"

if [ "$failures" -ne 0 ]; then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
