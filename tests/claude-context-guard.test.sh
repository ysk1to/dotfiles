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

# 最後の応答のコンテキスト量が tokens になる会話ログを書く
write_transcript() {
  {
    echo '{"type":"user","message":{"role":"user","content":"hi"}}'
    echo '{"type":"assistant","message":{"usage":{"input_tokens":1,"cache_creation_input_tokens":0,"cache_read_input_tokens":10,"output_tokens":5}}}'
    echo "{\"type\":\"assistant\",\"message\":{\"usage\":{\"input_tokens\":1,\"cache_creation_input_tokens\":1000,\"cache_read_input_tokens\":$(($1 - 1001)),\"output_tokens\":5}}}"
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

# 一度促したら、超えたままでも繰り返さない
assert_eq "2回目は何も出さない" "" "$(run)"

# 圧縮されてしきい値を下回ったら、次に超えたときにまた促す
write_transcript 30000
assert_eq "下回ったときは何も出さない" "" "$(run)"
write_transcript 155000
assert_eq "再び超えたらまた促す" "PostToolUse" "$(run | jq -r '.hookSpecificOutput.hookEventName')"

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
