#!/bin/bash
# Kindle for Mac の表示画面を1ページずつ撮影し、1つのPDFにまとめる。
# DRMの解除は行わない。個人利用の範囲で使うこと。
set -euo pipefail

BUNDLE_ID="com.amazon.Lassen"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ===== デフォルト設定 =====
MAX_PAGES=1000      # 撮影する最大ページ数（最終ページは自動検出して止まる）
DIRECTION="left"    # left=←（縦書きの日本語本） / right=→（横書きの本）
WAIT_SEC=1.2        # ページ送り後の待ち時間（秒）
START_DELAY=3       # 開始までの待ち時間（秒）
SAME_LIMIT=3        # 同じ画像がこの回数続いたら最終ページとみなす
FOCUS_RETRY=3       # Kindle 以外が前面に出たとき、Kindle を前面に戻す試行回数
REGION=""           # 撮影範囲 "x,y,w,h"（空ならKindleのウィンドウ全体）
OUTPUT=""           # 出力PDFのパスかディレクトリ（空ならデスクトップに日時付きで保存）
# ==========================

usage() {
	cat <<EOF
使い方: $(basename "$0") [オプション]

  -n ページ数   撮影する最大ページ数（デフォルト: ${MAX_PAGES}）
  -d 方向       ページ送りの方向 left|right（デフォルト: ${DIRECTION}）
  -w 秒         ページ送り後の待ち時間（デフォルト: ${WAIT_SEC}）
  -r x,y,w,h    撮影範囲（デフォルト: Kindleのウィンドウ全体）
  -o パス       出力PDFのパス（デフォルト: ~/Desktop/kindle_日時.pdf）
                ディレクトリを指定するとその中に kindle_日時.pdf で保存する。
                拡張子を省くと .pdf を付ける。同名のファイルがあれば末尾に日時を付ける
  -h            このヘルプを表示

事前に Kindle で本を開き、撮影を始めたいページを表示しておくこと。
撮影中は Kindle を前面に出したままにすること（ほかのアプリを操作しない）。
EOF
}

while getopts "n:d:w:r:o:h" opt; do
	case "$opt" in
		n) MAX_PAGES="$OPTARG" ;;
		d) DIRECTION="$OPTARG" ;;
		w) WAIT_SEC="$OPTARG" ;;
		r) REGION="$OPTARG" ;;
		o) OUTPUT="$OPTARG" ;;
		h) usage; exit 0 ;;
		*) usage; exit 1 ;;
	esac
done

case "$DIRECTION" in
	left) KEY_CODE=123 ;;
	right) KEY_CODE=124 ;;
	*) echo "エラー: -d には left か right を指定してください" >&2; exit 1 ;;
esac

STAMP="$(date +%Y%m%d_%H%M%S)"

# 出力先を絶対パスのファイル名に決める。撮影を始める前に、書き込めるかも確かめる
if [[ -z "$OUTPUT" ]]; then
	OUTPUT="$HOME/Desktop"
fi
if [[ -d "$OUTPUT" || "$OUTPUT" == */ ]]; then
	OUTPUT="${OUTPUT%/}/kindle_${STAMP}.pdf"
