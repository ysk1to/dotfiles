#!/bin/bash
# 撮影前のチェック。権限と Kindle の状態を key=value 形式で出力し、ウィンドウのプレビュー画像を保存する。
# Kindle を前面に出したりキー操作したりはしない。
# 使い方: preflight.sh [プレビュー画像の保存先]
set -euo pipefail

BUNDLE_ID="com.amazon.Lassen"
SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
PREVIEW="${1:-${TMPDIR:-/tmp}/kindle-capture-preview.png}"

info="$(swift "$SKILL_DIR/window_info.swift")"
echo "$info"

if ! grep -q '^kindle=running$' <<<"$info"; then
	exit 0
fi

# ページ送りのキー操作には、実行元アプリのアクセシビリティ許可が必要。
# 許可がないとウィンドウ属性の取得が -25211 で失敗する（ウィンドウがないだけなら -1719）
if osascript -e "tell application \"System Events\" to get position of front window of (first process whose bundle identifier is \"$BUNDLE_ID\")" 2>&1 | grep -q -- '-25211'; then
	echo "accessibility=ng"
else
	echo "accessibility=ok"
fi

window_id="$(sed -n 's/^window_id=//p' <<<"$info")"
if [[ -n "$window_id" ]]; then
	# -l はウィンドウを前面に出さずに撮影できる
	screencapture -x -o -l "$window_id" "$PREVIEW"
	echo "preview=$PREVIEW"
	echo "preview_pixels=$(sips -g pixelWidth "$PREVIEW" | awk '/pixelWidth/ {print $2}'),$(sips -g pixelHeight "$PREVIEW" | awk '/pixelHeight/ {print $2}')"
fi
