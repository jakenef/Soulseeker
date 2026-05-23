import Foundation

struct CSVImporter {
    static func parse(_ content: String) -> [TrackEntry] {
        let lines = content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return [] }

        var startIndex = 0
        let first = lines[0].lowercased()
        if first.contains("artist") && first.contains("title") {
            startIndex = 1
        }

        return lines[startIndex...].compactMap { line -> TrackEntry? in
            let parts = line.components(separatedBy: ",")
            guard parts.count >= 2 else { return nil }
            let artist = parts[0].trimmingCharacters(in: .whitespaces)
            let title = parts[1...].joined(separator: ",").trimmingCharacters(in: .whitespaces)
            guard !artist.isEmpty && !title.isEmpty else { return nil }
            return TrackEntry(artist: artist, title: title)
        }
    }
}
