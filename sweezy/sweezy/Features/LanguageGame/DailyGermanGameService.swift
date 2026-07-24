//
//  DailyGermanGameService.swift
//  sweezy
//
//  Daily Wordle-style German practice for Swiss life vocabulary.
//

import Foundation

enum DailyGermanTileState: String, Codable {
    case empty
    case absent
    case present
    case correct
}

struct DailyGermanTile: Identifiable, Equatable {
    let id = UUID()
    let letter: String
    let state: DailyGermanTileState
}

struct DailyGermanGuessRow: Identifiable, Equatable {
    let id = UUID()
    let letters: [DailyGermanTile]
}

struct DailyGermanPuzzle: Identifiable, Codable, Equatable {
    let id: String
    let word: String
    let clueKey: String
    let meaningKey: String
    let exampleKey: String
    let contextKey: String
}

private struct DailyGermanStoredState: Codable {
    let dayKey: String
    var guesses: [String]
    var isSolved: Bool
    var hasAwardedXP: Bool
}

@MainActor
final class DailyGermanGameService: ObservableObject {
    @Published private(set) var dayKey: String
    @Published private(set) var puzzle: DailyGermanPuzzle
    @Published private(set) var guesses: [String]
    @Published private(set) var currentGuess: String
    @Published private(set) var isSolved: Bool
    @Published private(set) var hasAwardedXP: Bool
    @Published var validationMessage: String?

    let maxAttempts = 6

    private let storageKey = "daily_german_game.state.v1"
    private let calendar: Calendar
    private let nowProvider: () -> Date

    init(calendar: Calendar = .current, nowProvider: @escaping () -> Date = Date.init) {
        self.calendar = calendar
        self.nowProvider = nowProvider
        let key = Self.makeDayKey(for: nowProvider(), calendar: calendar)
        self.dayKey = key
        self.puzzle = Self.puzzle(for: key)
        self.guesses = []
        self.currentGuess = ""
        self.isSolved = false
        self.hasAwardedXP = false
        restoreOrReset(for: key)
    }

    var wordLength: Int {
        puzzle.word.count
    }

    var attemptsLeft: Int {
        max(0, maxAttempts - guesses.count)
    }

    var isFinished: Bool {
        isSolved || guesses.count >= maxAttempts
    }

    var nextRefreshDate: Date {
        let start = calendar.startOfDay(for: nowProvider())
        return calendar.date(byAdding: .day, value: 1, to: start) ?? nowProvider().addingTimeInterval(24 * 60 * 60)
    }

    var rows: [DailyGermanGuessRow] {
        var output = guesses.map { evaluatedRow(for: $0) }

        if !isFinished {
            output.append(inputRow)
        }

        while output.count < maxAttempts {
            output.append(emptyRow)
        }

        return output
    }

    func refreshIfNeeded() {
        let key = Self.makeDayKey(for: nowProvider(), calendar: calendar)
        guard key != dayKey else { return }
        dayKey = key
        puzzle = Self.puzzle(for: key)
        guesses = []
        currentGuess = ""
        isSolved = false
        hasAwardedXP = false
        validationMessage = nil
        persist()
    }

    func type(_ letter: String) {
        guard !isFinished else { return }
        validationMessage = nil
        let normalized = Self.normalize(letter)
        guard normalized.count == 1, Self.keyboardLetters.contains(normalized) else { return }
        guard currentGuess.count < wordLength else { return }
        currentGuess.append(normalized)
    }

    func deleteLetter() {
        guard !currentGuess.isEmpty, !isFinished else { return }
        currentGuess.removeLast()
        validationMessage = nil
    }

    func submitGuess() {
        refreshIfNeeded()
        guard !isFinished else { return }
        guard currentGuess.count == wordLength else {
            validationMessage = "daily_german.validation.short".localized(with: wordLength)
            return
        }

        let guess = Self.normalize(currentGuess)
        guard Self.acceptedWords.contains(guess) || Self.puzzles.contains(where: { $0.word == guess }) else {
            validationMessage = "daily_german.validation.unknown".localized
            return
        }

        guesses.append(guess)
        currentGuess = ""
        isSolved = guess == puzzle.word
        validationMessage = nil
        persist()
    }

    func markAwardedXP() {
        guard isSolved, !hasAwardedXP else { return }
        hasAwardedXP = true
        persist()
    }

    func keyState(for letter: String) -> DailyGermanTileState {
        let normalized = Self.normalize(letter)
        var best: DailyGermanTileState = .empty
        for guess in guesses {
            for tile in evaluate(guess: guess) where tile.letter == normalized {
                switch tile.state {
                case .correct:
                    return .correct
                case .present:
                    if best != .correct { best = .present }
                case .absent:
                    if best == .empty { best = .absent }
                case .empty:
                    break
                }
            }
        }
        return best
    }

    private var inputRow: DailyGermanGuessRow {
        let letters = Array(currentGuess).map { String($0) }
        let tiles = (0..<wordLength).map { index in
            DailyGermanTile(letter: index < letters.count ? letters[index] : "", state: .empty)
        }
        return DailyGermanGuessRow(letters: tiles)
    }

    private var emptyRow: DailyGermanGuessRow {
        DailyGermanGuessRow(letters: (0..<wordLength).map { _ in DailyGermanTile(letter: "", state: .empty) })
    }

    private func evaluatedRow(for guess: String) -> DailyGermanGuessRow {
        DailyGermanGuessRow(letters: evaluate(guess: guess))
    }

