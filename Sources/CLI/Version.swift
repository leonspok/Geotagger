import Foundation

enum Version {
    static let number = "VERSION_NUMBER"
    static let commitHash = "GIT_COMMIT_HASH"

    static var full: String {
        return "v\(number) (\(commitHash))"
    }
}
