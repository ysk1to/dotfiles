#!/bin/bash
# bin/tmux-claude-auto-dev のテスト。実行: tests/tmux-claude-auto-dev.test.sh
# claude-auto-dev-status は偽物に差し替え、呼ばれたかを記録する。

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

# 偽の claude-auto-dev-status は FAKE_STATUS を出す
setup() {
  tmp=$(mktemp -d)
  export XDG_CACHE_HOME="$tmp" FAKE_LOG="$tmp/fake.log" FAKE_STATUS='[]'
  cache="$tmp/claude-auto-dev-status.json"
  cat > "$tmp/status" <<'EOF'
#!/bin/bash
echo "status $*" >> "$FAKE_LOG"
if [ "$1" = --json ]; then echo "$FAKE_STATUS"; else echo "状況の全文"; fi
EOF
  chmod +x "$tmp/status"
  export TMUX_AUTO_DEV_STATUS="$tmp/status"
}
calls() { if [ -f "$FAKE_LOG" ]; then grep -c '^status --json' "$FAKE_LOG"; else echo 0; fi; }
# 裏で取り直すので、キャッシュができるまで少し待つ
wait_cache() { for _ in 1 2 3 4 5 6 7 8 9 10; do [ -s "$cache" ] && return; sleep 0.2; done; }

repo() { # 判断待ち PR 作業中 着手できる 見落とし gh の失敗 通知の見出し
  jq -cn --argjson d "$1" --argjson p "$2" --argjson w "$3" --argjson r "$4" --arg missed "$5" --arg error "$6" --arg notice "$7" '
    {decisions: [range($d) | {number: ., title: "t"}], prs: [range($p) | {number: ., title: "t", labels: []}],
     in_progress: [range($w) | {number: (. + 8), title: "t"}], ready: $r,
     schedule: {missed_at: (if $missed == "" then null else 1 end)},
     notices: (if $notice == "" then [] else [{at: 1, title: $notice, message: "m"}] end)}
    + (if $error == "" then {} else {error: $error} end)'
}

# ---- 表示 ----
setup
echo "[$(repo 2 1 1 19 '' '' '')]" > "$cache"
assert_eq "件数を絵文字で出す（作業中は番号）" "🛠 🙋2 🔀1 🏃#8 📥19" "$("$bin/tmux-claude-auto-dev")"

setup
echo "[$(repo 0 0 0 0 '' '' '')]" > "$cache"
assert_eq "何もなければ ✓ だけ" "🛠 ✓" "$("$bin/tmux-claude-auto-dev")"

setup
echo "[$(repo 0 0 0 3 '' '' ''), $(repo 1 0 0 2 '' '' '')]" > "$cache"
assert_eq "リポジトリをまたいで足す" "🛠 🙋1 📥5" "$("$bin/tmux-claude-auto-dev")"

setup
echo "[$(repo 0 0 0 0 yes '' '')]" > "$cache"
assert_eq "起動の見落としは ⚠️" "🛠 ⚠️" "$("$bin/tmux-claude-auto-dev")"
echo "[$(repo 0 0 0 0 '' 'gh で取得できません' '')]" > "$cache"
assert_eq "gh の失敗は ⚠️" "🛠 ⚠️" "$("$bin/tmux-claude-auto-dev")"
echo "[$(repo 0 0 0 0 '' '' 'が失敗')]" > "$cache"
assert_eq "失敗の通知は ⚠️" "🛠 ⚠️" "$("$bin/tmux-claude-auto-dev")"
echo "[$(repo 0 0 0 0 '' '' 'が判断待ち')]" > "$cache"
assert_eq "失敗でない通知は ⚠️ にしない" "🛠 ✓" "$("$bin/tmux-claude-auto-dev")"

setup
echo "[]" > "$cache"
assert_eq "自動開発のリポジトリがなければ何も出さない" "" "$("$bin/tmux-claude-auto-dev")"

# ---- キャッシュ ----
setup
echo "[$(repo 0 0 0 1 '' '' '')]" > "$cache"
"$bin/tmux-claude-auto-dev" >/dev/null
sleep 0.5
assert_eq "キャッシュが新しければ取り直さない" "0" "$(calls)"

setup
echo "[$(repo 0 0 0 1 '' '' '')]" > "$cache"
touch -t 202601010000 "$cache"
FAKE_STATUS="[$(repo 0 0 0 7 '' '' '')]"
export FAKE_STATUS
assert_eq "古いキャッシュでも、待たずにそれを出す" "🛠 📥1" "$("$bin/tmux-claude-auto-dev")"
for _ in 1 2 3 4 5 6 7 8 9 10; do grep -q '"ready":7' "$cache" 2>/dev/null && break; sleep 0.2; done
assert_eq "古いキャッシュは裏で取り直す" "🛠 📥7" "$("$bin/tmux-claude-auto-dev")"

setup
FAKE_STATUS="[$(repo 1 0 0 0 '' '' '')]"
export FAKE_STATUS
assert_eq "キャッシュがなければ、取り直している間は … を出す" "🛠 …" "$("$bin/tmux-claude-auto-dev")"
wait_cache
assert_eq "取り直したら件数を出す" "🛠 🙋1" "$("$bin/tmux-claude-auto-dev")"

setup
cat > "$tmp/status" <<'EOF'
#!/bin/bash
echo "status $*" >> "$FAKE_LOG"
exit 1
EOF
echo "[$(repo 0 0 0 1 '' '' '')]" > "$cache"
touch -t 202601010000 "$cache"
"$bin/tmux-claude-auto-dev" >/dev/null
sleep 0.5
assert_eq "取り直しに失敗したら、前のキャッシュを残す" "🛠 📥1" "$("$bin/tmux-claude-auto-dev")"

# ---- ポップアップ ----
setup
popup=$("$bin/tmux-claude-auto-dev" --popup)
assert_eq "ポップアップに凡例を出す" "yes" "$(echo "$popup" | grep -q '🙋 判断待ちの Issue' && echo yes || echo no)"
assert_eq "ポップアップに状況の全文を出す" "yes" "$(echo "$popup" | grep -q '状況の全文' && echo yes || echo no)"

[ "$failures" -eq 0 ] || exit 1
