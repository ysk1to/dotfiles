#!/bin/bash
# bin/iterm-default-profile のテスト。実行: tests/iterm-default-profile.test.sh
# defaults と pgrep は、PATH の先頭に置いた偽物に差し替える

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

# 偽の defaults は、書き込みを $tmp/written に記録し、読み込みには $tmp/current を返す
# 偽の pgrep は、$tmp/running があれば iTerm2 が動いているとみなす
setup() {
  tmp=$(mktemp -d "$tmp_root/XXXXXX")
  mkdir "$tmp/bin"
  cat > "$tmp/bin/defaults" <<EOF
#!/bin/bash
case "\$1" in
  read) [ -f "$tmp/current" ] && /bin/cat "$tmp/current" ;;
  write) echo "\$*" > "$tmp/written" ;;
esac
EOF
  cat > "$tmp/bin/pgrep" <<EOF
#!/bin/bash
[ -f "$tmp/running" ]
EOF
  chmod +x "$tmp/bin/defaults" "$tmp/bin/pgrep"
  profile="$tmp/profile.json"
  echo '{"Profiles":[{"Name":"demo","Guid":"AAAA-1111"}]}' > "$profile"
}

run() {
  PATH="$tmp/bin:$PATH" "$bin/iterm-default-profile" "$@" "$profile" >/dev/null 2>&1
  echo $?
}

# jq のない環境（PATH に偽物しかない）で動かす
run_without_jq() {
  PATH="$tmp/bin" "$bin/iterm-default-profile" "$profile" >/dev/null 2>&1
  echo $?
}

# iTerm2 が止まっていれば、プロファイルの Guid を既定にする
setup
assert_eq "止まっていれば 0 で終わる" "0" "$(run)"
assert_eq "既定のプロファイルを書き込む" "write com.googlecode.iterm2 Default Bookmark Guid -string AAAA-1111" "$(cat "$tmp/written" 2>/dev/null)"

# すでに既定になっていれば、書き込まない
setup
echo AAAA-1111 > "$tmp/current"
assert_eq "既定になっていれば 0 で終わる" "0" "$(run)"
assert_eq "既定になっていれば書き込まない" "no" "$([ -e "$tmp/written" ] && echo yes || echo no)"

# iTerm2 が動いていれば、終了時に上書きされるので書き込まない（deploy は止めない）
setup
touch "$tmp/running"
assert_eq "動いていても 0 で終わる" "0" "$(run)"
assert_eq "動いていれば書き込まない" "no" "$([ -e "$tmp/written" ] && echo yes || echo no)"

# Guid が読めなければ、書き込まずに失敗する
setup
echo '{}' > "$profile"
assert_eq "Guid がなければ 1 で終わる" "1" "$(run)"
assert_eq "Guid がなければ書き込まない" "no" "$([ -e "$tmp/written" ] && echo yes || echo no)"

# jq がなければ、書き込まずに 0 で終わる（jq を入れる前の make install を止めない）
setup
assert_eq "jq がなくても 0 で終わる" "0" "$(run_without_jq)"
assert_eq "jq がなければ書き込まない" "no" "$([ -e "$tmp/written" ] && echo yes || echo no)"

# --check は、既定になっているかを確かめるだけで、書き込まない
setup
echo AAAA-1111 > "$tmp/current"
assert_eq "--check は既定になっていれば 0 で終わる" "0" "$(run --check)"
setup
echo BBBB-2222 > "$tmp/current"
assert_eq "--check は既定が違えば 1 で終わる" "1" "$(run --check)"
assert_eq "--check は書き込まない" "no" "$([ -e "$tmp/written" ] && echo yes || echo no)"

if [ "$failures" -ne 0 ]; then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
