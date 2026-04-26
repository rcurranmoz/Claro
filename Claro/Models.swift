import SwiftUI

// MARK: - Document Type

enum DocumentType: String, Codable, CaseIterable {
    case medicalBill = "Medical Bill"
    case eob = "Explanation of Benefits"
    case insuranceCard = "Insurance Card"
    case labResults = "Lab Results"
    case dischargeSummary = "Discharge Summary"
    case prescription = "Prescription"
    case other = "Document"

    var systemImage: String {
        switch self {
        case .medicalBill:      return "dollarsign.circle.fill"
        case .eob:              return "doc.text.fill"
        case .insuranceCard:    return "creditcard.fill"
        case .labResults:       return "cross.case.fill"
        case .dischargeSummary: return "house.fill"
        case .prescription:     return "pills.fill"
        case .other:            return "doc.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .medicalBill:      return .claroAccent
        case .eob:              return .cyan
        case .insuranceCard:    return Color(hex: "818CF8")
        case .labResults:       return .mint
        case .dischargeSummary: return .teal
        case .prescription:     return Color(hex: "C084FC")
        case .other:            return .claroSubtle
        }
    }
}

// MARK: - Analysis Types

struct ActionItem: Identifiable, Codable {
    let id: UUID
    let title: String
    let detail: String
    let urgency: Urgency

    enum Urgency: String, Codable {
        case high, medium, low
        init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self).lowercased()
            self = Urgency(rawValue: raw) ?? .low
        }
    }

    init(id: UUID = UUID(), title: String, detail: String, urgency: Urgency) {
        self.id = id; self.title = title; self.detail = detail; self.urgency = urgency
    }
}

struct LineItem: Identifiable, Codable {
    let id: UUID
    let code: String?
    let rawDescription: String
    let plainDescription: String
    let amount: Double?

    init(id: UUID = UUID(), code: String? = nil, rawDescription: String, plainDescription: String, amount: Double? = nil) {
        self.id = id; self.code = code; self.rawDescription = rawDescription
        self.plainDescription = plainDescription; self.amount = amount
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = (try? c.decodeIfPresent(UUID.self,   forKey: .id))            ?? UUID()
        code            = try? c.decodeIfPresent(String.self,  forKey: .code)
        rawDescription  = (try? c.decode(String.self, forKey: .rawDescription))         ?? ""
        plainDescription = (try? c.decode(String.self, forKey: .plainDescription))      ?? rawDescription
        if let d = try? c.decodeIfPresent(Double.self, forKey: .amount) {
            amount = d
        } else if let s = try? c.decodeIfPresent(String.self, forKey: .amount) {
            amount = Double(s.filter { $0.isNumber || $0 == "." })
        } else {
            amount = nil
        }
    }
}

struct FlaggedIssue: Identifiable, Codable {
    let id: UUID
    let title: String
    let detail: String
    let severity: Severity

    enum Severity: String, Codable {
        case alert   // red  — dispute or escalate now
        case warning // yellow — worth checking on
        case info    // green — informational, things look fine here
        init(from decoder: Decoder) throws {
            let raw = (try? decoder.singleValueContainer().decode(String.self).lowercased()) ?? "warning"
            self = Severity(rawValue: raw) ?? .warning
        }
    }

    init(id: UUID = UUID(), title: String, detail: String, severity: Severity = .warning) {
        self.id = id; self.title = title; self.detail = detail; self.severity = severity
    }

    init(from decoder: Decoder) throws {
        let c  = try decoder.container(keyedBy: CodingKeys.self)
        id       = (try? c.decodeIfPresent(UUID.self,   forKey: .id))    ?? UUID()
        title    = (try? c.decode(String.self, forKey: .title))           ?? ""
        detail   = (try? c.decode(String.self, forKey: .detail))          ?? ""
        severity = (try? c.decode(Severity.self, forKey: .severity))      ?? .warning
    }
}

