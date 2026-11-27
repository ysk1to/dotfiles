#!/bin/bash
# tests/ のテストが、mktemp で作った一時フォルダを終わるときに消しているかを確かめる。実行: tests/tmp-cleanup.test.sh
# テストを実際には動かさず、書き方だけを見る。決まりは次のとおり（tests/claude-auto-dev.test.sh と同じ形）。
# - mktemp で作ったものは、trap 'rm -rf "$変数"' EXIT で消す変数そのものか、その変数のフォルダの下（mktemp -d "$変数/XXXXXX"）に作る

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

# 決まりに合わない mktemp の行を「行番号: 中身」で出す
uncleaned() {
  local f="$1" trapped line n v
  # trap 'rm -rf "$a" "$b"' EXIT で消す変数の名前
  trapped=$(grep -E "^[[:space:]]*trap 'rm -rf [^']*' EXIT" "$f" | grep -oE '"\$[A-Za-z_][A-Za-z0-9_]*"' | tr -d '"$')
  while IFS=: read -r n line; do
    v=
    if [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=\$\(mktemp\ -d\)[[:space:]]*$ ]]; then
      v="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ mktemp\ [^\)]*\"\$([A-Za-z_][A-Za-z0-9_]*)/ ]]; then
      v="${BASH_REMATCH[1]}"
    fi
    if [ -z "$v" ] || ! grep -qxF "$v" <<< "$trapped"; then
      echo "$n: $line"
    fi
  done < <(grep -nE '(^|[^A-Za-z_])mktemp([^A-Za-z_]|$)' "$f" | grep -vE '^[0-9]+:[[:space:]]*#')
}

# ---- 見分け方 ----
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/good.sh" <<'EOF'
tmp_root=$(mktemp -d)
trap 'rm -rf "$tmp_root"' EXIT
setup() {
  tmp=$(mktemp -d "$tmp_root/XXXXXX")
}
# コメントの mktemp は見ない
EOF
assert_eq "trap で消すフォルダの下に作れば合う" "" "$(uncleaned "$tmp/good.sh")"

cat > "$tmp/bad.sh" <<'EOF'
setup() {
  tmp=$(mktemp -d)
}
EOF
assert_eq "trap のない mktemp は合わない" "2:   tmp=\$(mktemp -d)" "$(uncleaned "$tmp/bad.sh")"

cat > "$tmp/other.sh" <<'EOF'
tmp_root=$(mktemp -d)
trap 'rm -rf "$tmp_root"' EXIT
other=$(mktemp -d)
EOF
assert_eq "trap で消さない変数に作ると合わない" "3: other=\$(mktemp -d)" "$(uncleaned "$tmp/other.sh")"

# ---- tests/ のテスト ----
for f in tests/*.test.sh; do
  [ "$f" != tests/tmp-cleanup.test.sh ] || continue  # 見本の mktemp を書いている、このファイルは除く
  assert_eq "$f: mktemp で作ったものを終わるときに消す" "" "$(uncleaned "$f")"
done

echo
if [ "$failures" -eq 0 ]; then
  echo "すべて成功"
else
  echo "$failures 件失敗"
  exit 1
fi