elif [[ "$(tr '[:upper:]' '[:lower:]' <<<"${OUTPUT##*.}")" != "pdf" ]]; then
	OUTPUT="${OUTPUT}.pdf"
fi
OUTPUT_DIR="$(dirname "$OUTPUT")"
if [[ ! -d "$OUTPUT_DIR" ]]; then
	echo "エラー: 出力先のディレクトリがありません: $OUTPUT_DIR" >&2
	exit 1
fi
if [[ ! -w "$OUTPUT_DIR" ]]; then
	echo "エラー: 出力先のディレクトリに書き込めません: $OUTPUT_DIR" >&2
	exit 1
fi
OUTPUT="$(cd "$OUTPUT_DIR" && pwd)/$(basename "$OUTPUT")"
if [[ -e "$OUTPUT" ]]; then
	OUTPUT="${OUTPUT%.*}_${STAMP}.pdf"
fi
echo "出力先: $OUTPUT"

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kindle-capture.XXXXXX")"
# 撮影した画像は、終了時（PDF作成後・中断時とも）にディレクトリごと削除する
cleanup() {
	rm -rf "$WORK_DIR"
}
trap cleanup EXIT

activate_kindle() {
	osascript -e "tell application id \"$BUNDLE_ID\" to activate" >/dev/null
}

# Kindle の最前面ウィンドウの範囲を "x,y,w,h" で返す
kindle_window_region() {
	osascript <<EOF
tell application "System Events"
	set p to first process whose bundle identifier is "$BUNDLE_ID"
	set {x, y} to position of front window of p
	set {w, h} to size of front window of p
	return (x as text) & "," & (y as text) & "," & (w as text) & "," & (h as text)
end tell
EOF
}

turn_page() {
	osascript -e "tell application \"System Events\" to key code $KEY_CODE" >/dev/null
}

kindle_is_frontmost() {
	[[ "$(osascript -e 'tell application "System Events" to get bundle identifier of first process whose frontmost is true')" == "$BUNDLE_ID" ]]
}

# キー入力と撮影は前面のアプリに対して行われるので、Kindle が前面にいることを確かめる。
# ほかのアプリが前面に出ていたら Kindle を前面に戻し、戻せなければ失敗を返す
ensure_kindle_frontmost() {
	local n
	for ((n = 0; n <= FOCUS_RETRY; n++)); do
		if kindle_is_frontmost; then
			return 0
		fi
		if [[ "$n" -eq 0 ]]; then
			echo
			echo "警告: Kindle 以外のアプリが前面に出たので、Kindle を前面に戻します。"
		fi
		activate_kindle
		sleep 1
	done
	return 1
}

activate_kindle
echo "${START_DELAY}秒後に撮影を始めます。途中で止めるには Ctrl+C を押してください。"
sleep "$START_DELAY"
activate_kindle
sleep 1

if [[ -z "$REGION" ]]; then
	REGION="$(kindle_window_region)"
fi
echo "撮影範囲: $REGION"

prev_hash=""
same_count=0
page=0
shot=0
retake=0
interrupted=0

for ((i = 1; i <= MAX_PAGES; i++)); do
	if ! ensure_kindle_frontmost; then
		interrupted=1
		break
	fi
	shot=$((shot + 1))
	file="$WORK_DIR/$(printf '%05d' "$shot").png"
	screencapture -x -o -R "$REGION" "$file"

	# 撮影中に前面のアプリが変わっていたら、その画像は捨てて撮り直す
	if ! kindle_is_frontmost; then
		rm -f "$file"
		retake=$((retake + 1))
		if [[ "$retake" -gt "$FOCUS_RETRY" ]]; then
			interrupted=1
			break
		fi
		i=$((i - 1))
		continue
	fi
	retake=0

	hash="$(md5 -q "$file")"
	if [[ "$hash" == "$prev_hash" ]]; then
		rm -f "$file"
		same_count=$((same_count + 1))
		if [[ "$same_count" -ge "$SAME_LIMIT" ]]; then
			echo
			echo "ページが変わらなくなったので、最終ページとみなして終了します。"
			break
		fi
	else
		same_count=0
		prev_hash="$hash"
		page=$((page + 1))
		printf '\r撮影中: %d ページ' "$page"
	fi

	if ! ensure_kindle_frontmost; then
		interrupted=1
		break
	fi
	turn_page
	sleep "$WAIT_SEC"
done
echo

if [[ "$page" -eq 0 ]]; then
	echo "エラー: 1ページも撮影できませんでした" >&2
	exit 1
fi

# 途中で止まったときは、撮れたところまでをファイル名で区別して保存する
if [[ "$interrupted" -eq 1 ]]; then
	OUTPUT="${OUTPUT%.*}_途中まで.pdf"
	echo "エラー: Kindle を前面に戻せなかったので、撮影を途中で止めました。" >&2
fi

echo "PDFを作成しています..."
swift "$SCRIPT_DIR/make_pdf.swift" "$WORK_DIR" "$OUTPUT"

if [[ "$interrupted" -eq 1 ]]; then
	echo "途中までのPDF: ${OUTPUT}（${page}ページ）" >&2
	osascript -e "display notification \"途中で止まりました（${page}ページまで）\" with title \"Kindle Capture\"" >/dev/null
	exit 2
fi
echo "完了: ${OUTPUT}（${page}ページ）"
osascript -e "display notification \"${page}ページのPDFを作成しました\" with title \"Kindle Capture\"" >/dev/null
