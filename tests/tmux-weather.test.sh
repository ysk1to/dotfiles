#!/bin/bash
# bin/tmux-weather のテスト。実行: tests/tmux-weather.test.sh

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

setup() {
  tmp=$(mktemp -d)
  export XDG_CACHE_HOME="$tmp"
  # 取得の代わりに、問い合わせた URL をそのまま出す
  export TMUX_WEATHER_FETCH="echo"
  unset TMUX_WEATHER_LOCATION
}

# 引数で地点を指定できる
setup
assert_eq "引数の地点で問い合わせる" "https://wttr.in/Osaka?format=3" "$("$bin/tmux-weather" Osaka)"

# 引数がなければ、環境変数 TMUX_WEATHER_LOCATION の地点を使う
setup
assert_eq "環境変数の地点で問い合わせる" "https://wttr.in/Sapporo?format=3" "$(TMUX_WEATHER_LOCATION=Sapporo "$bin/tmux-weather")"

# どちらもなければ地点を付けない（wttr.in が IP から推定する）
setup
assert_eq "地点がなければ付けずに問い合わせる" "https://wttr.in/?format=3" "$("$bin/tmux-weather")"

if [ "$failures" -ne 0 ]; then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
