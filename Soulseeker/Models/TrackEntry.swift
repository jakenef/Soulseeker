import Foundation

struct TrackEntry: Identifiable, Equatable {
    var id = UUID()
    var artist: String = ""
    var title: String = ""
}
