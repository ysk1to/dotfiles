// PDF から指定したページを削除して上書き保存する（PDFKitを使用するので追加のインストール不要）。
// 使い方: swift remove_pages.swift <PDF> <ページ番号>...
// ページ番号に last を指定すると最後のページになる。
import Foundation
import PDFKit

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write("使い方: swift remove_pages.swift <PDF> <ページ番号>...\n".data(using: .utf8)!)
    exit(1)
}
let url = URL(fileURLWithPath: args[1])
guard let document = PDFDocument(url: url) else {
    FileHandle.standardError.write("PDFを開けません: \(args[1])\n".data(using: .utf8)!)
    exit(1)
}
let count = document.pageCount

var numbers = Set<Int>()
for arg in args[2...] {
    guard let number = arg == "last" ? count : Int(arg), (1...count).contains(number) else {
        FileHandle.standardError.write("ページがありません: \(arg)（全\(count)ページ）\n".data(using: .utf8)!)
        exit(1)
    }
    numbers.insert(number)
}
guard numbers.count < count else {
    FileHandle.standardError.write("すべてのページを削除することはできません\n".data(using: .utf8)!)
    exit(1)
}

// 後ろから消すと、前のページの番号がずれない
for number in numbers.sorted(by: >) {
    document.removePage(at: number - 1)
}

// 書き出しに失敗しても元のPDFが壊れないよう、一時ファイルに書いてから置き換える
let temp = url.deletingLastPathComponent().appendingPathComponent(".\(url.lastPathComponent).tmp")
guard document.write(to: temp) else {
    FileHandle.standardError.write("PDFの書き出しに失敗しました\n".data(using: .utf8)!)
    exit(1)
}
_ = try FileManager.default.replaceItemAt(url, withItemAt: temp)
print("removed=\(numbers.sorted().map(String.init).joined(separator: ","))")
print("pages=\(document.pageCount)")
