#!/bin/bash
# bin/tmux-help のテスト。実行: tests/tmux-help.test.sh

cd "$(dirname "$0")/.." || exit 1
bin="$PWD/bin"
conf="$PWD/.tmux.conf"
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

help=$("$bin/tmux-help")

# ヘルプに載っているキーを1行1つで出す。キーの欄は、行頭の空白2つから、次に空白が2つ以上続くところまで
# $1 が prefix なら「C-q キー…」の行、copy なら C-q で始まらない行（コピーモードの中のキー）を見る
listed_keys() {
  awk -v table="$1" '
    /^  [^ ]/ {
      line = substr($0, 3)
      if (!match(line, /  +/)) next
      n = split(substr(line, 1, RSTART - 1), keys, " ")
      if (table == "prefix" && keys[1] != "C-q") next
      if (table == "copy" && keys[1] == "C-q") next
      for (i = (table == "prefix" ? 2 : 1); i <= n; i++) print keys[i]
    }' <<< "$help"
}

# .tmux.conf で割り当てているキーを1行1つで出す。マウスの操作は除く
# $1 が prefix なら -T のない bind、copy なら -T copy-mode-vi の bind を見る
bound_keys() {
  awk -v table="$1" '
    $1 == "bind" {
      i = 2
      if ($i == "-r") i++
      if ($i == "-T") { t = $(i + 1); i += 2 } else t = "prefix"
      if (t == "copy-mode-vi") t = "copy"
      if (t == table && $i !~ /^Mouse/) print $i
    }' "$conf"
}

# .tmux.conf のキーのうち、ヘルプにないものを空白で区切って出す
missing_keys() {
  comm -23 <(bound_keys "$1" | sort -u) <(listed_keys "$1" | sort -u) | tr '\n' ' '
}

# 見出しで用途ごとに分ける
for section in ヘルプ ポップアップ ペイン ウィンドウ セッション コピーとペースト 画面の見かた; do
  assert_eq "見出し「${section}」がある" "■ $section" "$(grep -m1 -Fx "■ $section" <<< "$help")"
done

# .tmux.conf に足したキーは、すべてヘルプに載せる（足したのにヘルプを直し忘れたら、ここで気づく）
assert_eq "bind の一覧を読めている" "C-q" "$(bound_keys prefix | head -1)"
assert_eq ".tmux.conf の prefix のキーがすべて載っている" "" "$(missing_keys prefix)"
assert_eq ".tmux.conf のコピーモードのキーがすべて載っている" "" "$(missing_keys copy)"

# ヘルプのポップアップと、シェルのポップアップ（いまのペインの上に重ねる）を開くキーがある
assert_eq "C-q ? でヘルプを開く" "1" "$(grep -c '^bind ? display-popup .*~/bin/tmux-help' "$conf")"
assert_eq "C-q S でシェルをいまのペインの上に重ねて開く" "1" "$(grep -c '^bind S run-shell -b .*display-popup .*-w #{pane_width} .*-d "#{pane_current_path}"' "$conf")"

if [ "$failures" -ne 0 ]; then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
