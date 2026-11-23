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

# コンテキストが tokens で、prompt_cache が $2（省けばなし）の入力を作る
context_input() {
  jq -cn --argjson tokens "$1" --argjson cache "${2:-null}" '
    {model: {display_name: "Fable 5"}, version: "2.1.311",
     context_window: {used_percentage: 50, current_usage: {input_tokens: 1, cache_creation_input_tokens: 0, cache_read_input_tokens: ($tokens - 1)}}}
    + (if $cache then {prompt_cache: $cache} else {} end)'
}
has() { grep -q "$1" && echo yes || echo no; }
warm='{"warm":true,"caching_observed":true,"recache_tokens_if_cold":180000}'
cold='{"warm":false,"caching_observed":true,"recache_tokens_if_cold":180000}'

# キャッシュが切れたら、作り直す量と一緒に知らせる（文脈の大きさによらない）
setup
unset CLAUDE_CONTEXT_WARN_TOKENS
out=$(context_input 100000 "$cold" | "$bin/claude-statusline")
assert_eq "キャッシュが切れたら知らせる" "yes" "$(echo "$out" | has 'キャッシュ切れ')"
assert_eq "作り直す量を出す" "yes" "$(echo "$out" | has '作り直し 180K')"
assert_eq "キャッシュがあれば知らせない" "no" "$(context_input 100000 "$warm" | "$bin/claude-statusline" | has 'キャッシュ切れ')"
assert_eq "キャッシュを使っていなければ知らせない" "no" \
  "$(context_input 100000 '{"warm":false,"caching_observed":false}' | "$bin/claude-statusline" | has 'キャッシュ切れ')"
assert_eq "作り直す量がわからなければ今の文脈の量を出す" "yes" \
  "$(context_input 100000 '{"warm":false,"caching_observed":true,"recache_tokens_if_cold":null}' | "$bin/claude-statusline" | has '作り直し 100K')"

# 文脈が線（既定 15万）以上のあいだ、モデルを切り替えると作り直しになる印を出す
assert_eq "線以上ならモデルの切り替えの印を出す" "yes" "$(context_input 150000 "$warm" | "$bin/claude-statusline" | has 'モデル切替で作り直し')"
assert_eq "線未満なら印を出さない" "no" "$(context_input 149999 "$warm" | "$bin/claude-statusline" | has 'モデル切替で作り直し')"
assert_eq "prompt_cache がなくても線以上なら印を出す" "yes" "$(context_input 150000 | "$bin/claude-statusline" | has 'モデル切替で作り直し')"
assert_eq "キャッシュが切れていれば切り替えの印は出さない" "no" "$(context_input 150000 "$cold" | "$bin/claude-statusline" | has 'モデル切替で作り直し')"
export CLAUDE_CONTEXT_WARN_TOKENS=100000
assert_eq "線は CLAUDE_CONTEXT_WARN_TOKENS で変えられる" "yes" "$(context_input 100000 "$warm" | "$bin/claude-statusline" | has 'モデル切替で作り直し')"
unset CLAUDE_CONTEXT_WARN_TOKENS

if [ "$failures" -ne 0 ]; then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
