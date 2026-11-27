#!/bin/bash
# bin/claude-auto-dev-status のテスト。実行: tests/claude-auto-dev-status.test.sh
# gh は偽物に差し替える。状態のディレクトリと launchd の設定は一時ディレクトリに作る。

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

# 時刻は固定する（2026-11-18 16:30、この Mac のタイムゾーン）
now=$(date -j -f '%Y-%m-%d %H:%M:%S' '2026-11-18 16:30:00' +%s)
iso() { date -u -r "$1" +%Y-%m-%dT%H:%M:%SZ; }
at() { date -j -f '%Y-%m-%d %H:%M:%S' "$1" +%s; }

# 状態のディレクトリに、claude-auto-dev が残すもの（リポジトリの場所）を作る。gh は FAKE_ISSUES・FAKE_PRS を返す
setup() {
  tmp=$(mktemp -d)
  state="$tmp/state"
  export CLAUDE_AUTO_DEV_STATE_DIR="$state" CLAUDE_AUTO_DEV_LAUNCH_AGENTS="$tmp/agents" CLAUDE_AUTO_DEV_NOW="$now"
  export CLAUDE_AUTO_DEV_CONFIG_DIR="$tmp/config"
  mkdir -p "$state/repos" "$tmp/agents" "$tmp/my-app" "$tmp/bin"
  echo "$tmp/my-app" > "$state/repos/my-app"
  export PATH="$tmp/bin:$PATH" FAKE_LOG="$tmp/fake.log" FAKE_ISSUES='[]' FAKE_PRS='[]' FAKE_GH_FAIL=
  cat > "$tmp/bin/gh" <<'EOF'
#!/bin/bash
echo "gh pwd=$PWD $*" >> "$FAKE_LOG"
[ -z "$FAKE_GH_FAIL" ] || exit 1
case "$1 $2" in
  "issue list") echo "$FAKE_ISSUES" ;;
  "pr list") echo "$FAKE_PRS" ;;
esac
EOF
  chmod +x "$tmp/bin/gh"
}

status_json() { "$bin/claude-auto-dev-status" --json "$@" 2>/dev/null; }
q() { # jq の式 [リポジトリ名…]
  local expr="$1"
  shift
  status_json "$@" | jq -c "$expr" 2>/dev/null
}

issue() { # 番号 タイトル 作った時刻 ラベル…
  local n="$1" t="$2" c="$3"
  shift 3
  jq -cn --argjson n "$n" --arg t "$t" --arg c "$(iso "$c")" '{number: $n, title: $t, state: "OPEN", createdAt: $c,
    labels: ($ARGS.positional | map({name: .}))}' --args "$@"
}

# ---- 見つけ方 ----
setup
rm "$state/repos/my-app"
out=$("$bin/claude-auto-dev-status" 2>&1)
assert_eq "リポジトリがなければ成功で終わる" "0" "$?"
assert_eq "リポジトリがなければ、そう伝える" "yes" "$(echo "$out" | grep -q 'まだ動いていません' && echo yes || echo no)"
assert_eq "リポジトリがなければ JSON は空の配列" "[]" "$(q .)"

setup
assert_eq "記録されたリポジトリを出す" '["my-app"]' "$(q 'map(.name)')"
assert_eq "リポジトリの場所を出す" "\"$tmp/my-app\"" "$(q '.[0].repo')"
status_json >/dev/null
assert_eq "gh はリポジトリのディレクトリで呼ぶ" "yes" "$(grep -q "^gh pwd=$tmp/my-app " "$FAKE_LOG" && echo yes || echo no)"

setup
mkdir -p "$tmp/other"
echo "$tmp/other" > "$state/repos/other"
assert_eq "名前を指定したら、そのリポジトリだけ出す" '["other"]' "$(q 'map(.name)' other)"

# ---- GitHub ----
setup
FAKE_ISSUES="[$(issue 8 '直す' "$((now - 86400 * 3))" auto-ready),
  $(issue 9 '作業中' "$((now - 86400 * 3))" auto-ready auto-in-progress),
  $(issue 10 '決めて' "$((now - 86400 * 3))" needs-decision),
  $(issue 11 '本人が作業中' "$((now - 86400 * 3))" auto-ready in-progress),
  $(issue 12 '急ぎ' "$((now - 86400 * 3))" auto-ready p2),
  $(issue 13 '企画した' "$((now - 3600))" auto-planned auto-ready),
  $(issue 14 '自分で決めた' "$((now - 3600))" auto-planned auto-decided auto-ready),
  $(issue 15 '精査で見つけた' "$((now - 3600))" auto-finding auto-ready p2),
  $(issue 16 '前日の企画' "$((now - 86400 * 2))" auto-planned)]"
