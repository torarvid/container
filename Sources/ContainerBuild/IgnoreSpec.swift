//===----------------------------------------------------------------------===//
// Copyright © 2025 Apple Inc. and the container project authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//===----------------------------------------------------------------------===//

import Foundation

/// A type that handles .dockerignore pattern matching
struct IgnoreSpec {
    private let patterns: [String]

    /// Initialize an IgnoreSpec from .dockerignore file data
    /// - Parameter data: The contents of a .dockerignore file
    init(_ data: Data) {
        guard let contents = String(data: data, encoding: .utf8) else {
            self.patterns = []
            return
        }

        self.patterns = contents
            .split(separator: "\n")
            .map { line in line.trimmingCharacters(in: .whitespaces) }
            .filter { line in !line.isEmpty && !line.hasPrefix("#") }
            .map { String($0) }
    }

    /// Check if a file path should be ignored based on .dockerignore patterns
    /// - Parameters:
    ///   - relPath: The relative path to check
    ///   - isDirectory: Whether the path is a directory
    /// - Returns: true if the path should be ignored, false otherwise
    func shouldIgnore(relPath: String, isDirectory: Bool) throws -> Bool {
        guard !patterns.isEmpty else {
            return false
        }

        let globber = Globber(URL(fileURLWithPath: "/"))

        for pattern in patterns {
            // Try to match the pattern against the path
            let pathToMatch = isDirectory ? relPath + "/" : relPath

            let matchesWithSlash = try globber.glob(pathToMatch, pattern)
            if matchesWithSlash {
                return true
            }

            // Also try without the trailing slash for directories
            if isDirectory {
                let matchesWithoutSlash = try globber.glob(relPath, pattern)
                if matchesWithoutSlash {
                    return true
                }
            }

            // Check if pattern matches with ** prefix for nested paths
            let shouldAddPrefix = !pattern.hasPrefix("**/") && !pattern.hasPrefix("/")
            if shouldAddPrefix {
                let matchesWithPrefix = try globber.glob(pathToMatch, "**/" + pattern)
                if matchesWithPrefix {
                    return true
                }
            }
        }

        return false
    }
}
