// DateEngine.swift
// 起算日 2026-09-25，推算第 N 天 / 第几周 / 第几月 / 当前模块
// 注意：一律使用 Calendar.startOfDay，避免用 timeIntervalSince1970/86400 直接除（夏令时/时区会错一天）

import Foundation

struct DateEngine {
    /// 计划起算日：2026-09-25，作为「第 1 天」
    static let startDate: Date = {
        var comps = DateComponents(year: 2026, month: 9, day: 25)
        let cal = Calendar.current
        return cal.startOfDay(for: cal.date(from: comps)!)
    }()

    /// 公式周上限（12 个月 × 4 周）
    static let maxWeeks = 48

    let totalDays: Int
    let monthDurations: [Int]
    let blocks: [PlanBlock]

    /// 第 N 天：从起算日到今天经过的天数 + 1，最小 1，最大按计划上限截断
    func dayIndex(for date: Date = Date()) -> Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: date)
        let elapsed = cal.dateComponents([.day], from: DateEngine.startDate, to: today).day ?? 0
        return min(max(elapsed + 1, 1), totalDays)
    }

    /// 第几周：ceil(day/7)，上限 48
    func weekIndex(for day: Int) -> Int {
        return min(Int(ceil(Double(day) / 7.0)), DateEngine.maxWeeks)
    }

    /// 第几月：ceil(week/4)，上限 12
    func monthIndex(for day: Int) -> Int {
        let w = weekIndex(for: day)
        return min(Int(ceil(Double(w) / 4.0)), 12)
    }

    /// 当前模块：找到覆盖当前公式周的块
    func currentBlock(for day: Int) -> PlanBlock {
        let w = weekIndex(for: day)
        return blocks.first(where: { $0.weekRange.contains(w) })
            ?? blocks.last
            ?? PlanBlock(month: 1, weekRange: 1...1, label: "", title: "", items: [])
    }

    /// 某计划月份的第一天（在计划内的序号）
    func monthStartDay(_ month: Int) -> Int {
        var d = 1
        for m in 1..<month {
            d += monthDurations[m - 1]
        }
        return d
    }

    /// 某计划月份的完成比例（0~1），过去月份为 1，当前月份按比例，未来为 0
    func monthProgress(_ month: Int, day: Int) -> Double {
        let start = monthStartDay(month)
        let dur = monthDurations[month - 1]
        if day < start { return 0 }
        let done = day - start + 1
        return min(1.0, Double(done) / Double(dur))
    }

    /// 连续打卡天数：从今天（或昨天）往前数连续已打卡的天数
    func streak(checkins: [String]) -> Int {
        let set = Set(checkins)
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var count = 0
        var cursor = today
        // 今天没打卡则从昨天起算，避免「今天还没打却断签」的错觉
        if !set.contains(DateEngine.dayString(today)) {
            guard let prev = cal.date(byAdding: .day, value: -1, to: today) else { return 0 }
            cursor = prev
        }
        while set.contains(DateEngine.dayString(cursor)) {
            count += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return count
    }

    /// 日期 -> "yyyy-MM-dd"，打卡存储用该字符串
    static func dayString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f.string(from: date)
    }
}
