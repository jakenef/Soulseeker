import Foundation

enum DownloadStatus {
    case queued
    case searching
    case downloading(progress: Double)
    case done
    case failed(message: String)
}

extension DownloadStatus: Equatable {
    static func == (lhs: DownloadStatus, rhs: DownloadStatus) -> Bool {
        switch (lhs, rhs) {
        case (.queued, .queued): return true
        case (.searching, .searching): return true
        case (.downloading(let a), .downloading(let b)): return a == b
        case (.done, .done): return true
        case (.failed(let a), .failed(let b)): return a == b
        default: return false
        }
    }

    var isQueued: Bool {
        if case .queued = self { return true }
        return false
    }
}

struct DownloadItem: Identifiable {
    let id = UUID()
    let label: String
    let command: [String]
    var status: DownloadStatus = .queued
    var rawLog: [String] = []
}
