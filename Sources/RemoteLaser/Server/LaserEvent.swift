import Foundation

struct LaserEvent: Codable {
    enum Kind: String, Codable { case move, down, up, hide }

    var type: Kind
    var x: Double?
    var y: Double?
}