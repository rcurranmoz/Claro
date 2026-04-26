import Foundation
import UIKit

struct AnalysisService {
    static let shared = AnalysisService()

    private var endpoint: URL { Config.workerURL }
    private let model = "claude-sonnet-4-6"

    func analyze(document: HealthDocument) async throws -> DocumentAnalysis {
        guard let imageData = document.imageData,
              let image = UIImage(data: imageData) else {
            throw AnalysisError.noImage
        }

        let resized = resizeImage(image, maxDimension: 1568)
        guard let jpeg = resized.jpegData(compressionQuality: 0.85) else {
            throw AnalysisError.imageProcessingFailed
        }

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "system": systemPrompt,
            "messages": [[
                "role": "user",
                "content": [
                    [
                        "type": "image",
                        "source": [
                            "type": "base64",
                            "media_type": "image/jpeg",
                            "data": jpeg.base64EncodedString()
                        ]
                    ],
                    [
                        "type": "text",
                        "text": "This is a \(document.type.rawValue). Analyze it and respond with JSON only."
                    ]
                ]
            ]]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.workerSecret, forHTTPHeaderField: "X-Claro-Secret")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "unknown"
            throw AnalysisError.apiError("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0): \(body)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = (json["content"] as? [[String: Any]])?.first,
              let text = content["text"] as? String else {
            throw AnalysisError.parseError("Unexpected response shape")
        }

        return try decodeAnalysis(from: text)
    }

    // MARK: - Insurance Card Extraction

    struct InsuranceCardInfo {
        let insurerName: String
        let planName: String
        let memberId: String
    }