FAKE_PRS='[{"number":30,"title":"開いている","state":"OPEN","labels":[{"name":"no-auto-merge"}],"mergedAt":null},
  {"number":29,"title":"マージした","state":"MERGED","labels":[{"name":"auto-dev"}],"mergedAt":"'"$(iso "$((now - 7200))")"'"},
  {"number":28,"title":"手元の PR","state":"MERGED","labels":[],"mergedAt":"'"$(iso "$((now - 7200))")"'"},
  {"number":27,"title":"前日のマージ","state":"MERGED","labels":[{"name":"auto-dev"}],"mergedAt":"'"$(iso "$((now - 86400 * 2))")"'"}]'
export FAKE_ISSUES FAKE_PRS
assert_eq "判断待ちの Issue を出す" '[{"number":10,"title":"決めて"}]' "$(q '.[0].decisions')"
assert_eq "開いている PR を出す" '[{"number":30,"title":"開いている","labels":["no-auto-merge"]}]' "$(q '.[0].prs')"
assert_eq "自動開発が作業中の Issue を出す" '[{"number":9,"title":"作業中"}]' "$(q '.[0].in_progress')"
assert_eq "着手できる Issue の数（判断待ち・作業中を除く）" "5" "$(q '.[0].ready')"
assert_eq "次に着手する Issue は p2 の番号の小さい順" '{"number":12,"title":"急ぎ"}' "$(q '.[0].next')"
assert_eq "直近にマージした自動開発の PR" '[{"number":29,"title":"マージした"}]' "$(q '.[0].recent.merged')"
assert_eq "直近に企画が作った Issue" '[13,14]' "$(q '[.[0].recent.planned[].number]')"
assert_eq "直近に Claude が自分で決めた Issue" '[14]' "$(q '[.[0].recent.decided[].number]')"
assert_eq "直近に精査が見つけた問題" '[15]' "$(q '[.[0].recent.findings[].number]')"
text=$("$bin/claude-auto-dev-status" 2>/dev/null)
assert_eq "テキストの直近の欄では、企画した Issue を Planner が作成として出す" "yes" "$(grep -qE 'Planner が作成 +#13 企画した' <<< "$text" && echo yes || echo no)"
assert_eq "テキストの直近の欄では、精査で見つけた問題を Auditor が発見として出す" "yes" "$(grep -qE 'Auditor が発見 +#15 精査で見つけた' <<< "$text" && echo yes || echo no)"
assert_eq "直近の幅は時間で変えられる" '[13,14,16]' "$(CLAUDE_AUTO_DEV_STATUS_HOURS=72 q '[.[0].recent.planned[].number]')"

setup
FAKE_GH_FAIL=1
export FAKE_GH_FAIL
assert_eq "gh が失敗したら、そのことを出す" "yes" "$(q '.[0].error' | grep -q 'gh' && echo yes || echo no)"
"$bin/claude-auto-dev-status" >/dev/null 2>&1
assert_eq "gh が失敗しても、ほかは出して成功で終わる" "0" "$?"

# ---- 手元の記録 ----
run_log() { # ファイル名の時刻 ターン数 費用 拒否の数 かかった時間（ミリ秒）
  mkdir -p "$state/logs"
  jq -n --argjson t "$2" --argjson c "$3" --argjson d "$4" --argjson ms "${5:-0}" '{num_turns: $t, total_cost_usd: $c,
    duration_ms: $ms, permission_denials: [range($d) | {tool_name: "Bash"}]}' > "$state/logs/my-app-$1.json"
}
setup
run_log 20261117-230000 10 1.0 0 600000
run_log 20261118-020000 20 1.25 1 840000
run_log 20261118-140000 46 1.5 0 4920400
echo '{}' > "$state/logs/other-20261118-150000.json"
assert_eq "今日の回の数・費用・かかった時間（秒）・拒否の数" '{"count":2,"cost":2.75,"duration":5760,"denials":1}' "$(q '.[0].runs.today')"
assert_eq "前回の回" "{\"at\":$(at '2026-11-18 14:00:00'),\"turns\":46,\"cost\":1.5,\"duration\":4920,\"denials\":0}" "$(q '.[0].runs.last')"

setup
assert_eq "回がなければ、今日は0回" '{"count":0,"cost":0,"duration":0,"denials":0}' "$(q '.[0].runs.today')"
assert_eq "記録がなくてもエラーを出さない" "" "$("$bin/claude-auto-dev-status" 2>&1 >/dev/null)"
assert_eq "回がなければ、前回はなし" "null" "$(q '.[0].runs.last')"

setup
mkdir -p "$state/notices"
printf '%s\t%s\t%s\n' "$((now - 86400 * 2))" "が失敗" "古い" "$((now - 600))" "が失敗" "#8: 止まりました" > "$state/notices/my-app.tsv"
assert_eq "直近の通知を出す" "[{\"at\":$((now - 600)),\"title\":\"が失敗\",\"message\":\"#8: 止まりました\"}]" "$(q '.[0].notices')"

