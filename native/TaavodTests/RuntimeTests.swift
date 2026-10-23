import Foundation
import AppKit
import Testing
@testable import Taavod

@MainActor
private final class RuntimeTestHost {
    private let window: NSWindow

    init(runner: ExerciseRunner) {
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
        window = NSWindow(contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.alphaValue = 0.01
        window.contentView = host
        window.orderFrontRegardless()
        runner.attachRuntime(to: host)
    }

    func close() { window.close() }
}

@MainActor
private func testRunner() -> (ExerciseRunner, RuntimeTestHost) {
    let nativeFolder = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let runner = ExerciseRunner(runtimeRoot: nativeFolder.appendingPathComponent(".runtime-cache", isDirectory: true))
    return (runner, RuntimeTestHost(runner: runner))
}

private func sqlExercise(solution: String) -> Exercise {
    Exercise(id: "runtime-sql", skillId: "sql", title: "SQL runtime check", prompt: "Query the fixture.", kind: "sql", difficulty: "Foundation", minutes: 5, starter: nil, solution: solution, explanation: "", hints: [], rubric: [], options: nil, correctOption: nil, source: nil)
}

private func pythonExercise(solution: String) -> Exercise {
    Exercise(id: "runtime-python", skillId: "python", title: "Python runtime check", prompt: "Assign your result.", kind: "python", difficulty: "Foundation", minutes: 5, starter: nil, solution: solution, explanation: "", hints: [], rubric: [], options: nil, correctOption: nil, source: nil)
}

@Test @MainActor func sqlChecksAlternateAnswersRejectErrorsAndIsolatesExploration() async throws {
    let (runner, runtimeHost) = testRunner()
    let reference = """
SELECT c.category_id, c.name, COUNT(fc.film_id) AS film_count
FROM category AS c
LEFT JOIN film_category AS fc ON fc.category_id = c.category_id
GROUP BY c.category_id, c.name
ORDER BY c.category_id;
"""
    let exercise = sqlExercise(solution: reference)

    let alternate = """
SELECT category_id, name, count(film_id)
FROM category LEFT JOIN film_category USING (category_id)
GROUP BY category_id, name;
"""
    let passed = try #require(await runner.run(exercise: exercise, code: alternate))
    #expect(passed.passed == true)
    #expect(passed.checks == 2)

    let wrong = try #require(await runner.run(exercise: exercise, code: "SELECT category_id, COUNT(*) FROM film_category GROUP BY category_id;"))
    #expect(wrong.passed == false)
    #expect(wrong.checks == 2)

    let invalid = try #require(await runner.run(exercise: exercise, code: "SELEC category_id FROM category;"))
    #expect(invalid.passed == nil)
    #expect(invalid.error?.isEmpty == false)

    let exploration = try #require(await runner.explore(code: "SELECT COUNT(*) AS actor_count FROM actor;"))
    #expect(exploration.error == nil, "Pagila exploration error: \(exploration.feedback)")
    #expect(exploration.checks == 0)
    #expect(exploration.results?.first?.rows.first?["actor_count"]?.number == 200)

    let afterExplore = try #require(await runner.run(exercise: exercise, code: alternate))
    #expect(afterExplore.error == nil, "Post-exploration check error: \(afterExplore.feedback)")
    #expect(afterExplore.passed == true)
    #expect(afterExplore.checks == 2)

    runner.suspend()
    runtimeHost.close()
}

@Test @MainActor func sqlCancellationReturnsWithoutAResult() async throws {
    let (runner, runtimeHost) = testRunner()
    let warmup = sqlExercise(solution: "SELECT 1 AS value;")
    _ = try #require(await runner.run(exercise: warmup, code: "SELECT 1 AS value;"))

    let slow = sqlExercise(solution: "SELECT 1 AS value;")
    let recursive = "WITH RECURSIVE tally(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM tally WHERE n < 100000000) SELECT COUNT(*) FROM tally;"
    let task = Task { await runner.run(exercise: slow, code: recursive) }
    try await Task.sleep(for: .milliseconds(250))
    runner.cancel()
    let outcome = await task.value
    #expect(outcome == nil)
    #expect(runner.isRunning == false)
    runner.suspend()
    runtimeHost.close()
}

@Test @MainActor func pythonChecksTwoFixturesReportsMismatchAndReturnsPlot() async throws {
    let (runner, runtimeHost) = testRunner()
    let exercise = pythonExercise(solution: "result = df['revenue'].sum()")
    let plotting = """
import matplotlib.pyplot as plt
result = df['revenue'].sum()
df.groupby('region')['revenue'].sum().plot(kind='bar')
"""
    let correct = try #require(await runner.run(exercise: exercise, code: plotting))
    #expect(correct.error == nil, "Python runtime error: \(correct.feedback)")
    #expect(correct.passed == true)
    #expect(correct.checks == 2)
    #expect(correct.plot?.hasPrefix("data:image/png;base64,") == true)

    let incorrect = try #require(await runner.run(exercise: exercise, code: "result = df['revenue'].mean()"))
    #expect(incorrect.error == nil, "Python mismatch runtime error: \(incorrect.feedback)")
    #expect(incorrect.passed == false)
    #expect(incorrect.checks == 2)
    runner.suspend()
    runtimeHost.close()
}
