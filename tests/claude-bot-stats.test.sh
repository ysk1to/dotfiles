#!/bin/bash
# bin/claude-bot-stats のテスト。実行: tests/claude-bot-stats.test.sh
# gh は偽物に差し替える。自動開発の記録と会話の記録は一時ディレクトリに作る。

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

# 時刻は固定する（2026-11-22 12:00、この Mac のタイムゾーン）
now=$(date -j -f '%Y-%m-%d %H:%M:%S' '2026-11-22 12:00:00' +%s)
iso() { date -u -r "$1" +%Y-%m-%dT%H:%M:%SZ; }
day=86400

# 状態のディレクトリ（リポジトリの場所と events.tsv）と会話の記録を作る。gh は FAKE_PRS を返す
setup() {
  tmp=$(mktemp -d)
  state="$tmp/state"
  projects="$tmp/projects"
  export CLAUDE_AUTO_DEV_STATE_DIR="$state" CLAUDE_AUTO_DEV_NOW="$now" CLAUDE_PROJECTS_DIR="$projects"
  mkdir -p "$state/repos" "$tmp/my-app" "$tmp/bin" "$projects/p1"
  echo "$tmp/my-app" > "$state/repos/my-app"
  : > "$state/events.tsv"
  export PATH="$tmp/bin:$PATH" FAKE_LOG="$tmp/fake.log" FAKE_PRS='[]' FAKE_ISSUES='[]' FAKE_GH_FAIL=
  cat > "$tmp/bin/gh" <<'EOF'
#!/bin/bash
echo "gh pwd=$PWD $*" >> "$FAKE_LOG"
[ -z "$FAKE_GH_FAIL" ] || exit 1
case "$1 $2" in
  "pr list") echo "$FAKE_PRS" ;;
  "issue list") echo "$FAKE_ISSUES" ;;
esac
EOF
  chmod +x "$tmp/bin/gh"
}

event() { # 何秒前 リポジトリ 種類 内容
  printf '%s\t%s\t%s\t%s\n' "$((now - $1))" "$2" "$3" "$4" >> "$state/events.tsv"
}

q() { # jq の式 [引数…]
  local expr="$1"
  shift
  "$bin/claude-bot-stats" --json "$@" 2>/dev/null | jq -c "$expr" 2>/dev/null
}

# ---- 自動開発の Bot ----

setup
event 3600 my-app start "#12 に着手"
event 3000 my-app pr "#20 🤖 [add] 何か"
event 2900 my-app end "19 ターン、5m"
event 2000 my-app start "企画"
event 1900 my-app issue "#21 🤖 案その1"
event 1800 my-app issue "#22 🤖 案その2"
event 1700 my-app end "10 ターン、3m"
event 1500 my-app start "精査"
event 1400 my-app end "8 ターン、2m"
event 1200 my-app start "探索（調査）"
event 1100 my-app end "5 ターン、1m"
event 1000 my-app start "探索（審査）"
event 900 my-app end "5 ターン、1m"
event 800 my-app start "#13 に着手"
event 700 my-app decision "#13: 判断待ちで止まりました。Issue のコメントを見てください"
event 600 my-app start "#14 に着手"
event 500 my-app fail "claude が終了コード 1 で止まりました"
assert_eq "着手の回は Engineer として数える" '{"runs":3,"pr":1,"decision":1,"fail":1}' \
  "$(q '.bots["my-app"].Engineer | {runs, pr, decision, fail}')"
assert_eq "企画の回は Planner として、作った Issue を数える" '{"runs":1,"issue":2}' \
  "$(q '.bots["my-app"].Planner | {runs, issue}')"
assert_eq "精査の回は Auditor として数える" '1' "$(q '.bots["my-app"].Auditor.runs')"
assert_eq "探索の段は Researcher として、段ごとに1回と数える" '2' "$(q '.bots["my-app"].Researcher.runs')"

setup
event $((8 * day)) my-app start "#1 に着手"
event $((8 * day - 60)) my-app pr "#2 古い PR"
event 600 my-app start "#3 に着手"
assert_eq "既定では直近7日だけを数える" '{"runs":1,"pr":0}' "$(q '.bots["my-app"].Engineer | {runs, pr}')"
assert_eq "--days で期間を変えられる" '{"runs":2,"pr":1}' "$(q '.bots["my-app"].Engineer | {runs, pr}' --days 10)"
assert_eq "期間を出力に入れる" '7' "$(q '.days')"

setup
event 600 my-app notice "週の枠 10%"
assert_eq "回の外のお知らせは数えない" '{}' "$(q '.bots["my-app"] // {}')"

setup
event 600 my-app start "#1 に着手"
event 500 other-app pr "#9 別のリポジトリ"
assert_eq "リポジトリごとに分けて数える" '0' "$(q '.bots["my-app"].Engineer.pr')"

