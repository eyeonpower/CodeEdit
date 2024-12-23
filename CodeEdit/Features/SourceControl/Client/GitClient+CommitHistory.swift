//
//  GitClient+CommitHistory.swift
//  CodeEdit
//
//  Created by Albert Vinizhanau on 10/20/23.
//

import Foundation

extension GitClient {
    /// Gets the commit history log for the specified branch or file
    /// - Parameters:
    ///   - branchName: Name of the branch
    ///   - maxCount: Maximum amount of entries to get
    ///   - fileLocalPath: Optional path of file to get history for
    /// - Returns: Array of git commits
    func getCommitHistory(
        branchName: String? = nil,
        maxCount: Int? = nil,
        fileLocalPath: String? = nil,
        showMergeCommits: Bool = false
    ) async throws -> [GitCommit] {
        let branchString = branchName != nil ? "\"\(branchName ?? "")\"" : ""
        let fileString = fileLocalPath != nil ? "\"\(fileLocalPath ?? "")\"" : ""
        let countString = maxCount != nil ? "-n \(maxCount ?? 0)" : ""

        let dateFormatter = DateFormatter()

        // Can't use `Locale.current`, since it'd give a nil date outside the US
        dateFormatter.locale = Locale(identifier: Locale.current.identifier)
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"

        let output = try await run(
            """
            log \(showMergeCommits ? "" : "--no-merges") -z \
            --pretty=%h¦%H¦%s¦%aN¦%ae¦%cn¦%ce¦%aD¦%b¦%D¦ \
            \(countString) \(branchString) -- \(fileString)
            """.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let remoteURL = try await getRemoteURL()

        return output
            .split(separator: "\0")
            .map { line -> GitCommit in
                let parameters = String(line).components(separatedBy: "¦")
                let infoRef = parameters[safe: 9]
                var refs: [String] = []
                var tag = ""
                if let infoRef = infoRef {
                    if infoRef.contains("tag:") {
                        tag = infoRef.components(separatedBy: "tag:")[1].trimmingCharacters(in: .whitespaces)
                    } else {
                        refs = infoRef.split(separator: ",").compactMap {
                            var element = String($0)
                            if element.contains("origin/HEAD") { return nil }
                            if element.contains("HEAD -> ") {
                                element = element.replacingOccurrences(of: "HEAD -> ", with: "")
                            }
                            return element.trimmingCharacters(in: .whitespaces)
                        }
                    }
                }

                return GitCommit(
                    hash: parameters[safe: 0] ?? "",
                    commitHash: parameters[safe: 1] ?? "",
                    message: parameters[safe: 2] ?? "",
                    author: parameters[safe: 3] ?? "",
                    authorEmail: parameters[safe: 4] ?? "",
                    committer: parameters[safe: 5] ?? "",
                    committerEmail: parameters[safe: 6] ?? "",
                    body: parameters[safe: 8] ?? "",
                    refs: refs,
                    tag: tag,
                    remoteURL: remoteURL,
                    date: dateFormatter.date(from: parameters[safe: 7] ?? "") ?? Date()
                )
            }
    }
}
