import SwiftUI
import AppKit

private struct PagilaSchema: Decodable {
    struct Column: Decodable, Identifiable {
        var table_name: String
        var column_name: String
        var data_type: String
        var is_nullable: String
        var ordinal_position: Int
        var id: String { "\(table_name).\(column_name)" }
    }
    struct Constraint: Decodable, Identifiable {
        var table_name: String
        var kind: String
        var definition: String
        var id: String { "\(table_name):\(definition)" }
    }
    var columns: [Column]
    var constraints: [Constraint]

    static var load: PagilaSchema? {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("Resources/pagila-schema.json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(PagilaSchema.self, from: data)
    }

    var tables: [String] { Array(Set(columns.map(\.table_name))).sorted() }
    func columns(in table: String) -> [Column] { columns.filter { $0.table_name == table }.sorted { $0.ordinal_position < $1.ordinal_position } }
    func primaryKeys(in table: String) -> Set<String> {
        Set(constraints.filter { $0.table_name == table && $0.kind == "p" }.flatMap { columnNames($0.definition, pattern: #"PRIMARY KEY\s*\(([^)]+)\)"#) })
    }
    var relations: [Relation] {
        constraints.filter { $0.kind == "f" }.compactMap { constraint in
            guard let from = columnNames(constraint.definition, pattern: #"FOREIGN KEY\s*\(([^)]+)\)"#).first,
                  let target = constraint.definition.range(of: #"REFERENCES\s+([\w.]+)\s*\(([^)]+)\)"#, options: .regularExpression) else { return nil }
            let matched = String(constraint.definition[target])
            let pieces = matched.replacingOccurrences(of: #"^REFERENCES\s+"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: ")", with: "").split(separator: "(")
            guard pieces.count == 2 else { return nil }
            return Relation(source: constraint.table_name, sourceColumn: from, target: String(pieces[0]).split(separator: ".").last.map(String.init) ?? String(pieces[0]), targetColumn: String(pieces[1]))
        }
    }
    private func columnNames(_ definition: String, pattern: String) -> [String] {
        guard let range = definition.range(of: pattern, options: .regularExpression) else { return [] }
        let segment = String(definition[range])
        guard let open = segment.firstIndex(of: "("), let close = segment.lastIndex(of: ")") else { return [] }
        return segment[segment.index(after: open)..<close].split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

private struct Relation: Identifiable {
    var source: String
    var sourceColumn: String
    var target: String
    var targetColumn: String
    var id: String { "\(source).\(sourceColumn)->\(target).\(targetColumn)" }
}

struct SchemaExplorerView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var app: AppModel
    private let schema = PagilaSchema.load
    @State private var selectedTable = "actor"
    @State private var search = ""
    @State private var showingQueries = false
    @State private var selectedSample = 0
    @State private var queryCode = SchemaExplorerView.samples[0].sql
    @State private var queryOutcome: PracticeOutcome?
    @State private var queryTask: Task<Void, Never>?
    @State private var findText = ""
    private var selectedTextBinding: Binding<String> {
        Binding(get: { app.study.selectedText }, set: { app.study.selectedText = $0 })
    }

    private struct SampleQuery {
        var title: String
        var description: String
        var sql: String
    }
    private static let samples = [
        SampleQuery(title: "Most rented films", description: "Join the film catalog to inventory copies and rental events, then aggregate at film grain.", sql: """
SELECT f.title, COUNT(*) AS rental_count
FROM film AS f
JOIN inventory AS i ON i.film_id = f.film_id
JOIN rental AS r ON r.inventory_id = i.inventory_id
GROUP BY f.film_id, f.title
ORDER BY rental_count DESC, f.title
LIMIT 5;
"""),
        SampleQuery(title: "Rentals by month", description: "Group rental events by calendar month to view activity over time.", sql: """
SELECT DATE_TRUNC('month', rental_date)::date AS month,
       COUNT(*) AS rentals
FROM rental
GROUP BY 1
ORDER BY 1
LIMIT 10;
""")
    ]

    private var activeTable: String {
        guard let schema, schema.tables.contains(selectedTable) else { return schema?.tables.first ?? "" }
        return selectedTable
    }
    private var neighborhood: [String] {
        guard let schema else { return [] }
        let related = schema.relations.filter { $0.source == activeTable || $0.target == activeTable }
            .map { $0.source == activeTable ? $0.target : $0.source }
        return Array(Set([activeTable] + related)).sorted()
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if let schema {
                HStack(spacing: 0) {
                    tableList(schema).frame(width: 190)
                    Divider()
                if showingQueries { sampleQueries }
                else {
                    VStack(spacing: 0) {
                        relationshipDiagram(schema).frame(height: 255)
                        Divider()
                        tableDetails(schema).frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                }
            } else {
                ContentUnavailableView("Schema unavailable", systemImage: "externaldrive.badge.exclamationmark", description: Text("The included Pagila schema file could not be read."))
            }
        }
        .frame(minWidth: 850, minHeight: 620)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "point.3.connected.trianglepath.dotted").font(.title3).foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("Pagila data explorer").font(.headline)
                Text("Explore tables, keys, and relationships before you query").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Picker("Explorer section", selection: $showingQueries) {
                Text("Schema").tag(false)
                Text("Sample queries").tag(true)
            }.pickerStyle(.segmented).frame(width: 210)
            Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
        }
        .padding(16).background(.regularMaterial)
    }

    private var sampleQueries: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                ForEach(Array(Self.samples.enumerated()), id: \.offset) { index, sample in
                    Button {
                        selectedSample = index
                        queryCode = sample.sql
                        queryOutcome = nil
                    } label: {
                        Text(sample.title).font(.callout.weight(.medium))
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(selectedSample == index ? Color.accentColor.opacity(0.14) : Color.clear, in: Capsule())
                    }.buttonStyle(.plain)
                }
                Spacer()
                if app.runner.isRunning { Button("Cancel") { app.runner.cancel(); queryTask?.cancel() }.buttonStyle(.bordered) }
                else { Button { runSample() } label: { Label("Run sample", systemImage: "play.fill") }.buttonStyle(.borderedProminent) }
            }
            .padding(12)
            Text(Self.samples[selectedSample].description).font(.callout).foregroundStyle(.secondary)
                .padding(.horizontal, 14).padding(.bottom, 10)
            if !app.packs.isInstalled(.sql) {
                if app.packs.installing == .sql {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preparing SQL practice · \(app.packs.sizeLabel(.sql))").font(.caption).foregroundStyle(.secondary)
                        ProgressView(value: app.packs.progress)
                        Button("Cancel download") { app.packs.cancel() }.buttonStyle(.bordered)
                    }.padding(12)
                } else {
                    HStack {
                        Text(app.packs.error ?? "SQL data downloads once and is then available offline.")
                            .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        Spacer()
                        Button(app.packs.error == nil ? "Install SQL data" : "Retry") { installSQLAndRun() }
                            .buttonStyle(.borderedProminent)
                    }.padding(12).background(Color.accentColor.opacity(0.06))
                }
            }
            NativeCodeEditor(text: $queryCode, selectedText: selectedTextBinding, findText: $findText, language: .sql)
                .frame(minHeight: 220, maxHeight: .infinity)
            if let queryOutcome {
                queryResult(queryOutcome)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDisappear { queryTask?.cancel() }
    }

    private func runSample() {
        queryTask?.cancel()
        queryTask = Task {
            let outcome = await app.runner.explore(code: queryCode)
            guard !Task.isCancelled, let outcome else { return }
            queryOutcome = outcome
            app.study.outcome = outcome
            app.study.mode = "explore"
        }
    }

    private func installSQLAndRun() {
        queryTask?.cancel()
        queryTask = Task {
            do {
                try await app.packs.install(.sql)
                guard !Task.isCancelled, app.packs.isInstalled(.sql) else { return }
                runSample()
            } catch {
                // RuntimePacks exposes the actionable setup error in its observable state.
            }
        }
    }

    private func queryResult(_ outcome: PracticeOutcome) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Sample result", systemImage: "tablecells").font(.caption.weight(.semibold))
                Spacer()
                Text(outcome.feedback).font(.caption).foregroundColor(Color(nsColor: outcome.error == nil ? .secondaryLabelColor : .systemRed)).lineLimit(2)
            }
            if let error = outcome.error, !error.isEmpty {
                Text(error).font(.system(.caption, design: .monospaced)).foregroundStyle(.red).textSelection(.enabled)
            }
            if let results = outcome.results, let result = results.first {
                ScrollView([.horizontal, .vertical]) {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 5) {
                        GridRow {
                            ForEach(Array(result.fields.enumerated()), id: \.offset) { _, field in
                                Text(field.name).font(.caption.weight(.semibold))
                            }
                        }
                        ForEach(Array(result.rows.prefix(100).enumerated()), id: \.offset) { _, row in
                            GridRow {
                                ForEach(Array(result.fields.enumerated()), id: \.offset) { _, field in
                                    Text(resultText(row[field.name])).font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                                }
                            }
                        }
                    }.padding(8)
                }.frame(maxHeight: 135).background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(12).background(Color(nsColor: .controlBackgroundColor))
    }

    private func resultText(_ value: JSONValue?) -> String {
        guard let value else { return "—" }
        switch value {
        case .string(let text): return text
        case .number(let number): return String(number)
        case .bool(let flag): return flag ? "true" : "false"
        case .null: return "null"
        case .array, .object: return "value"
        }
    }

    private func tableList(_ schema: PagilaSchema) -> some View {
        VStack(spacing: 8) {
            TextField("Find table", text: $search).textFieldStyle(.roundedBorder).padding(.horizontal, 10).padding(.top, 10)
            ScrollView {
                LazyVStack(spacing: 3) {
                    ForEach(schema.tables.filter { search.isEmpty || $0.localizedCaseInsensitiveContains(search) }, id: \.self) { table in
                        Button { selectedTable = table } label: {
                            HStack {
                                Image(systemName: "tablecells").foregroundStyle(.secondary)
                                Text(table).font(.callout.monospaced()).lineLimit(1)
                                Spacer()
                                Text("\(schema.columns(in: table).count)").font(.caption2).foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 7).padding(.horizontal, 9)
                            .background(table == activeTable ? Color.accentColor.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 8))
                            .contentShape(RoundedRectangle(cornerRadius: 8))
                        }.buttonStyle(.plain)
                    }
                }.padding(.horizontal, 7).padding(.bottom, 8)
            }
        }.background(Color(nsColor: .controlBackgroundColor))
    }

    private func relationshipDiagram(_ schema: PagilaSchema) -> some View {
        GeometryReader { geometry in
            let names = neighborhood
            let positions = diagramPositions(count: names.count, size: geometry.size)
            ZStack {
                Canvas { context, _ in
                    for relation in schema.relations where names.contains(relation.source) && names.contains(relation.target) {
                        guard let startIndex = names.firstIndex(of: relation.source), let endIndex = names.firstIndex(of: relation.target), startIndex != endIndex else { continue }
                        let start = positions[startIndex]
                        let end = positions[endIndex]
                        var path = Path()
                        path.move(to: start)
                        path.addLine(to: end)
                        context.stroke(path, with: .color(Color.accentColor.opacity(0.36)), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        let labelPoint = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
                        let label = Text("\(relation.sourceColumn) → \(relation.targetColumn)")
                            .font(.system(size: 9, design: .monospaced)).foregroundColor(.secondary)
                        context.draw(label, at: labelPoint)
                    }
                }
                ForEach(Array(names.enumerated()), id: \.element) { index, name in
                    Button { selectedTable = name } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 5) {
                                Image(systemName: "tablecells").font(.caption2)
                                Text(name).font(.caption.monospaced().weight(.semibold)).lineLimit(1)
                            }
                            Text("\(schema.columns(in: name).count) columns")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding(9).frame(width: 130, alignment: .leading)
                        .background(name == activeTable ? Color.accentColor.opacity(0.14) : Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(name == activeTable ? Color.accentColor.opacity(0.5) : Color.primary.opacity(0.07)))
                        .contentShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .position(positions[index])
                    .accessibilityLabel("Select table \(name)")
                }
                if names.count == 1 {
                    Text("No connected tables").font(.caption).foregroundStyle(.tertiary).position(x: geometry.size.width / 2, y: geometry.size.height - 18)
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .overlay(alignment: .topLeading) {
            Label("RELATIONSHIPS", systemImage: "point.3.connected.trianglepath.dotted")
                .font(.caption2.weight(.bold)).tracking(0.9).foregroundStyle(.secondary).padding(12)
        }
    }

    private func diagramPositions(count: Int, size: CGSize) -> [CGPoint] {
        guard count > 0 else { return [] }
        if count == 1 { return [CGPoint(x: size.width / 2, y: size.height / 2)] }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radiusX = max(95, min(size.width * 0.33, 260))
        let radiusY = max(50, min(size.height * 0.31, 100))
        return (0..<count).map { index in
            if index == 0 { return center }
            let ringIndex = index - 1
            let ringCount = max(1, count - 1)
            let angle = (Double(ringIndex) / Double(ringCount)) * 2 * Double.pi - Double.pi / 2
            return CGPoint(x: center.x + cos(angle) * radiusX, y: center.y + sin(angle) * radiusY)
        }
    }

    private func tableDetails(_ schema: PagilaSchema) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(activeTable).font(.title3.weight(.semibold).monospaced())
                Text("\(schema.columns(in: activeTable).count) columns").font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
            if let incoming = schema.relations.filter({ $0.target == activeTable }).first {
                Label("Referenced by \(incoming.source).\(incoming.sourceColumn)", systemImage: "arrow.down.left")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let outgoing = schema.relations.filter({ $0.source == activeTable }).first {
                Label("\(outgoing.sourceColumn) references \(outgoing.target).\(outgoing.targetColumn)", systemImage: "arrow.up.right")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Text("COLUMN").frame(maxWidth: .infinity, alignment: .leading)
                Text("TYPE").frame(width: 190, alignment: .leading)
                Text("KEY").frame(width: 80, alignment: .leading)
                Text("NULL").frame(width: 48, alignment: .trailing)
            }.font(.caption2.weight(.bold)).tracking(0.6).foregroundStyle(.tertiary)
            Divider()
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(schema.columns(in: activeTable)) { column in
                        let primary = schema.primaryKeys(in: activeTable).contains(column.column_name)
                        let foreign = schema.relations.contains { $0.source == activeTable && $0.sourceColumn == column.column_name }
                        HStack(spacing: 8) {
                            Text(column.column_name).font(.callout.monospaced()).frame(maxWidth: .infinity, alignment: .leading)
                            Text(column.data_type).font(.caption.monospaced()).foregroundStyle(.secondary).frame(width: 190, alignment: .leading)
                            HStack(spacing: 4) {
                                if primary { Image(systemName: "key.fill").foregroundStyle(.orange); Text("PK") }
                                if foreign { Image(systemName: "arrowshape.turn.up.right.fill").foregroundStyle(.blue); Text("FK") }
                            }.font(.caption2.weight(.medium)).frame(width: 80, alignment: .leading)
                            Text(column.is_nullable == "YES" ? "YES" : "NO").font(.caption2).foregroundStyle(.tertiary).frame(width: 48, alignment: .trailing)
                        }
                        .padding(.vertical, 7)
                        .overlay(alignment: .bottom) { Rectangle().fill(Color.primary.opacity(0.04)).frame(height: 1) }
                    }
                }
            }
        }
        .padding(16)
    }
}