# 後の回が正常に終わっていれば、それより前の通知は片付いたものとして印を付ける
setup
mkdir -p "$state/notices" "$state/ok"
printf '%s\t%s\t%s\n' "$((now - 7200))" "が失敗" "gh で Issue を取得できません" "$((now - 600))" "が失敗" "#8: 止まりました" > "$state/notices/my-app.tsv"
echo "$((now - 3600))" > "$state/ok/my-app"
assert_eq "後の回が正常に終わった通知は resolved にする" '[true,null]' "$(q '[.[0].notices[].resolved]')"

agent() { # StartCalendarInterval の JSON [リポジトリのパス]
  jq -n --argjson cal "$1" --arg repo "${2:-$tmp/my-app}" '{Label: "local.test", StartCalendarInterval: $cal,
    ProgramArguments: ["/bin/zsh", "-lc", "exec claude-auto-dev \($repo)"]}' > "$tmp/agents/test.plist"
  plutil -convert xml1 "$tmp/agents/test.plist"
}
checked() { mkdir -p "$state/checked" && echo "$1" > "$state/checked/my-app"; }

# ---- テキストの出力 ----
has() { if printf '%s\n' "$1" | grep -qF -- "$2"; then echo yes; else echo no; fi; }
setup
run_log 20261118-140000 46 1.5 1 4920000
mkdir -p "$state/notices"
printf '%s\t%s\t%s\n' "$((now - 600))" "が失敗" "#8: 止まりました" > "$state/notices/my-app.tsv"
FAKE_ISSUES="[$(issue 10 '決めて' "$((now - 86400 * 3))" needs-decision), $(issue 12 '急ぎ' "$((now - 86400 * 3))" auto-ready p2),
  $(issue 14 '自分で決めた' "$((now - 3600))" auto-planned auto-decided auto-ready)]"
FAKE_PRS='[{"number":30,"title":"開いている","state":"OPEN","labels":[{"name":"no-auto-merge"}],"mergedAt":null}]'
export FAKE_ISSUES FAKE_PRS
text=$("$bin/claude-auto-dev-status" 2>&1)
assert_eq "テキストにリポジトリ名を出す" "my-app" "$(printf '%s\n' "$text" | head -n 1)"
assert_eq "テキストに判断待ちを出す" "yes" "$(has "$text" '#10 決めて')"
assert_eq "テキストに開いている PR とラベルを出す" "yes" "$(has "$text" '#30 開いている（no-auto-merge）')"
assert_eq "テキストに次に着手する Issue と件数を出す" "yes" "$(has "$text" '#12 急ぎ（着手できる Issue 2 件）')"
assert_eq "テキストに今日の回とかかった時間を出す（ドルは出さない）" "yes" "$(has "$text" '1 回  1h22m  拒否 1')"
assert_eq "テキストに前回の回を出す" "yes" "$(has "$text" '11/18 14:00  46 ターン  1h22m')"
assert_eq "テキストに Claude が決めたことを出す" "yes" "$(has "$text" '#14 自分で決めた')"
assert_eq "テキストに通知を出す" "yes" "$(has "$text" '11/18 16:20  が失敗  #8: 止まりました')"
assert_eq "作業中がなければ「なし」と出す" "yes" "$(printf '%s\n' "$text" | grep -q '作業中 *なし' && echo yes || echo no)"

# ---- GitHub の URL ----
assert_eq "origin がなければ、リポジトリの URL は null" "null" "$(q '.[0].url')"
assert_eq "origin がなければ、テキストに URL を出さない" "no" "$(has "$text" 'https://')"
git init -q "$tmp/my-app"
git -C "$tmp/my-app" remote add origin git@github.com:someone/my-app.git
assert_eq "origin（ssh）から GitHub の URL を作る" '"https://github.com/someone/my-app"' "$(q '.[0].url')"
git -C "$tmp/my-app" remote set-url origin https://github.com/someone/my-app.git
assert_eq "origin（https）から GitHub の URL を作る" '"https://github.com/someone/my-app"' "$(q '.[0].url')"
git -C "$tmp/my-app" remote set-url origin git@example.com:someone/my-app.git
assert_eq "origin が GitHub でなければ null" "null" "$(q '.[0].url')"
git -C "$tmp/my-app" remote set-url origin git@github.com:someone/my-app.git
text=$("$bin/claude-auto-dev-status" 2>&1)
assert_eq "テキストの判断待ちの次の行に、Issue の URL を出す" "                    https://github.com/someone/my-app/issues/10" "$(grep -A1 -F '#10 決めて' <<< "$text" | tail -n 1)"
assert_eq "テキストの開いている PR の次の行に、PR の URL を出す" "                    https://github.com/someone/my-app/pull/30" "$(grep -A1 -F '#30 開いている' <<< "$text" | tail -n 1)"
assert_eq "判断待ちと開いている PR のほかには URL を出さない" "2" "$(grep -c 'https://' <<< "$text")"
assert_eq "直近の出来事がない項目は出さない" "no" "$(has "$text" 'マージ')"

