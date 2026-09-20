import Foundation

extension URL {
    /// Builds a `URL` from a string that is known-good at authoring time.
    ///
    /// Preferable to `URL(string:)!` because the failure names the offending
    /// literal instead of trapping anonymously. Only use it for URLs written in
    /// source; anything derived from data should stay optional and be handled.
    static func literal(_ string: String) -> URL {
        guard let url = URL(string: string) else {
            preconditionFailure("Malformed URL literal: \(string)")
        }
        return url
    }
}