struct PositiveFinding: Identifiable, Codable {
    let id: UUID
    let title: String
    let detail: String
    init(id: UUID = UUID(), title: String, detail: String) {
        self.id = id; self.title = title; self.detail = detail
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id     = (try? c.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        title  = (try? c.decode(String.self, forKey: .title))     ?? ""
        detail = (try? c.decode(String.self, forKey: .detail))    ?? ""
    }
}

struct DocumentAnalysis: Codable {
    let title: String
    let summary: String
    let lineItems: [LineItem]
    let positiveFindings: [PositiveFinding]
    let flaggedIssues: [FlaggedIssue]
    let actionItems: [ActionItem]
    let totalBilled: Double?
    let patientOwes: Double?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title           = (try? c.decodeIfPresent(String.self, forKey: .title))                     ?? ""
        summary         = try c.decode(String.self, forKey: .summary)
        lineItems       = (try? c.decodeIfPresent([LineItem].self,        forKey: .lineItems))        ?? []
        positiveFindings = (try? c.decodeIfPresent([PositiveFinding].self, forKey: .positiveFindings)) ?? []
        flaggedIssues   = (try? c.decodeIfPresent([FlaggedIssue].self,    forKey: .flaggedIssues))   ?? []
        actionItems     = (try? c.decodeIfPresent([ActionItem].self,      forKey: .actionItems))     ?? []
        func decodeAmount(_ key: CodingKeys) -> Double? {
            if let d = try? c.decodeIfPresent(Double.self, forKey: key) { return d }
            if let s = try? c.decodeIfPresent(String.self, forKey: key) {
                return Double(s.filter { $0.isNumber || $0 == "." })
            }
            return nil
        }
        totalBilled = decodeAmount(.totalBilled)
        patientOwes = decodeAmount(.patientOwes)
    }
}

// MARK: - Health Document

struct HealthDocument: Identifiable, Codable {
    let id: UUID
    var type: DocumentType
    let dateScanned: Date
    var imageData: Data?
    var analysis: DocumentAnalysis?
    var title: String
    var profileId: UUID?

    init(type: DocumentType = .other, imageData: Data? = nil) {
        self.id = UUID()
        self.type = type
        self.dateScanned = Date()
        self.imageData = imageData
        self.profileId = nil
        let month = Date().formatted(.dateTime.month(.abbreviated).year())
        self.title = "\(type.rawValue) · \(month)"
    }

    // Handles missing profileId from documents saved before profiles were introduced
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = try c.decode(UUID.self,         forKey: .id)
        type      = try c.decode(DocumentType.self, forKey: .type)
        dateScanned = try c.decode(Date.self,       forKey: .dateScanned)
        imageData = try? c.decodeIfPresent(Data.self,             forKey: .imageData)
        analysis  = try? c.decodeIfPresent(DocumentAnalysis.self, forKey: .analysis)
        title     = (try? c.decode(String.self, forKey: .title)) ?? ""
        profileId = try? c.decodeIfPresent(UUID.self, forKey: .profileId)
    }
}

// MARK: - Insurance Profile

struct InsuranceProfile: Codable {
    var insurerName: String
    var planName: String
    var memberId: String
    var deductibleAnnual: Double
    var deductibleMet: Double
    var outOfPocketMax: Double
    var outOfPocketMet: Double

    var deductibleProgress: Double {
        guard deductibleAnnual > 0 else { return 0 }
        return min(deductibleMet / deductibleAnnual, 1.0)
    }

    var outOfPocketProgress: Double {
        guard outOfPocketMax > 0 else { return 0 }
        return min(outOfPocketMet / outOfPocketMax, 1.0)
    }

    var deductibleRemaining: Double { max(0, deductibleAnnual - deductibleMet) }
}

// MARK: - Family Profile

struct Profile: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var relationship: Relationship

    enum Relationship: String, Codable, CaseIterable {
        case spouse  = "Spouse"
        case child   = "Child"
        case parent  = "Parent"
        case other   = "Other"

        var systemImage: String {
            switch self {
            case .spouse: return "heart.fill"
            case .child:  return "figure.and.child.holdinghands"
            case .parent: return "figure.2"
            case .other:  return "person.fill"
            }
        }

        var color: Color {
            switch self {
            case .spouse: return Color(hex: "F472B6")
            case .child:  return .mint
            case .parent: return Color(hex: "818CF8")
            case .other:  return .claroSubtle
            }
        }
    }
}
