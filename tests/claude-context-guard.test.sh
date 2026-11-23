#!/bin/bash
# bin/claude-context-guard のテスト。実行: tests/claude-context-guard.test.sh

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
  export CLAUDE_CONTEXT_WARN_TOKENS=150000
  transcript="$tmp/session.jsonl"
}

# 最後の応答のコンテキスト量が $1 トークンで、その応答が $2 分前（省けば今）の会話ログを書く
write_transcript() {
  local at
  at=$(jq -rn --argjson min "${2:-0}" 'now - $min * 60 | floor | todate')
  {
    echo '{"type":"user","message":{"role":"user","content":"hi"}}'
    echo '{"type":"assistant","message":{"usage":{"input_tokens":1,"cache_creation_input_tokens":0,"cache_read_input_tokens":10,"output_tokens":5}}}'
    echo "{\"type\":\"assistant\",\"message\":{\"usage\":{\"input_tokens\":1,\"cache_creation_input_tokens\":1000,\"cache_read_input_tokens\":$(($1 - 1001)),\"output_tokens\":5}},\"timestamp\":\"${at%Z}.123Z\"}"
    echo '{"type":"user","message":{"role":"user","content":[{"type":"tool_result","content":"ok"}]}}'
  } > "$transcript"
}

run() {
  echo "{\"session_id\":\"s1\",\"transcript_path\":\"$transcript\",\"hook_event_name\":\"${1:-PostToolUse}\"}" | "$bin/claude-context-guard"
}

# しきい値より少なければ何も出さない
setup
write_transcript 149999
assert_eq "しきい値未満では何も出さない" "" "$(run)"

# しきい値を超えたら、イベント名つきで Notion への記録を促す
setup
write_transcript 160000
out=$(run UserPromptSubmit)
assert_eq "超えたらイベント名を返す" "UserPromptSubmit" "$(echo "$out" | jq -r '.hookSpecificOutput.hookEventName')"
assert_eq "超えたら Notion への記録を促す" "yes" "$(echo "$out" | jq -r '.hookSpecificOutput.additionalContext' | grep -q 'Notion' && echo yes || echo no)"
assert_eq "トークン数を万単位で伝える" "yes" "$(echo "$out" | jq -r '.hookSpecificOutput.additionalContext' | grep -q '16万' && echo yes || echo no)"
assert_eq "次にやることまで書くよう促す" "yes" "$(echo "$out" | jq -r '.hookSpecificOutput.additionalContext' | grep -q '次にやること' && echo yes || echo no)"

# 一度促したら、超えたままでも繰り返さない
assert_eq "2回目は何も出さない" "" "$(run)"

# 圧縮されてしきい値を下回ったら、次に超えたときにまた促す
write_transcript 30000
assert_eq "下回ったときは何も出さない" "" "$(run)"
write_transcript 155000
assert_eq "再び超えたらまた促す" "PostToolUse" "$(run | jq -r '.hookSpecificOutput.hookEventName')"

# しきい値を指定しなければ、15万で促す
setup
unset CLAUDE_CONTEXT_WARN_TOKENS
write_transcript 149999
assert_eq "既定では15万未満で何も出さない" "" "$(run)"
write_transcript 150000
assert_eq "既定では15万で促す" "PostToolUse" "$(run | jq -r '.hookSpecificOutput.hookEventName')"

# 60分以上あけた再開で、文脈がしきい値以上なら、送信を1回だけ止めて知らせる
setup
write_transcript 160000 61
out=$(run UserPromptSubmit)
assert_eq "長くあけた再開は送信を止める" "block" "$(echo "$out" | jq -r '.decision')"
assert_eq "止めた理由に作り直す量を書く" "yes" "$(echo "$out" | jq -r '.reason' | grep -q '16万' && echo yes || echo no)"
assert_eq "止めた理由にあけた時間を書く" "yes" "$(echo "$out" | jq -r '.reason' | grep -q '61分' && echo yes || echo no)"
assert_eq "止めた理由に続け方を書く" "yes" "$(echo "$out" | jq -r '.reason' | grep -q 'もう一度送信' && echo yes || echo no)"
assert_eq "30万未満では、大きな作り直しとは書かない" "no" "$(echo "$out" | jq -r '.reason' | grep -q '大きな作り直し' && echo yes || echo no)"

# もう一度送れば通り、記録を促す
out=$(run UserPromptSubmit)
assert_eq "もう一度送れば止めない" "null" "$(echo "$out" | jq -r '.decision')"
assert_eq "通したときに記録を促す" "UserPromptSubmit" "$(echo "$out" | jq -r '.hookSpecificOutput.hookEventName')"

# 通したあと、また長くあけたら、もう一度止める
write_transcript 170000 90
assert_eq "次に長くあけたらまた止める" "block" "$(run UserPromptSubmit | jq -r '.decision')"

# 30万トークン以上なら、作り直しが大きいことを書く
setup
write_transcript 310000 61
assert_eq "30万以上は大きな作り直しと書く" "yes" "$(run UserPromptSubmit | jq -r '.reason' | grep -q '大きな作り直し' && echo yes || echo no)"

# 止めるのは、長くあけて、文脈がしきい値以上で、送信のときだけ
setup
write_transcript 160000 59
assert_eq "60分未満なら止めない" "null" "$(run UserPromptSubmit | jq -r '.decision')"
setup
write_transcript 149999 61
assert_eq "しきい値未満なら長くあけても止めない" "" "$(run UserPromptSubmit)"
setup
write_transcript 160000 61
assert_eq "道具のあとでは止めない" "null" "$(run PostToolUse | jq -r '.decision')"

# あける時間は CLAUDE_RESUME_GAP_MINUTES で変えられる
setup
export CLAUDE_RESUME_GAP_MINUTES=30
write_transcript 160000 31
assert_eq "あける時間を変えられる" "block" "$(run UserPromptSubmit | jq -r '.decision')"
unset CLAUDE_RESUME_GAP_MINUTES

# 応答の時刻がわからなければ止めない
setup
write_transcript 160000 61
sed -i.bak 's/,"timestamp":"[^"]*"//' "$transcript"
assert_eq "時刻がなければ止めない" "null" "$(run UserPromptSubmit | jq -r '.decision')"

# 会話ログがなくても失敗しない
setup
transcript="$tmp/missing.jsonl"
assert_eq "会話ログがなければ何も出さない" "" "$(run)"
run > /dev/null
assert_eq "会話ログがなくても終了コード 0" "0" "$?"

if [ "$failures" -ne 0 ]; then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
