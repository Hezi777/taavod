import Foundation

enum LearningProgress {
    static func date(_ text: String) -> Date? {
        (try? Date(text, strategy: .iso8601)) ?? (try? Date(text, strategy: .iso8601.year().month().day().time(includingFractionalSeconds: true)))
    }
    static func dueReviews(attempts: [WorkspaceRecord], tracks: [SkillTrack], now: Date = .now) -> [Exercise] {
        let groups = Dictionary(grouping: attempts, by: { $0.payload.text("exerciseId") })
        let ids = Set(groups.compactMap { key, group -> String? in
            let sorted = group.sorted { $0.payload.text("createdAt") < $1.payload.text("createdAt") }
            guard let last = sorted.last, last.payload.flag("passed"), !last.payload.flag("selfReported"),
                  let lastDate = date(last.payload.text("createdAt")) else { return nil }
            let independent = sorted.filter { $0.payload.flag("passed") && !$0.payload.flag("selfReported") && $0.payload.number("hintsUsed") == 0 }.count
            let interval = [1, 3, 7, 14, 30][min(max(independent - 1, 0), 4)]
            return lastDate.addingTimeInterval(Double(interval) * 86400) <= now ? key : nil
        })
        return tracks.flatMap(\.exercises).filter { ids.contains($0.id) }
    }
    static func week(_ now: Date = .now) -> String {
        var calendar = Calendar(identifier: .iso8601); calendar.timeZone = TimeZone(identifier: "Asia/Jerusalem")!
        let monday = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let formatter = DateFormatter(); formatter.calendar = calendar; formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: monday)
    }
    static func suggestPlan(app: AppModel) {
        let week = week(), attempts = app.store.list("attempts")
        var candidates: [(String, String, String?, Int)] = dueReviews(attempts: attempts, tracks: app.tracks).prefix(2).map { ("Recall: " + $0.title, "review", $0.id, min($0.minutes, 25)) }
        let ranked = app.tracks.sorted { a, b in
            @MainActor func score(_ track: SkillTrack) -> Double {
                let tries = attempts.filter { $0.payload.text("skillId") == track.id }
                guard !tries.isEmpty else { return app.store.profile["skillConfidence"]?.object[track.id]?.number ?? 0 }
                return Double(tries.filter { $0.payload.flag("passed") && !$0.payload.flag("selfReported") }.count) / Double(tries.count) * 5
            }
            return score(a) == score(b) ? a.id < b.id : score(a) < score(b)
        }
        for track in ranked.prefix(2) {
            if let exercise = track.exercises.first(where: { exercise in !attempts.contains { $0.payload.text("exerciseId") == exercise.id && $0.payload.flag("passed") && !$0.payload.flag("selfReported") } }) ?? track.exercises.first {
                candidates.append((exercise.title, "practice", exercise.id, 45))
            }
        }
        candidates += [("Strengthen one project story", "project", nil, 45), ("Explain one BI decision aloud", "interview", nil, 30)]
        var remaining = max(15, Int(app.store.profile.number("weeklyHours") * 60))
        for (index, item) in candidates.enumerated() where remaining >= 15 {
            let minutes = min(item.3, remaining), id = "plan-\(week)-\(index)"
            remaining -= minutes
            guard app.store.record("tasks", id: id) == nil else { continue }
            var payload: [String: JSONValue] = ["title": .string(item.0), "type": .string(item.1), "minutes": .number(Double(minutes)), "done": .bool(false), "weekOf": .string(week)]
            if let exerciseID = item.2 { payload["exerciseId"] = .string(exerciseID); payload["href"] = .string("/practice?exercise=" + exerciseID) }
            else { payload["href"] = .string(item.1 == "project" ? "/portfolio" : "/interviews") }
            app.store.update("tasks", id: id, patch: payload)
        }
    }
}
