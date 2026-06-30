import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Constants

private let kAppGroup = "group.com.gncaitech.ansim_signal"
private let kApiUrl   = "http://ansim.gncaitech.com/api/checkin"

// MARK: - Check-in Intent (iOS 17+, interactive widget button)

struct CheckinIntent: AppIntent {
    static var title: LocalizedStringResource = "안부 신호 전송"

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: kAppGroup)
        guard let token = defaults?.string(forKey: "ansim_server_token"), !token.isEmpty else {
            return .result()
        }

        // Optimistic update — reflect immediately before API response
        let now = Date()
        WidgetData.save(to: defaults, date: now)
        WidgetCenter.shared.reloadAllTimelines()

        // Confirm with server time
        if let serverDate = await callCheckinApi(token: token) {
            WidgetData.save(to: defaults, date: serverDate)
            WidgetCenter.shared.reloadAllTimelines()
        }

        return .result()
    }

    private func callCheckinApi(token: String) async -> Date? {
        guard let url = URL(string: kApiUrl) else { return nil }
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let checkedAt = json["checked_at"] as? String else { return nil }
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = fmt.date(from: checkedAt) { return d }
            fmt.formatOptions = [.withInternetDateTime]
            return fmt.date(from: checkedAt)
        } catch {
            return nil
        }
    }
}

// MARK: - Widget Data Helpers

enum WidgetData {
    static func save(to defaults: UserDefaults?, date: Date) {
        let intervalHours = defaults?.integer(forKey: "ansim_interval_hours") ?? 24
        let ms = Int64(date.timeIntervalSince1970 * 1000)
        let deadline = date.addingTimeInterval(Double(intervalHours) * 3600)
        let remaining = deadline.timeIntervalSince(Date())

        let status: String
        if remaining < 0             { status = "overdue" }
        else if remaining < Double(intervalHours) * 3600 / 12 { status = "warning" }
        else                         { status = "safe" }

        let timeRemainingStr: String
        if remaining < 0 {
            let h = Int(-remaining / 3600)
            timeRemainingStr = h > 0 ? "\(h)시간 초과" : "초과됨"
        } else if remaining >= 3600 {
            timeRemainingStr = "\(Int(remaining / 3600))시간 남음"
        } else {
            timeRemainingStr = "\(Int(remaining / 60))분 남음"
        }

        let cal = Calendar.current
        let h = cal.component(.hour, from: date)
        let m = cal.component(.minute, from: date)
        let period   = h < 12 ? "오전" : "오후"
        let displayH = h == 0 ? 12 : h > 12 ? h - 12 : h
        let lastCheckinStr = "\(period) \(displayH):\(String(format: "%02d", m))"

        defaults?.set(status, forKey: "ansim_status")
        defaults?.set(lastCheckinStr, forKey: "ansim_last_checkin")
        defaults?.set(timeRemainingStr, forKey: "ansim_time_remaining")
        defaults?.set(ms, forKey: "ansim_last_checkin_ms")
    }

    static func load() -> AnsimEntry {
        let d = UserDefaults(suiteName: kAppGroup)
        return AnsimEntry(
            date:          Date(),
            status:        d?.string(forKey: "ansim_status")        ?? "unknown",
            lastCheckin:   d?.string(forKey: "ansim_last_checkin")   ?? "--",
            timeRemaining: d?.string(forKey: "ansim_time_remaining") ?? "--"
        )
    }
}

// MARK: - Timeline Entry & Provider

struct AnsimEntry: TimelineEntry {
    let date: Date
    let status: String
    let lastCheckin: String
    let timeRemaining: String
}

