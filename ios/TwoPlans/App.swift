// App.swift
// 应用入口：@main，TabView 两个 Tab

import SwiftUI

@main
struct TwoPlansApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                PlanView(plan: studyPlan)
                    .tabItem {
                        Label("AI 学习", systemImage: "book.fill")
                    }

                PlanView(plan: singPlan)
                    .tabItem {
                        Label("唱歌", systemImage: "music.note")
                    }
            }
        }
    }
}
