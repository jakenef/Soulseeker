import Foundation
import Combine

@MainActor
class DownloadManager: ObservableObject {
    @Published var queue: [DownloadItem] = []

    private var activeProcess: Process?
    private var isRunning = false

    static let sldlSearchPaths: [String] = [
        "/opt/homebrew/bin/sldl",
        "/usr/local/bin/sldl",
        "/usr/bin/sldl",
        (ProcessInfo.processInfo.environment["HOME"] ?? "") + "/bin/sldl"
    ]

    static func detectSldlPath() -> String? {
        sldlSearchPaths.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    func enqueueTrack(artist: String, title: String,
                      user: String, pass: String,
                      path: String, format: String, sldlPath: String) {
        var args = [sldlPath, "artist=\(artist), title=\(title)",
                    "--user", user, "--pass", pass, "-p", path]
        if format != "Any" { args += ["--pref-format", format.lowercased()] }
        append(DownloadItem(label: "\(artist) \u{2013} \(title)", command: args))
    }

    func enqueueAlbum(artist: String, album: String,
                      user: String, pass: String,
                      path: String, format: String, sldlPath: String) {
        var args = [sldlPath, "artist=\(artist), album=\(album)",
                    "--user", user, "--pass", pass, "-p", path]
        if format != "Any" { args += ["--pref-format", format.lowercased()] }
        append(DownloadItem(label: "\(artist) \u{2013} \(album)", command: args))
    }

    func enqueuePlaylist(url: String,
                         user: String, pass: String,
                         path: String, format: String, sldlPath: String) {
        var args = [sldlPath, url, "--user", user, "--pass", pass, "-p", path]
        if format != "Any" { args += ["--pref-format", format.lowercased()] }
        append(DownloadItem(label: url, command: args))
    }

    private func append(_ item: DownloadItem) {
        queue.append(item)
        startNextIfIdle()
    }

    private func startNextIfIdle() {
        guard !isRunning,
              let idx = queue.indices.first(where: { queue[$0].status.isQueued }) else { return }
        run(index: idx)
    }

    private func run(index: Int) {
        isRunning = true
        queue[index].status = .searching

        let item = queue[index]
        guard !item.command.isEmpty else {
            queue[index].status = .failed(message: "Empty command")
            isRunning = false
            startNextIfIdle()
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: item.command[0])
        process.arguments = Array(item.command.dropFirst())

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let text = String(data: handle.availableData, encoding: .utf8) ?? ""
            guard !text.isEmpty else { return }
            Task { @MainActor [weak self] in self?.handleOutput(text, index: index) }
        }

        process.terminationHandler = { [weak self] p in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if p.terminationStatus == 0 {
                    self.queue[index].status = .done
                } else {
                    let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    let msg = String(data: errData, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown error"
                    self.queue[index].status = .failed(message: msg)
                }
                self.isRunning = false
                self.startNextIfIdle()
            }
        }

        do {
            try process.run()
            activeProcess = process
        } catch {
            queue[index].status = .failed(message: error.localizedDescription)
            isRunning = false
            startNextIfIdle()
        }
    }

    private func handleOutput(_ text: String, index: Int) {
        queue[index].rawLog.append(text)
        for line in text.components(separatedBy: .newlines) {
            if line.localizedCaseInsensitiveContains("Searching") {
                queue[index].status = .searching
            } else if let pct = parsePercent(from: line) {
                queue[index].status = .downloading(progress: pct)
            }
        }
    }

    private func parsePercent(from line: String) -> Double? {
        guard let range = line.range(of: #"\d+(?=\s*%)"#, options: .regularExpression) else { return nil }
        return Double(line[range]).map { $0 / 100.0 }
    }
}