setup
agent '[{"Hour":14,"Minute":0}]'
checked "$(at '2026-11-18 08:00:00')"
FAKE_GH_FAIL=1
export FAKE_GH_FAIL
text=$("$bin/claude-auto-dev-status" 2>&1)
assert_eq "テキストで起動の見落としを知らせる" "yes" "$(has "$text" '⚠ 11/18 14:00 の起動が記録されていません')"
assert_eq "テキストで gh の失敗を知らせる" "yes" "$(has "$text" '⚠ gh で Issue と PR を取得できません')"
assert_eq "テキストに次の起動を出す" "yes" "$(has "$text" '前回 11/18 08:00 / 次回 11/19 14:00')"

# ---- 起動の予定（launchd） ----
setup
agent '[{"Hour":14,"Minute":0},{"Hour":20,"Minute":0}]'
checked "$(at '2026-11-18 14:00:01')"
assert_eq "次の起動の時刻" "$(at '2026-11-18 20:00:00')" "$(q '.[0].schedule.next_at')"
assert_eq "起動した時刻" "$(at '2026-11-18 14:00:01')" "$(q '.[0].schedule.checked_at')"
assert_eq "予定どおり起動されていれば、見落としはなし" "null" "$(q '.[0].schedule.missed_at')"

checked "$(at '2026-11-18 08:00:00')"
assert_eq "予定の時刻に起動されていなければ、その時刻を出す" "$(at '2026-11-18 14:00:00')" "$(q '.[0].schedule.missed_at')"

setup
agent '[{"Hour":2,"Minute":0}]'
assert_eq "今日の予定が終わっていれば、次は明日" "$(at '2026-11-19 02:00:00')" "$(q '.[0].schedule.next_at')"
assert_eq "一度も起動されていなければ、前の予定を見落としとして出す" "$(at '2026-11-18 02:00:00')" "$(q '.[0].schedule.missed_at')"

setup
agent '{"Minute":15}'
assert_eq "時を省いた予定は毎時（1件だけの形も読む）" "$(at '2026-11-18 17:15:00')" "$(q '.[0].schedule.next_at')"

setup
agent '[{"Hour":20,"Minute":0}]' "$tmp/other-app"
assert_eq "ほかのリポジトリの launchd の設定は読まない" "null" "$(q '.[0].schedule.next_at')"
assert_eq "設定がなければ、見落としも出さない" "null" "$(q '.[0].schedule.missed_at')"

# ---- 実行中の回 ----
setup
assert_eq "動いていなければ running は null" "null" "$(q '.[0].running')"

setup
mkdir -p "$state/locks/my-app"
echo $$ > "$state/locks/my-app/pid"
echo '{"mode":"implement","issue":14,"log":"/x.log","started_at":100}' > "$state/locks/my-app/run"
assert_eq "動いている回の種類・Issue・始まった時刻を出す" '{"mode":"implement","issue":14,"log":"/x.log","started_at":100}' "$(q '.[0].running')"
assert_eq "テキストでも実行中の回を出す（Engineer と Issue の番号）" "yes" "$("$bin/claude-auto-dev-status" 2>/dev/null | grep -q '実行中 *Engineer #14（' && echo yes || echo no)"
for m in plan:Planner explore:Researcher review:Auditor evaluate:Evaluator other:other; do
  echo '{"mode":"'"${m%%:*}"'","issue":null,"log":"/x.log","started_at":100}' > "$state/locks/my-app/run"
  assert_eq "テキストでは ${m%%:*} の回を ${m#*:} と出す" "yes" "$("$bin/claude-auto-dev-status" 2>/dev/null | grep -q "実行中 *${m#*:}（" && echo yes || echo no)"
done

setup
mkdir -p "$state/locks/my-app"
sleep 30 & dead=$!
kill "$dead"; wait "$dead" 2>/dev/null
echo "$dead" > "$state/locks/my-app/pid"
echo '{"mode":"plan","issue":null,"log":"/x.log","started_at":100}' > "$state/locks/my-app/run"
assert_eq "落ちてロックだけ残っていれば running は null" "null" "$(q '.[0].running')"

# ---- 略称 ----
setup
assert_eq "略称の設定がなければ、名前の先頭3文字" '"my-"' "$(q '.[0].label')"

setup
mkdir -p "$tmp/config"
printf '%s\n' 'other oth' 'my-app app' > "$tmp/config/labels"
assert_eq "略称の設定があれば、それを使う" '"app"' "$(q '.[0].label')"

[ "$failures" -eq 0 ] || exit 1
