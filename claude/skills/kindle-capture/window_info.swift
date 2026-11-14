// Kindle の最前面ウィンドウの情報を key=value 形式で出力する。
// アクセシビリティの許可は不要（ウィンドウ一覧は CGWindowList から取得する）。
// 使い方: swift window_info.swift
import AppKit
import CoreGraphics

let bundleID = "com.amazon.Lassen"

let pids = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).map { $0.processIdentifier }
guard !pids.isEmpty else {
    print("kindle=not_running")
    exit(0)
}
print("kindle=running")
print("screen_recording=\(CGPreflightScreenCaptureAccess() ? "ok" : "ng")")

// 別のデスクトップ（Space）にあるウィンドウも対象にする（kindle-capture.sh は Kindle を前面に出してから撮るので、そのまま撮影できる）。
// Kindle は本のウィンドウのほかに小さな補助ウィンドウも持つため、画面に表示中のものを優先し、その中で最も大きい通常ウィンドウ（layer 0）を使う
let list = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
func area(_ w: [String: Any]) -> CGFloat {
    guard let d = w[kCGWindowBounds as String] as? NSDictionary, let r = CGRect(dictionaryRepresentation: d) else { return 0 }
    return r.width * r.height
}
func onScreen(_ w: [String: Any]) -> Bool {
    (w[kCGWindowIsOnscreen as String] as? Bool) == true
}
let window = list
    .filter {
        ($0[kCGWindowOwnerPID as String] as? pid_t).map(pids.contains) == true
            && ($0[kCGWindowLayer as String] as? Int) == 0
    }
    .max { (onScreen($0) ? 1 : 0, area($0)) < (onScreen($1) ? 1 : 0, area($1)) }
guard let window,
      let id = window[kCGWindowNumber as String] as? Int,
      let boundsDict = window[kCGWindowBounds as String] as? NSDictionary,
      let bounds = CGRect(dictionaryRepresentation: boundsDict) else {
    print("window=none")
    exit(0)
}
print("window_id=\(id)")
print("window=\(Int(bounds.minX)),\(Int(bounds.minY)),\(Int(bounds.width)),\(Int(bounds.height))")
print("window_onscreen=\(onScreen(window) ? "yes" : "no")")
