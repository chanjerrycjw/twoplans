// PlanView.swift
// 通用计划视图：今日卡片 + 任务勾选 + 12 个月网格 + 打卡日历
// 仅使用 iOS 15 就有的 API：TabView/NavigationView/List/LazyVGrid/ProgressView/@AppStorage/DisclosureGroup/.sheet

import SwiftUI

struct PlanView: View {
    let plan: PlanData

    @State private var showResetAlert = false
    // 每个计划一份 JSON 进度，key 用 plan.id 区分
    @AppStorage private var raw: String

    private let engine: DateEngine
    private let weekdayNames = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]

    init(plan: PlanData) {
        self.plan = plan
        _raw = AppStorage(wrappedValue: "", ProgressStore.storageKey(planID: plan.id))
        engine = DateEngine(totalDays: plan.totalDays,
                            monthDurations: plan.monthDurations,
                            blocks: plan.blocks)
    }

    // MARK: 持久化读写
    private var progress: PlanProgress {
        ProgressStore.decode(raw)
    }

    private func save(_ p: PlanProgress) {
        raw = ProgressStore.encode(p)
    }

    // MARK: 日期推算
    private var dayIndex: Int { engine.dayIndex() }
    private var weekIndex: Int { engine.weekIndex(for: dayIndex) }
    private var monthIndex: Int { engine.monthIndex(for: dayIndex) }
    private var currentBlock: PlanBlock { engine.currentBlock(for: dayIndex) }
    private var todayString: String { DateEngine.dayString(Date()) }
    private var weekdayName: String {
        let w = Calendar.current.component(.weekday, from: Date()) // 1=周日
        return weekdayNames[(w - 1 + 7) % 7]
    }

    // MARK: 任务勾选
    private func taskKey(_ index: Int) -> String {
        ProgressStore.taskKey(planID: plan.id, week: currentBlock.weekRange.lowerBound, index: index)
    }
    private func isTaskDone(_ index: Int) -> Bool {
        progress.taskChecks[taskKey(index)] ?? false
    }
    private func toggleTask(_ index: Int) {
        var p = progress
        let k = taskKey(index)
        p.taskChecks[k] = !(p.taskChecks[k] ?? false)
        save(p)
    }

    // MARK: 打卡
    private func isCheckedInToday() -> Bool {
        progress.checkins.contains(todayString)
    }
    private func toggleCheckIn() {
        var p = progress
        if let idx = p.checkins.firstIndex(of: todayString) {
            p.checkins.remove(at: idx)
        } else {
            p.checkins.append(todayString)
        }
        save(p)
    }
    private var streak: Int { engine.streak(checkins: progress.checkins) }

    // 最近 8 周（56 天）的方格日历
    private var calendarDays: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var arr: [Date] = []
        for i in (0..<56).reversed() {
            if let d = cal.date(byAdding: .day, value: -i, to: today) {
                arr.append(d)
            }
        }
        return arr
    }

    // MARK: 检查点（唱歌）
    private func cpKey(_ month: Int, _ index: Int) -> String {
        ProgressStore.checkpointKey(planID: plan.id, month: month, index: index)
    }
    private func isCheckpointDone(_ month: Int, _ index: Int) -> Bool {
        progress.checkpoints[cpKey(month, index)] ?? false
    }
    private func toggleCheckpoint(_ month: Int, _ index: Int) {
        var p = progress
        let k = cpKey(month, index)
        p.checkpoints[k] = !(p.checkpoints[k] ?? false)
        save(p)
    }

    // MARK: 重置
    private func resetProgress() {
        save(PlanProgress())
    }

    // MARK: 视图
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerCard
                    todayTasksSection
                    if plan.id == "sing" {
                        dailyMenuSection
                    }
                    monthGridSection
                    checkInSection
                    if plan.id == "sing" {
                        checkpointsSection
                    }
                    resetButton
                }
                .padding()
            }
            .navigationTitle(plan.name)
        }
        .alert(Text("重置进度"), isPresented: $showResetAlert) {
            Button("取消", role: .cancel) { }
            Button("确定重置", role: .destructive) { resetProgress() }
        } message: {
            Text("将清空本计划所有任务勾选、打卡记录与月度检查点，且无法恢复。确定吗？")
        }
    }

    // 顶部卡片：第 N 天 / 第 X 周 / 第 Y 月 + 当前模块 + 总进度
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("第 \(dayIndex) 天")
                    .font(.title2).bold()
                Spacer()
                Text("第 \(weekIndex) 周 · 第 \(monthIndex) 月")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Text("今天：\(todayString)")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("当前模块：\(currentBlock.label) \(currentBlock.title)")
                .font(.headline)
            ProgressView(value: Double(dayIndex), total: Double(plan.totalDays))
                .accentColor(.blue)
            Text("总进度 \(Int(Double(dayIndex) / Double(plan.totalDays) * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // 今日任务：当前模块的要点，可勾选，持久化
    private var todayTasksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("今日任务（\(currentBlock.label)）")
                .font(.headline)
            if currentBlock.items.isEmpty {
                Text("暂无任务")
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(currentBlock.items.enumerated()), id: \.offset) { index, item in
                    Button {
                        toggleTask(index)
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: isTaskDone(index) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(isTaskDone(index) ? .green : .gray)
                                .padding(.top, 2)
                            Text(item)
                                .strikethrough(isTaskDone(index))
                                .foregroundColor(isTaskDone(index) ? .secondary : .primary)
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // 唱歌：按今天星期几展示每日练习菜单
    private var dailyMenuSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("每日练习菜单 · \(weekdayName)")
                .font(.headline)
            if let items = plan.dailyMenu[weekdayName], !items.isEmpty {
                ForEach(items, id: \.self) { item in
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text(item)
                    }
                }
            } else {
                Text("今日为休息日，轻松练习即可")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // 12 个月网格：当前月高亮，已完成比例小字
    private var monthGridSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("12 个月进度")
                .font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(1...12, id: \.self) { m in
                    let ratio = engine.monthProgress(m, day: dayIndex)
                    let isCurrent = (m == monthIndex)
                    VStack(spacing: 4) {
                        Text("\(m) 月")
                            .font(.subheadline)
                            .bold()
                        Text("\(Int(ratio * 100))%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(isCurrent ? Color.blue.opacity(0.25) : Color(.tertiarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isCurrent ? Color.blue : Color.clear, lineWidth: 1.5)
                    )
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // 打卡：按钮 + 连续天数 + 8 周方格日历
    private var checkInSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("每日打卡")
                    .font(.headline)
                Spacer()
                Text("已连续 \(streak) 天")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Button {
                toggleCheckIn()
            } label: {
                Text(isCheckedInToday() ? "取消今日打卡" : "今日打卡")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(isCheckedInToday() ? Color.gray.opacity(0.3) : Color.blue)
                    .foregroundColor(isCheckedInToday() ? .primary : .white)
                    .cornerRadius(10)
            }
            Text("最近 8 周")
                .font(.caption)
                .foregroundColor(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(calendarDays, id: \.self) { d in
                    let s = DateEngine.dayString(d)
                    let done = progress.checkins.contains(s)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(done ? Color.green : Color(.tertiarySystemBackground))
                        .frame(height: 18)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // 唱歌：月度检查点清单
    private var checkpointsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("月度检查点")
                .font(.headline)
            ForEach(1...12, id: \.self) { m in
                if let items = plan.monthlyCheckpoints[m], !items.isEmpty {
                    DisclosureGroup {
                        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                            Button {
                                toggleCheckpoint(m, index)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: isCheckpointDone(m, index) ? "checkmark.square.fill" : "square")
                                        .foregroundColor(isCheckpointDone(m, index) ? .green : .gray)
                                    Text(item)
                                        .strikethrough(isCheckpointDone(m, index))
                                        .foregroundColor(isCheckpointDone(m, index) ? .secondary : .primary)
                                    Spacer()
                                }
                            }
                        }
                    } label: {
                        Text("第 \(m) 个月")
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var resetButton: some View {
        Button {
            showResetAlert = true
        } label: {
            Text("重置本计划进度")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundColor(.red)
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}
