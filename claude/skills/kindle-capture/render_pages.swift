// PDF の指定ページを PNG に書き出す（仕上がりの確認用。PDFKitを使用するので追加のインストール不要）。
// 使い方: swift render_pages.swift <PDF> <出力ディレクトリ> <ページ番号>...
// ページ番号に last を指定すると最後のページになる。
import AppKit
import PDFKit

let args = CommandLine.arguments
guard args.count >= 4, let document = PDFDocument(url: URL(fileURLWithPath: args[1])) else {
    FileHandle.standardError.write("使い方: swift render_pages.swift <PDF> <出力ディレクトリ> <ページ番号>...\n".data(using: .utf8)!)
    exit(1)
}
let outputDir = URL(fileURLWithPath: args[2])
print("pages=\(document.pageCount)")

for arg in args[3...] {
    guard let number = arg == "last" ? document.pageCount : Int(arg),
          let page = document.page(at: number - 1) else {
        FileHandle.standardError.write("ページがありません: \(arg)\n".data(using: .utf8)!)
        continue
    }
    let size = page.bounds(for: .mediaBox).size
    guard let image = page.thumbnail(of: size, for: .mediaBox).cgImage(forProposedRect: nil, context: nil, hints: nil),
          let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
        continue
    }
    let file = outputDir.appendingPathComponent(String(format: "page%05d.png", number))
    try png.write(to: file)
    print(file.path)
}
