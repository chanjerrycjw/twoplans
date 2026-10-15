// ProgressStore.swift
// 持久化模型与辅助：进度以 Codable JSON 字符串存入 UserDefaults
// 实际读写由 PlanView 中的 @AppStorage 完成，这里只负责编解码与 key 生成

import Foundation

/// 单个计划的持久化进度
struct PlanProgress: Codable {
    /// 今日任务勾选状态：key 形如 "study_t_3_0"
    var taskChecks: [String: Bool]
    /// 打卡日期字符串数组，格式 "yyyy-MM-dd"
    var checkins: [String]
    /// 月度检查点勾选状态：key 形如 "sing_c_1_0"
    var checkpoints: [String: Bool]

    init() {
        taskChecks = [:]
        checkins = []
        checkpoints = [:]
    }
}

/// 持久化相关的纯函数辅助（无状态，可安全在任意视图调用）
enum ProgressStore {
    /// UserDefaults 中对应某计划的 JSON 存储 key
    static func storageKey(planID: String) -> String {
        "twoplans_\(planID)_data"
    }

    /// 从 @AppStorage 的 JSON 字符串解码；为空或损坏时返回空进度
    static func decode(_ raw: String) -> PlanProgress {
        guard let data = raw.data(using: .utf8),
              let p = try? JSONDecoder().decode(PlanProgress.self, from: data) else {
            return PlanProgress()
        }
        return p
    }

    /// 编码为 JSON 字符串；失败返回空对象字符串
    static func encode(_ p: PlanProgress) -> String {
        if let d = try? JSONEncoder().encode(p),
           let s = String(data: d, encoding: .utf8) {
            return s
        }
        return "{}"
    }

    /// 今日任务勾选 key
    static func taskKey(planID: String, week: Int, index: Int) -> String {
        "\(planID)_t_\(week)_\(index)"
    }

    /// 月度检查点勾选 key
    static func checkpointKey(planID: String, month: Int, index: Int) -> String {
        "\(planID)_c_\(month)_\(index)"
    }
}
