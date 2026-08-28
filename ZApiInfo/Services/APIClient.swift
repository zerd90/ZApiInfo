import Foundation

enum APIClient {
    struct FetchResult: Sendable {
        var data: Data
        var statusCode: Int
        var duration: TimeInterval
        var url: String
    }

    static func get(
        url: URL,
        apiKey: String,
        extraHeader: (String, String)?,
        timeout: TimeInterval
    ) async throws -> FetchResult {
        let started = Date()
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedKey.isEmpty {
            request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        }
        if let extraHeader {
            request.setValue(extraHeader.1, forHTTPHeaderField: extraHeader.0)
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.httpAdditionalHeaders = ["Accept": "application/json"]
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw AppError.from(urlError: error)
        } catch {
            throw AppError.network
        }

        let duration = Date().timeIntervalSince(started)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let result = FetchResult(
            data: data,
            statusCode: status,
            duration: duration,
            url: redactedURL(url)
        )
        if status == 401 { throw AppError.unauthorized }
        if status == 403 { throw AppError.forbidden }
        if !(200..<300).contains(status) { throw AppError.http(status) }
        return result
    }

    static func redactedURL(_ url: URL) -> String {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let items = components?.queryItems, !items.isEmpty {
            components?.queryItems = items.map { item in
                let name = item.name.lowercased()
                if name.contains("key") || name.contains("token") || name.contains("secret") {
                    return URLQueryItem(name: item.name, value: "***")
                }
                return item
            }
        }
        return components?.string ?? url.absoluteString
    }
}
