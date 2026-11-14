// 指定ディレクトリ内の画像をファイル名順に並べ、1つのPDFにまとめる。
// 使い方: swift make_pdf.swift <画像ディレクトリ> <出力PDF>
import AppKit
import PDFKit

let args = CommandLine.arguments
guard args.count == 3 else {
    FileHandle.standardError.write("使い方: swift make_pdf.swift <画像ディレクトリ> <出力PDF>\n".data(using: .utf8)!)
    exit(1)
}

let inputDir = URL(fileURLWithPath: args[1])
let outputURL = URL(fileURLWithPath: args[2])
let extensions: Set<String> = ["png", "jpg", "jpeg"]

let files = try FileManager.default
    .contentsOfDirectory(at: inputDir, includingPropertiesForKeys: nil)
    .filter { extensions.contains($0.pathExtension.lowercased()) }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }

let document = PDFDocument()
for file in files {
    guard let image = NSImage(contentsOf: file), let page = PDFPage(image: image) else {
        FileHandle.standardError.write("読み込めない画像をスキップしました: \(file.lastPathComponent)\n".data(using: .utf8)!)
        continue
    }
    document.insert(page, at: document.pageCount)
}

guard document.pageCount > 0, document.write(to: outputURL) else {
    FileHandle.standardError.write("PDFの作成に失敗しました\n".data(using: .utf8)!)
    exit(1)
}
