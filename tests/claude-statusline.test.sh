#!/bin/bash
# bin/claude-statusline のテスト。実行: tests/claude-statusline.test.sh

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
  cache="$tmp/claude-rate-limits.json"
}

input='{"model":{"display_name":"Fable 5"},"version":"2.1.311","rate_limits":{"five_hour":{"used_percentage":5,"resets_at":100},"seven_day":{"used_percentage":45,"resets_at":200}}}'

# rate_limits を tmux 用のキャッシュに書き込む
setup
echo "$input" | "$bin/claude-statusline" > /dev/null
assert_eq "rate_limits をキャッシュに書き込む" \
  '{"five_hour":{"used_percentage":5,"resets_at":100},"seven_day":{"used_percentage":45,"resets_at":200}}' \
  "$(cat "$cache" 2>/dev/null)"

# rate_limits に Fable の枠はないので、claude-usage-refresh が書いた seven_day_fable を消さない
setup
echo '{"five_hour":{"used_percentage":1,"resets_at":1},"seven_day_fable":{"used_percentage":35,"resets_at":300}}' > "$cache"
echo "$input" | "$bin/claude-statusline" > /dev/null
assert_eq "キャッシュにある Fable の枠を残す" \
  '{"seven_day_fable":{"used_percentage":35,"resets_at":300},"five_hour":{"used_percentage":5,"resets_at":100},"seven_day":{"used_percentage":45,"resets_at":200}}' \
  "$(cat "$cache")"

# rate_limits がなければキャッシュを変えない
setup
echo '{"five_hour":{"used_percentage":1,"resets_at":1}}' > "$cache"
echo '{"model":{"display_name":"Fable 5"},"version":"2.1.311"}' | "$bin/claude-statusline" > /dev/null
assert_eq "rate_limits がなければキャッシュを変えない" \
  '{"five_hour":{"used_percentage":1,"resets_at":1}}' "$(cat "$cache")"

if [ "$failures" -ne 0 ]; then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
