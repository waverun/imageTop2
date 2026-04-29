import SwiftUI

struct DeveloperFeedbackView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("developerFeedbackEmail") private var savedFeedbackEmail = ""
    @AppStorage("developerFeedbackUserID") private var feedbackUserID = UUID().uuidString

    private let adminEmail = "sephraya.ray@gmail.com"
    private let functionsRegion = "us-central1"
    private let firebaseProjectID = "cipelume"

    @State private var rating: Int = 0
    @State private var message: String = ""
    @State private var email: String = ""
    @State private var sending = false
    @State private var statusMessage = ""
    @State private var statusIsError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Send Feedback")
                .font(.headline)

            HStack(spacing: 6) {
                Text("Rating:")
                ForEach(1...5, id: \.self) { star in
                    Button(action: { rating = star }) {
                        Image(systemName: star <= rating ? "star.fill" : "star")
                            .foregroundColor(.yellow)
                    }
                    .buttonStyle(.plain)
                }
                Button("Clear") { rating = 0 }
                    .buttonStyle(.link)
            }

            TextField("Email (optional)", text: $email)
                .textFieldStyle(.roundedBorder)

            TextField("Message (optional)", text: $message, axis: .vertical)
                .lineLimit(5, reservesSpace: true)
                .textFieldStyle(.roundedBorder)

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundColor(statusIsError ? .red : .green)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .disabled(sending)
                Button("Send") {
                    Task { await sendFeedback() }
                }
                .disabled(sending)
            }
        }
        .padding(16)
        .frame(width: 420, height: 260)
        .onAppear {
            email = savedFeedbackEmail
        }
    }

    private func isValidEmail(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let pattern = #"^[A-Z0-9a-z._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }

    @MainActor
    private func sendFeedback() async {
        statusMessage = ""
        statusIsError = false
        sending = true
        defer { sending = false }

        let projectID = firebaseProjectID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !projectID.isEmpty, projectID != "YOUR_PROJECT_ID" else {
            statusIsError = true
            statusMessage = "Missing Firebase project ID."
            return
        }
        let functionURL = "https://\(functionsRegion)-\(projectID).cloudfunctions.net/sendMail"

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let userEmail = isValidEmail(trimmedEmail) ? trimmedEmail : nil
        if let validEmail = userEmail {
            savedFeedbackEmail = validEmail
        }

        do {
            let normalizedRating = rating == 0 ? nil : min(max(rating, 1), 5)
            let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
            let ratingText = normalizedRating != nil ? "\(normalizedRating!)/5" : "not provided"

            let adminLines: [String] = [
                "New developer feedback was submitted.",
                "",
                "Rating: \(ratingText)",
                "User email: \(userEmail ?? "unknown")",
                trimmedMessage.isEmpty ? "Message: none" : "Message: \(trimmedMessage)"
            ]

            let adminMailer = DeveloperFeedbackMailer(
                functionURLString: functionURL,
                toEmail: adminEmail
            )
            try await adminMailer.sendMail(
                subject: normalizedRating != nil ? "Developer feedback: \(ratingText)" : "Developer feedback",
                message: adminLines.joined(separator: "\n"),
                replyTo: userEmail
            )

            if let userEmail {
                let userMailer = DeveloperFeedbackMailer(
                    functionURLString: functionURL,
                    toEmail: userEmail
                )
                let thanksMessage = "Thank you for your feedback. We appreciate your help improving CipeLume."
                try await userMailer.sendMail(
                    subject: "Thank you for your feedback",
                    message: thanksMessage,
                    replyTo: nil
                )
            }

            statusMessage = "Feedback sent successfully."
        } catch {
            statusIsError = true
            statusMessage = "Send failed: \(error.localizedDescription)"
        }
    }
}