setup
event 3000 my-app start "#12 に着手"
event 2900 my-app fail "#12: 前の回が途中で止まっていました"
event 2000 my-app start "#15 に着手"
event 1900 my-app fail "#15: claude が終了コード 1 で止まりました。ログ: /tmp/x.log"
event 1000 my-app start "#12 に着手"
event 900 my-app fail "#12: 前の回が途中で止まっていました"
assert_eq "失敗を、先頭の番号を除いた最初の「。」より前の文で、理由ごとに多い順に数える" \
  '{"前の回が途中で止まっていました":2,"claude が終了コード 1 で止まりました":1}' \
  "$(q '.bots["my-app"].Engineer.fail_reasons')"

setup
event 3000 my-app start "探索（審査）"
event 2900 my-app notice "探索（お題）: 案 5 件、採用 2 件"
event 2000 my-app start "探索（審査）"
event 1900 my-app notice "探索（お題）: 案 5 件、採用 2 件"
event 1800 my-app notice "週の枠 10%"
assert_eq "Researcher の出した案と採用した案を、探索のお知らせから足し合わせる" '{"ideas":10,"adopted":4}' \
  "$(q '.bots["my-app"].Researcher | {ideas, adopted}')"

# ---- Reviewer ----

pr() { # 番号 何秒前に作ったか 状態 マージした人（なければ空） 自動レビューのコメントの1行目（なければ空）
  jq -cn --argjson n "$1" --arg c "$(iso "$((now - $2))")" --arg s "$3" --arg m "$4" --arg h "$5" \
    '{number: $n, createdAt: $c, state: $s, mergedBy: (if $m == "" then null else {login: $m} end),
      comments: (if $h == "" then [] else [{body: ($h + "\n\n本文")}] end)}'
}

setup
FAKE_PRS="[$(pr 1 600 MERGED app/github-actions "## 自動レビュー: マージしました"),$(pr 2 600 OPEN "" "## 自動レビュー: 要確認（マージしていません）"),$(pr 3 600 OPEN "" ""),$(pr 4 $((8 * day)) MERGED app/github-actions "## 自動レビュー: マージしました")]"
assert_eq "期間内の PR を、自動マージ・要確認・レビュー前に分けて数える" \
  '{"prs":3,"auto_merged":1,"needs_check":1,"not_reviewed":1}' "$(q '.reviewer["my-app"] | {prs, auto_merged, needs_check, not_reviewed}')"
assert_eq "gh はリポジトリの場所で呼ぶ" "1" "$(grep -c "gh pwd=$tmp/my-app pr list" "$FAKE_LOG")"

setup
FAKE_PRS="[$(pr 1 600 MERGED ysk1to "## 自動レビュー: 要確認（マージしていません）")]"
assert_eq "ワークフローがマージしたかで判定する（要確認のあとに本人がマージしたものは要確認）" \
  '{"auto_merged":0,"needs_check":1}' "$(q '.reviewer["my-app"] | {auto_merged, needs_check}')"

setup
FAKE_PRS="[$(pr 1 600 MERGED app/github-actions "## 自動レビュー"),$(pr 2 600 MERGED ysk1to "## 自動レビュー")]"
assert_eq "見出しに判定を書かない自動レビューでも、マージした人で分ける" \
  '{"auto_merged":1,"needs_check":1}' "$(q '.reviewer["my-app"] | {auto_merged, needs_check}')"

setup
FAKE_GH_FAIL=1
assert_eq "gh が失敗しても止まらず、そのリポジトリは null にする" 'null' "$(q '.reviewer["my-app"]')"

review() { # 番号 マージした人（なければ空） 自動レビューのコメントの本文…（コメントごとに1つ）
  local n="$1" m="$2"
  shift 2
  jq -cn --argjson n "$n" --arg c "$(iso "$((now - 600))")" --arg m "$m" \
    '{number: $n, createdAt: $c, state: (if $m == "" then "OPEN" else "MERGED" end),
      mergedBy: (if $m == "" then null else {login: $m} end), comments: [$ARGS.positional[] | {body: .}]}' --args "$@"
}
needs_check() { # 理由…
  printf '## 自動レビュー: 要確認（マージしていません）\n\n'
  printf -- '- %s\n' "$@"
  printf '\n@foo 確認をお願いします。\n\n### 判定の理由\n- 直った: 何か\n'
}
rule="自動レビューや Claude への指示にかかわるファイルを変更しています: CLAUDE.md"
judged="レビューで、人の判断が必要と判定されました"

