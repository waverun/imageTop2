import Foundation

enum DeveloperFeedbackMailerError: LocalizedError {
    case invalidFunctionURL
    case invalidHTTPResponse
    case serverError(code: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .invalidFunctionURL:
            return "Invalid sendMail function URL."
        case .invalidHTTPResponse:
            return "No HTTP response from sendMail function."
        case let .serverError(code, body):
            return "sendMail HTTP \(code): \(body)"
        }
    }
}

final class DeveloperFeedbackMailer {
    private let functionURLString: String
    private let toEmail: String
    private let fromName: String
    private let timeout: TimeInterval

    init(
        functionURLString: String,
        toEmail: String,
        fromName: String = "CipeLume Feedback",
        timeout: TimeInterval = 30
    ) {
        self.functionURLString = functionURLString
        self.toEmail = toEmail
        self.fromName = fromName
        self.timeout = timeout
    }

    func sendFeedbackEmail(
        rating: Int?,
        message: String,
        userId: String,
        userEmail: String?,
        userDisplayName: String?
    ) async throws {
        guard let url = URL(string: functionURLString), !functionURLString.isEmpty else {
            throw DeveloperFeedbackMailerError.invalidFunctionURL
        }

        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = userEmail?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDisplayName = userDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let replyTo = (trimmedEmail?.isEmpty == false) ? trimmedEmail : nil
        let normalizedRating = rating.map { min(max($0, 1), 5) }
        let ratingText = normalizedRating != nil ? "\(normalizedRating!)/5" : "not provided"
        let subject = normalizedRating != nil ? "Developer feedback: \(ratingText)" : "Developer feedback"

        let lines: [String] = [
            "New developer feedback was submitted.",
            "",
            "Rating: \(ratingText)",
            "User ID: \(userId)",
            "User email: \(replyTo ?? "unknown")",
            "Display name: \((trimmedDisplayName?.isEmpty == false) ? trimmedDisplayName! : "unknown")",
            trimmedMessage.isEmpty ? "Message: none" : "Message: \(trimmedMessage)"
        ]

        let payload: [String: Any] = [
            "subject": subject,
            "message": lines.joined(separator: "\n"),
            "fromName": fromName,
            "to": toEmail,
            "replyTo": replyTo as Any
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw DeveloperFeedbackMailerError.invalidHTTPResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let serverText = String(data: data, encoding: .utf8) ?? ""
            throw DeveloperFeedbackMailerError.serverError(code: http.statusCode, body: serverText)
        }
    }
}