struct AnsimProvider: TimelineProvider {
    func placeholder(in context: Context) -> AnsimEntry {
        AnsimEntry(date: Date(), status: "safe", lastCheckin: "오전 9:32", timeRemaining: "3시간 남음")
    }
    func getSnapshot(in context: Context, completion: @escaping (AnsimEntry) -> Void) {
        completion(WidgetData.load())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<AnsimEntry>) -> Void) {
        let defaults = UserDefaults(suiteName: kAppGroup)
        let intervalHours = defaults?.integer(forKey: "ansim_interval_hours") ?? 24
        let lastCheckinMs = defaults?.object(forKey: "ansim_last_checkin_ms") as? Int64 ?? 0

        var entries: [AnsimEntry] = []
        let now = Date()

        // 15분 간격으로 4개 항목 생성 (현재 ~ 1시간)
        for i in 0..<4 {
            let entryDate = Calendar.current.date(byAdding: .minute, value: i * 15, to: now) ?? now
            let lastCheckIn = lastCheckinMs > 0
                ? Date(timeIntervalSince1970: Double(lastCheckinMs) / 1000)
                : nil

            let remaining: TimeInterval
            if let lc = lastCheckIn {
                let deadline = lc.addingTimeInterval(Double(intervalHours) * 3600)
                remaining = deadline.timeIntervalSince(entryDate)
            } else {
                remaining = 0
            }

            let status: String
            if lastCheckIn == nil       { status = "unknown" }
            else if remaining < 0       { status = "overdue" }
            else if remaining < Double(intervalHours) * 3600 / 12 { status = "warning" }
            else                        { status = "safe" }

            let timeRemainingStr: String
            if lastCheckIn == nil {
                timeRemainingStr = "--"
            } else if remaining < 0 {
                let h = Int(-remaining / 3600)
                timeRemainingStr = h > 0 ? "\(h)시간 초과" : "초과됨"
            } else if remaining >= 3600 {
                timeRemainingStr = "\(Int(remaining / 3600))시간 남음"
            } else {
                timeRemainingStr = "\(Int(remaining / 60))분 남음"
            }

            let lastCheckinStr: String
            if let lc = lastCheckIn {
                let cal = Calendar.current
                let h = cal.component(.hour, from: lc)
                let m = cal.component(.minute, from: lc)
                let period   = h < 12 ? "오전" : "오후"
                let displayH = h == 0 ? 12 : h > 12 ? h - 12 : h
                lastCheckinStr = "\(period) \(displayH):\(String(format: "%02d", m))"
            } else {
                lastCheckinStr = "--"
            }

            entries.append(AnsimEntry(
                date: entryDate,
                status: status,
                lastCheckin: lastCheckinStr,
                timeRemaining: timeRemainingStr
            ))
        }

        // 15분 후 새 타임라인 요청
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: now) ?? now
        completion(Timeline(entries: entries, policy: .after(nextUpdate)))
    }
}

// MARK: - Color / Label Helpers

extension Color {
    static let navyStart = Color(red: 37/255,  green: 99/255,  blue: 235/255)
    static let navyEnd   = Color(red: 30/255,  green: 58/255,  blue: 138/255)
    static let widgetBg  = Color(red: 239/255, green: 244/255, blue: 255/255)

    static func statusDot(_ s: String) -> Color {
        switch s {
        case "safe":    return Color(red: 22/255,  green: 163/255, blue: 74/255)
        case "warning": return Color(red: 245/255, green: 158/255, blue: 11/255)
        case "overdue": return Color(red: 220/255, green: 38/255,  blue: 38/255)
        default:        return Color(red: 148/255, green: 163/255, blue: 184/255)
        }
    }

    static func statusLabel(_ s: String) -> String {
        switch s {
        case "safe":    return "안전"
        case "warning": return "주의"
        case "overdue": return "위급"
        default:        return "미확인"
        }
    }
}

// MARK: - Shield Icon

