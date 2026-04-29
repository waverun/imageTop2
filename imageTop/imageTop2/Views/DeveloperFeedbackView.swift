import SwiftUI

struct DeveloperFeedbackView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("developerFeedbackEmail") private var savedFeedbackEmail = ""
    @AppStorage("developerFeedbackUserID") private var feedbackUserID = UUID().uuidString
    @AppStorage("developerFeedbackFunctionURL") private var functionURL = ""

    private let adminEmail = "sephraya.ray@gmail.com"

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

        guard !functionURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            statusIsError = true
            statusMessage = "Missing sendMail function URL."
            return
        }

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let userEmail = isValidEmail(trimmedEmail) ? trimmedEmail : nil
        if let validEmail = userEmail {
            savedFeedbackEmail = validEmail
        }

        do {
            let adminMailer = DeveloperFeedbackMailer(
                functionURLString: functionURL,
                toEmail: adminEmail
            )

            try await adminMailer.sendFeedbackEmail(
                rating: rating == 0 ? nil : rating,
                message: message,
                userId: feedbackUserID,
                userEmail: userEmail,
                userDisplayName: nil
            )

            if let userEmail {
                let userMailer = DeveloperFeedbackMailer(
                    functionURLString: functionURL,
                    toEmail: userEmail
                )
                try await userMailer.sendFeedbackEmail(
                    rating: rating == 0 ? nil : rating,
                    message: message,
                    userId: feedbackUserID,
                    userEmail: userEmail,
                    userDisplayName: nil
                )
            }

            statusMessage = "Feedback sent successfully."
        } catch {
            statusIsError = true
            statusMessage = "Send failed: \(error.localizedDescription)"
        }
    }
}