setup
FAKE_PRS="[$(review 1 "" "$(needs_check "$rule")"),$(review 2 "" "$(needs_check "$judged")"),$(review 3 ysk1to "$(needs_check "$rule" "$judged")"),$(review 4 "" "$(needs_check "\`no-auto-merge\` ラベルが付いています" "このワークフローがテストしないファイルを変更しています: a.sh")"),$(review 5 "" "## 自動レビュー: 要確認（マージしていません）")]"
assert_eq "要確認を、決まりで止まったものとレビューが判断を求めたものに分ける" \
  '{"needs_check":5,"needs_check_by_rule":2,"needs_check_by_review":3}' \
  "$(q '.reviewer["my-app"] | {needs_check, needs_check_by_rule, needs_check_by_review}')"

setup
FAKE_PRS="[$(review 1 "" "$(needs_check "$judged")" "途中のコメント" "$(needs_check "$rule")")]"
assert_eq "要確認の理由は、最後の自動レビューのコメントで見る" '{"needs_check_by_rule":1,"needs_check_by_review":0}' \
  "$(q '.reviewer["my-app"] | {needs_check_by_rule, needs_check_by_review}')"

issue() { # 番号 何秒前に作ったか 状態 作った人
  jq -cn --argjson n "$1" --arg c "$(iso "$((now - $2))")" --arg s "$3" --arg a "$4" \
    '{number: $n, createdAt: $c, state: $s, author: {login: $a}}'
}

setup
FAKE_ISSUES="[$(issue 1 600 OPEN app/github-actions),$(issue 2 600 CLOSED app/github-actions),$(issue 3 600 OPEN ysk1to),$(issue 4 $((8 * day)) OPEN app/github-actions)]"
assert_eq "ワークフローが作った期間内の Issue を、作った数と開いている数で数える" '{"created":2,"open":1}' \
  "$(q '.reviewer["my-app"].followup_issues')"

# ---- スキル ----

skill_line() { # 何秒前 スキル名
  jq -cn --arg t "$(iso "$((now - $1))")" --arg s "$2" \
    '{type: "assistant", timestamp: $t, message: {content: [{type: "tool_use", name: "Skill", input: {skill: $s}}]}}'
}

setup
{
  skill_line 600 recruiter
  skill_line 500 recruiter
  skill_line 400 yomiyasu
  skill_line $((8 * day)) yomiyasu
  jq -cn --arg t "$(iso "$((now - 300))")" '{type: "user", timestamp: $t, message: {content: "スキルの話だけ"}}'
} > "$projects/p1/a.jsonl"
assert_eq "会話の記録から、期間内にスキルが呼ばれた回数を数える" '{"recruiter":2,"yomiyasu":1}' "$(q '.skills')"

setup
assert_eq "会話の記録がなければ空にする" '{}' "$(q '.skills')"

# ---- テキストの出力 ----

setup
event 600 my-app start "#1 に着手"
event 500 my-app pr "#2 PR"
out=$("$bin/claude-bot-stats" 2>/dev/null)
assert_eq "テキストでは、リポジトリと役割ごとに1行で出す" "1" "$(grep -c '^  Engineer  回 1  PR 1' <<< "$out")"

setup
event 3000 my-app start "#1 に着手"
event 2900 my-app fail "#1: 前の回が途中で止まっていました"
event 2800 my-app fail "#1: gh で Issue を取得できません"
event 2700 my-app fail "#1: 前の回が途中で止まっていました"
event 2000 my-app start "探索（審査）"
event 1900 my-app notice "探索（お題）: 案 5 件、採用 2 件"
FAKE_PRS="[$(review 1 "" "$(needs_check "$rule")")]"
FAKE_ISSUES="[$(issue 1 600 OPEN app/github-actions)]"
out=$("$bin/claude-bot-stats" 2>/dev/null)
assert_eq "テキストでは、失敗の理由を役割の行の下に多い順に字下げして出す" \
  "$(printf '  Engineer  回 1  PR 0  Issue 0  判断待ち 0  失敗 3\n    前の回が途中で止まっていました  2\n    gh で Issue を取得できません  1')" \
  "$(grep -A2 '^  Engineer' <<< "$out")"
assert_eq "テキストでは、Researcher の行に案と採用の数を続けて出す" "1" "$(grep -c '^  Researcher  回 1  .*  失敗 0  案 5  採用 2$' <<< "$out")"
assert_eq "テキストでは、Reviewer の行に要確認の内訳と古くなった記述の Issue を続けて出す" "1" \
  "$(grep -c '要確認 1  レビュー前 0  決まりで要確認 1  判断で要確認 0  古くなった記述の Issue 1（開 1）$' <<< "$out")"

echo
if [ "$failures" -eq 0 ]; then
  echo "すべて成功"
else
  echo "$failures 件失敗"
  exit 1
fi