struct ShieldIcon: View {
    var size: CGFloat = 36
    var body: some View {
        ZStack {
            Path { p in
                let s = size
                p.move(to: CGPoint(x: s*0.50, y: s*0.10))
                p.addLine(to: CGPoint(x: s*0.85, y: s*0.22))
                p.addCurve(to: CGPoint(x: s*0.50, y: s*0.88),
                           control1: CGPoint(x: s*0.85, y: s*0.62),
                           control2: CGPoint(x: s*0.85, y: s*0.62))
                p.addCurve(to: CGPoint(x: s*0.15, y: s*0.22),
                           control1: CGPoint(x: s*0.15, y: s*0.62),
                           control2: CGPoint(x: s*0.15, y: s*0.62))
                p.closeSubpath()
            }
            .fill(Color.white.opacity(0.9))
            .frame(width: size, height: size)

            Path { p in
                let s = size
                p.move(to: CGPoint(x: s*0.33, y: s*0.50))
                p.addLine(to: CGPoint(x: s*0.45, y: s*0.63))
                p.addLine(to: CGPoint(x: s*0.68, y: s*0.37))
            }
            .stroke(Color.navyStart,
                    style: StrokeStyle(lineWidth: size*0.07, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Check-in Button Visuals

struct CheckinButtonContent: View {
    var size: CGFloat    = 70
    var fontSize: CGFloat = 9
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [.navyStart, .navyEnd],
                                     startPoint: UnitPoint(x: 0.29, y: 0.29),
                                     endPoint:   UnitPoint(x: 0.71, y: 0.71)))
                .frame(width: size, height: size)
                .shadow(color: .navyStart.opacity(0.4), radius: 8, x: 0, y: 4)
            VStack(spacing: 3) {
                ShieldIcon(size: size * 0.44)
                Text("나 괜찮아요")
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Status Info (left panel of medium widget)

struct StatusInfoView: View {
    let entry: AnsimEntry
    var titleSize:  CGFloat = 11
    var statusSize: CGFloat = 14
    var subSize:    CGFloat = 11

    var body: some View {
        VStack(spacing: 4) {
            Text("안심시그널")
                .font(.system(size: titleSize, weight: .semibold))
                .foregroundColor(.navyStart)
            HStack(spacing: 5) {
                Circle()
                    .fill(Color.statusDot(entry.status))
                    .frame(width: 9, height: 9)
                Text(Color.statusLabel(entry.status))
                    .font(.system(size: statusSize, weight: .bold))
                    .foregroundColor(Color(red: 55/255, green: 65/255, blue: 81/255))
            }
            .padding(.top, 2)
            Text("마지막: \(entry.lastCheckin)")
                .font(.system(size: subSize))
                .foregroundColor(Color(red: 107/255, green: 114/255, blue: 128/255))
            Text(entry.timeRemaining)
                .font(.system(size: subSize))
                .foregroundColor(Color(red: 107/255, green: 114/255, blue: 128/255))
        }
    }
}

// MARK: - Small Widget (2×2)

struct AnsimSmallView: View {
    let entry: AnsimEntry
    var body: some View {
        ZStack {
            Color.widgetBg
            VStack(spacing: 4) {
                Text("안심시그널")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.navyStart)

                Button(intent: CheckinIntent()) {
                    CheckinButtonContent(size: 68, fontSize: 8)
                }
                .buttonStyle(.plain)

                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.statusDot(entry.status))
                        .frame(width: 7, height: 7)
                    Text(entry.timeRemaining)
                        .font(.system(size: 9))
                        .foregroundColor(Color(red: 55/255, green: 65/255, blue: 81/255))
                }
            }
            .padding(8)
        }
        .widgetURL(URL(string: "homewidget://open"))
    }
}

// MARK: - Medium Widget (4×2)

struct AnsimMediumView: View {
    let entry: AnsimEntry
    var body: some View {
        ZStack {
            Color.widgetBg
            HStack(spacing: 0) {
                StatusInfoView(entry: entry)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Button(intent: CheckinIntent()) {
                    CheckinButtonContent(size: 90, fontSize: 10)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .widgetURL(URL(string: "homewidget://open"))
    }
}

// MARK: - Entry View & Widget

struct AnsimWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: AnsimEntry
    var body: some View {
        switch family {
        case .systemSmall:  AnsimSmallView(entry: entry)
        case .systemMedium: AnsimMediumView(entry: entry)
        default:            AnsimSmallView(entry: entry)
        }
    }
}

struct AnsimWidget: Widget {
    let kind: String = "AnsimWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AnsimProvider()) { entry in
            AnsimWidgetEntryView(entry: entry)
                .containerBackground(Color.widgetBg, for: .widget)
        }
        .configurationDisplayName("안심시그널")
        .description("안부 신호 상태를 홈 화면에서 확인하세요.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