    func extractInsuranceCard(image: UIImage) async throws -> InsuranceCardInfo {
        let resized = resizeImage(image, maxDimension: 1568)
        guard let jpeg = resized.jpegData(compressionQuality: 0.85) else {
            throw AnalysisError.imageProcessingFailed
        }

        let prompt = """
        This is an insurance card. Extract the following and respond with ONLY a JSON object:
        {
          "insurerName": "the insurance company name",
          "planName": "the plan name or type (e.g. PPO Gold, HMO)",
          "memberId": "the member ID or subscriber ID number"
        }
        If a field is not visible, use an empty string. No markdown, no explanation.
        """

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 256,
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "image", "source": ["type": "base64", "media_type": "image/jpeg",
                                                  "data": jpeg.base64EncodedString()]],
                    ["type": "text", "text": prompt]
                ]
            ]]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.workerSecret, forHTTPHeaderField: "X-Claro-Secret")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AnalysisError.apiError("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = (json["content"] as? [[String: Any]])?.first,
              let text = content["text"] as? String else {
            throw AnalysisError.parseError("Unexpected response shape")
        }

        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            cleaned = cleaned.components(separatedBy: "\n").dropFirst().joined(separator: "\n")
            if cleaned.hasSuffix("```") { cleaned = String(cleaned.dropLast(3)) }
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let cardData = cleaned.data(using: .utf8),
              let cardJson = try JSONSerialization.jsonObject(with: cardData) as? [String: Any] else {
            throw AnalysisError.parseError("Could not parse card response")
        }

        return InsuranceCardInfo(
            insurerName: cardJson["insurerName"] as? String ?? "",
            planName:    cardJson["planName"]    as? String ?? "",
            memberId:    cardJson["memberId"]    as? String ?? ""
        )
    }

    // MARK: - Dispute Letter

    func generateDisputeLetter(for document: HealthDocument, issues: [FlaggedIssue]) async throws -> String {
        guard let imageData = document.imageData,
              let image = UIImage(data: imageData) else {
            throw AnalysisError.noImage
        }
        let resized = resizeImage(image, maxDimension: 1568)
        guard let jpeg = resized.jpegData(compressionQuality: 0.85) else {
            throw AnalysisError.imageProcessingFailed
        }
        let issueList = issues.map { "• \($0.title): \($0.detail)" }.joined(separator: "\n")
        let prompt = """
        Based on this medical billing document and the issues listed below, write a professional \
        dispute letter the patient can send to their provider or insurance company.

        Issues to address:
        \(issueList)

        Write a complete, ready-to-mail letter. Use placeholders like [YOUR NAME], [YOUR ADDRESS], \
        [DATE], [PROVIDER/INSURER NAME AND ADDRESS] where the patient must fill in their information. \
        Be firm but courteous. Reference specific amounts and dates visible in the document. \
        Cite applicable patient rights and laws where relevant (No Surprises Act, state balance \
        billing protections, ACA protections). End with a clear request and a deadline for response.
        """
        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 1500,
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "image", "source": ["type": "base64", "media_type": "image/jpeg",
                                                  "data": jpeg.base64EncodedString()]],
                    ["type": "text", "text": prompt]
                ]
            ]]
        ]
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json",   forHTTPHeaderField: "Content-Type")
        request.setValue(Config.workerSecret,  forHTTPHeaderField: "X-Claro-Secret")
        request.setValue("2023-06-01",         forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AnalysisError.apiError("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = (json["content"] as? [[String: Any]])?.first,
              let text = content["text"] as? String else {
            throw AnalysisError.parseError("Unexpected response shape")
        }
        return text
    }

    // MARK: - Private

    private func decodeAnalysis(from text: String) throws -> DocumentAnalysis {
        // Strip markdown code fences if Claude wrapped the JSON
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            cleaned = cleaned
                .components(separatedBy: "\n")
                .dropFirst()
                .joined(separator: "\n")
            if cleaned.hasSuffix("```") {
                cleaned = String(cleaned.dropLast(3))
            }
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else {
            throw AnalysisError.parseError("Could not encode response text")
        }
        do {
            return try JSONDecoder().decode(DocumentAnalysis.self, from: data)
        } catch {
            let preview = String(cleaned.prefix(300))
            throw AnalysisError.parseError("JSON decode failed: \(error.localizedDescription)\n\nResponse preview:\n\(preview)")
        }
    }

    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        guard max(size.width, size.height) > maxDimension else { return image }
        let scale = maxDimension / max(size.width, size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        return UIGraphicsImageRenderer(size: newSize).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    // MARK: - System Prompt

    private let systemPrompt = """
    You are an expert medical billing advocate with deep knowledge of CPT codes, ICD-10 codes, \
    insurance EOBs, patient rights, appeal processes, and common billing errors.

    Analyze the provided health document and respond with ONLY a valid JSON object — no markdown, \
    no preamble, no explanation outside the JSON.

    Schema:
    {
      "title": "short descriptive label, 3-6 words, e.g. 'UCSF ER Visit Feb 2026' or 'Anthem EOB – Knee Surgery'",
      "summary": "2-3 sentences in plain English: what is this document and what does the patient need to know right now",
      "lineItems": [
        {
          "code": "CPT or procedure code if visible, or null",
          "rawDescription": "exact text from the document",
          "plainDescription": "what this actually means in plain English",
          "amount": dollar amount as a number, or null
        }
      ],
      "positiveFindings": [
        {
          "title": "short label for something that looks correct or favorable",
          "detail": "why this is good news for the patient"
        }
      ],
      "flaggedIssues": [
        {
          "title": "short issue name",
          "detail": "what the issue is, why it matters, what to do about it",
          "severity": "alert (needs immediate action/dispute), warning (worth checking), or info (minor note)"
        }
      ],
      "actionItems": [
        {
          "title": "what the patient should do",
          "detail": "how to do it, who to call, what to say, any deadlines",
          "urgency": "high or medium or low"
        }
      ],
      "totalBilled": total amount billed as a number or null,
      "patientOwes": amount the patient is actually responsible for as a number or null
    }

    For positiveFindings, note things like: insurance adjustment correctly applied, \
    no duplicate charges found, charges align with diagnosis, deductible applied correctly, \
    provider is in-network, payment processed. Only include if genuinely confirmed — do not invent.

    For flaggedIssues: use severity "alert" for potential errors requiring dispute or escalation, \
    "warning" for things that seem off but need verification, "info" for general notes. \
    Actively look for: duplicate charges, unbundling, upcoding, balance billing violations, \
    charges exceeding usual and customary rates, missing insurance adjustments, incorrect \
    application of deductible or copay, billing for services not rendered.

    For actionItems, include: appeal deadlines if relevant, who to call (insurer vs provider), \
    requests for itemized bills, and anything time-sensitive.

    If the image is unclear or not a medical document, return a summary explaining that and empty arrays for the other fields.
    """

    // MARK: - Errors

    enum AnalysisError: LocalizedError {
        case noImage
        case imageProcessingFailed
        case apiError(String)
        case parseError(String)

        var errorDescription: String? {
            switch self {
            case .noImage:                  return "No image found for this document."
            case .imageProcessingFailed:    return "Could not process the image."
            case .apiError(let msg):        return "Analysis service error: \(msg)"
            case .parseError(let msg):      return "Could not read analysis response: \(msg)"
            }
        }
    }
}