    private func evaluate(guess: String) -> [DailyGermanTile] {
        let guessLetters = Array(guess).map(String.init)
        let targetLetters = Array(puzzle.word).map(String.init)
        var result = Array(repeating: DailyGermanTileState.absent, count: guessLetters.count)
        var remaining: [String: Int] = [:]

        for index in guessLetters.indices {
            if guessLetters[index] == targetLetters[index] {
                result[index] = .correct
            } else {
                remaining[targetLetters[index], default: 0] += 1
            }
        }

        for index in guessLetters.indices where result[index] != .correct {
            let letter = guessLetters[index]
            if let count = remaining[letter], count > 0 {
                result[index] = .present
                remaining[letter] = count - 1
            }
        }

        return guessLetters.enumerated().map { DailyGermanTile(letter: $0.element, state: result[$0.offset]) }
    }

    private func restoreOrReset(for key: String) {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let stored = try? JSONDecoder().decode(DailyGermanStoredState.self, from: data),
            stored.dayKey == key
        else {
            persist()
            return
        }

        guesses = stored.guesses
        isSolved = stored.isSolved
        hasAwardedXP = stored.hasAwardedXP
    }

    private func persist() {
        let state = DailyGermanStoredState(
            dayKey: dayKey,
            guesses: guesses,
            isSolved: isSolved,
            hasAwardedXP: hasAwardedXP
        )
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private static func makeDayKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    private static func puzzle(for dayKey: String) -> DailyGermanPuzzle {
        let seed = abs(dayKey.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) })
        return puzzles[seed % puzzles.count]
    }

    private static func normalize(_ value: String) -> String {
        value
            .uppercased()
            .replacingOccurrences(of: "Ä", with: "AE")
            .replacingOccurrences(of: "Ö", with: "OE")
            .replacingOccurrences(of: "Ü", with: "UE")
            .replacingOccurrences(of: "ß", with: "SS")
            .filter { $0 >= "A" && $0 <= "Z" }
    }

    static let keyboardRows: [[String]] = [
        ["Q", "W", "E", "R", "T", "Z", "U", "I", "O", "P"],
        ["A", "S", "D", "F", "G", "H", "J", "K", "L"],
        ["Y", "X", "C", "V", "B", "N", "M"]
    ]

    private static let keyboardLetters = Set(keyboardRows.flatMap { $0 })

    private static let puzzles: [DailyGermanPuzzle] = [
        .init(id: "miete", word: "MIETE", clueKey: "daily_german.word.miete.clue", meaningKey: "daily_german.word.miete.meaning", exampleKey: "daily_german.word.miete.example", contextKey: "daily_german.word.miete.context"),
        .init(id: "kasse", word: "KASSE", clueKey: "daily_german.word.kasse.clue", meaningKey: "daily_german.word.kasse.meaning", exampleKey: "daily_german.word.kasse.example", contextKey: "daily_german.word.kasse.context"),
        .init(id: "brief", word: "BRIEF", clueKey: "daily_german.word.brief.clue", meaningKey: "daily_german.word.brief.meaning", exampleKey: "daily_german.word.brief.example", contextKey: "daily_german.word.brief.context"),
        .init(id: "konto", word: "KONTO", clueKey: "daily_german.word.konto.clue", meaningKey: "daily_german.word.konto.meaning", exampleKey: "daily_german.word.konto.example", contextKey: "daily_german.word.konto.context"),
        .init(id: "karte", word: "KARTE", clueKey: "daily_german.word.karte.clue", meaningKey: "daily_german.word.karte.meaning", exampleKey: "daily_german.word.karte.example", contextKey: "daily_german.word.karte.context"),
        .init(id: "hilfe", word: "HILFE", clueKey: "daily_german.word.hilfe.clue", meaningKey: "daily_german.word.hilfe.meaning", exampleKey: "daily_german.word.hilfe.example", contextKey: "daily_german.word.hilfe.context"),
        .init(id: "regel", word: "REGEL", clueKey: "daily_german.word.regel.clue", meaningKey: "daily_german.word.regel.meaning", exampleKey: "daily_german.word.regel.example", contextKey: "daily_german.word.regel.context"),
        .init(id: "frist", word: "FRIST", clueKey: "daily_german.word.frist.clue", meaningKey: "daily_german.word.frist.meaning", exampleKey: "daily_german.word.frist.example", contextKey: "daily_german.word.frist.context"),
        .init(id: "lohn", word: "LOHN", clueKey: "daily_german.word.lohn.clue", meaningKey: "daily_german.word.lohn.meaning", exampleKey: "daily_german.word.lohn.example", contextKey: "daily_german.word.lohn.context"),
        .init(id: "arzt", word: "ARZT", clueKey: "daily_german.word.arzt.clue", meaningKey: "daily_german.word.arzt.meaning", exampleKey: "daily_german.word.arzt.example", contextKey: "daily_german.word.arzt.context")
    ]

    private static let acceptedWords: Set<String> = [
        "ABEND", "ADRES", "AMPEL", "ANRUF", "APFEL", "ARBEIT", "ARZT", "BANK", "BRIEF", "DATEN",
        "FRIST", "HAUS", "HILFE", "KARTE", "KASSE", "KINDER", "KONTO", "LOHN", "MIETE", "REGEL",
        "SCHULE", "STADT", "STEUER", "TERMIN", "WOHNT", "ZAHLT"
    ]
}
