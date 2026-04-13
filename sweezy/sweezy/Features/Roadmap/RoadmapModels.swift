//
//  RoadmapModels.swift
//  sweezy
//
//  Mountain-style integration roadmap with 10 levels
//

import SwiftUI

// MARK: - Level Task Model
struct LevelTask: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let iconName: String
    let type: TaskType
    let targetId: String? // checklist slug, guide category, or special action
    /// Legacy/static reward, kept for potential future tuning.
    /// UI should prefer `effectiveXPReward`, which is derived from `GamificationXP`
    /// to stay in sync with global XP rules.
    let xpReward: Int
    let isPremiumOnly: Bool
    
    enum TaskType: String, Codable {
        case checklist = "checklist"
        case guideCategory = "guide_category"
        case guide = "guide"
        case action = "action" // special actions like "visit map", "set reminder"
    }
    
    /// XP used for display and roadmap summaries.
    /// Built on top of `GamificationXP`, so numbers in Roadmap
    /// are always согласованы с глобальними правилами.
    var effectiveXPReward: Int {
        switch type {
        case .checklist:
            return GamificationXP.value(for: .checklistCompleted)
        case .guideCategory, .guide:
            return GamificationXP.value(for: .guideReadCompleted)
        case .action:
            return GamificationXP.value(for: .roadmapStageCompleted)
        }
    }
}

// MARK: - Roadmap Level Model
struct RoadmapLevel: Identifiable, Codable {
    let id: Int
    let title: String
    let subtitle: String
    let description: String
    let iconName: String
    let requiredProgress: Int // % of previous level to unlock
    let estimatedDays: String
    let isPremiumOnly: Bool
    let relatedChecklistIds: [String]
    let relatedGuideCategories: [String]
    let tips: [String]
    let premiumTips: [String] // Extra tips for premium users
    let tasks: [LevelTask] // Detailed tasks for this level
    
    var altitude: Int { id * 500 } // Meters for mountain visualization
}

// MARK: - Level Status
enum LevelStatus: Codable {
    case locked
    case available
    case inProgress
    case completed
    
    var iconName: String {
        switch self {
        case .locked: return "lock.fill"
        case .available: return "play.circle.fill"
        case .inProgress: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .locked: return Theme.Colors.textTertiary
        case .available: return Theme.Colors.primary
        case .inProgress: return Theme.Colors.accent
        case .completed: return Theme.Colors.success
        }
    }
}

// MARK: - User Progress
struct RoadmapProgress: Codable {
    var currentLevel: Int
    var levelProgress: [Int: Double] // levelId: progress 0.0-1.0
    var completedLevels: Set<Int>
    var skippedLevels: Set<Int> // Premium feature
    var unlockedAt: [Int: Date]
    var completedAt: [Int: Date]
    
    static var empty: RoadmapProgress {
        RoadmapProgress(
            currentLevel: 1,
            levelProgress: [1: 0.0],
            completedLevels: [],
            skippedLevels: [],
            unlockedAt: [1: Date()],
            completedAt: [:]
        )
    }
    
    func status(for levelId: Int, isPremium: Bool) -> LevelStatus {
        if completedLevels.contains(levelId) || skippedLevels.contains(levelId) {
            return .completed
        }
        if levelId == currentLevel {
            return .inProgress
        }
        if levelId < currentLevel {
            return .completed
        }
        // Check if previous level is 80% complete or premium can skip
        let previousProgress = levelProgress[levelId - 1] ?? 0
        if previousProgress >= 0.8 || (isPremium && levelId <= currentLevel + 2) {
            return .available
        }
        return .locked
    }
    
    func progress(for levelId: Int) -> Double {
        levelProgress[levelId] ?? 0.0
    }
}

// MARK: - Default Levels Data
extension RoadmapLevel {
    static let allLevels: [RoadmapLevel] = [

        // LEVEL 1: Базовий табір
        RoadmapLevel(
            id: 1,
            title: "Базовий табір",
            subtitle: "Перші кроки в Швейцарії",
            description: "Реєстрація, документи та перші організаційні кроки. Ваш старт у новій країні.",
            iconName: "flag.fill",
            requiredProgress: 0,
            estimatedDays: "1–7 днів",
            isPremiumOnly: false,
            relatedChecklistIds: ["arrival"],
            relatedGuideCategories: ["documents", "emergency"],
            tips: [
                "Зареєструйтесь в Gemeinde протягом 14 днів після прибуття",
                "Візьміть з собою всі оригінали документів",
                "Зробіть фото і скани паспорта та дозволу на проживання"
            ],
            premiumTips: [
                "🎯 Найкращий час для реєстрації: вівторок–четвер зранку",
                "📍 Уникайте понеділків — найбільші черги"
            ],
            tasks: [
                LevelTask(id: "1-1", title: "Пройти чек-лист «Перші кроки»", description: "Реєстрація, банк, страховка — базовий старт", iconName: "checklist", type: .checklist, targetId: "arrival", xpReward: 100, isPremiumOnly: false),
                LevelTask(id: "1-2", title: "Прочитати гіди про документи", description: "Anmeldung, Ausweis S, дозволи", iconName: "doc.text", type: .guideCategory, targetId: "documents", xpReward: 30, isPremiumOnly: false),
                LevelTask(id: "1-3", title: "Зберегти номери екстрених служб", description: "144, 117, 118, 143 — запам'ятайте", iconName: "phone.badge.plus", type: .action, targetId: "save-contacts", xpReward: 20, isPremiumOnly: false),
                LevelTask(id: "1-4", title: "Знайти своє Gemeinde на карті", description: "Де реєструватись і куди звертатись", iconName: "map", type: .action, targetId: "map-gemeinde", xpReward: 20, isPremiumOnly: false),
                LevelTask(id: "1-5", title: "Прочитати гіди про екстрені ситуації", description: "Що робити при хворобі, крадіжці, аварії", iconName: "exclamationmark.triangle", type: .guideCategory, targetId: "emergency", xpReward: 25, isPremiumOnly: false),
                LevelTask(id: "1-6", title: "Перевірити пошту в поштовій скриньці", description: "Листи від Gemeinde та страхової важливі", iconName: "envelope.open", type: .action, targetId: "check-mailbox", xpReward: 15, isPremiumOnly: false)
            ]
        ),

        // LEVEL 2: Перший привал
        RoadmapLevel(
            id: 2,
            title: "Перший привал",
            subtitle: "Банк, SIM та фінансова база",
            description: "Відкриття рахунку, швейцарська SIM-картка, TWINT та перше розуміння витрат.",
            iconName: "creditcard.fill",
            requiredProgress: 80,
            estimatedDays: "3–10 днів",
            isPremiumOnly: false,
            relatedChecklistIds: [],
            relatedGuideCategories: ["banking", "finance"],
            tips: [
                "PostFinance та Neon — найдоступніші варіанти для нових жителів",
                "Для відкриття рахунку потрібен Permit та Anmeldebestätigung",
                "Swisscom, Sunrise, Salt — основні оператори. M-Budget — найдешевший"
            ],
            premiumTips: [
                "💡 Neon та Yuh — безкоштовні цифрові банки без комісій",
                "📱 Wingo та M-Budget — найдешевші тарифи для мігрантів"
            ],
            tasks: [
                LevelTask(id: "2-1", title: "Відкрити банківський рахунок", description: "PostFinance, Neon або будь-який банк", iconName: "building.columns", type: .action, targetId: "open-bank-account", xpReward: 80, isPremiumOnly: false),
                LevelTask(id: "2-2", title: "Отримати швейцарську SIM-карту", description: "Prepaid або контракт — порівняйте", iconName: "simcard.fill", type: .action, targetId: "get-sim", xpReward: 40, isPremiumOnly: false),
                LevelTask(id: "2-3", title: "Вивчити гіди про банківські послуги", description: "Рахунки, картки, перекази в Швейцарії", iconName: "building.columns.circle", type: .guideCategory, targetId: "banking", xpReward: 30, isPremiumOnly: false),
                LevelTask(id: "2-4", title: "Встановити TWINT або Paymit", description: "Основний спосіб оплати в Швейцарії", iconName: "qrcode", type: .action, targetId: "setup-twint", xpReward: 25, isPremiumOnly: false),
                LevelTask(id: "2-5", title: "Розібратись з Quellensteuer", description: "Як утримується податок з зарплати", iconName: "percent", type: .guideCategory, targetId: "finance", xpReward: 30, isPremiumOnly: false),
                LevelTask(id: "2-6", title: "Підключити eBill (електронні рахунки)", description: "Оплата комунальних та рахунків онлайн", iconName: "bolt.fill", type: .action, targetId: "setup-ebill", xpReward: 20, isPremiumOnly: false)
            ]
        ),

        // LEVEL 3: Гірська хатина
        RoadmapLevel(
            id: 3,
            title: "Гірська хатина",
            subtitle: "Житло та медичне страхування",
            description: "Пошук постійного житла, оформлення обов'язкового медстрахування та пошук лікаря.",
            iconName: "house.fill",
            requiredProgress: 80,
            estimatedDays: "2–8 тижнів",
            isPremiumOnly: false,
            relatedChecklistIds: ["insurance", "housing"],
            relatedGuideCategories: ["insurance", "housing"],
            tips: [
                "Медичне страхування — обов'язково протягом 3 місяців після реєстрації",
                "Homegate, Immoscout24, Tutti.ch — основні платформи оренди",
                "Betreibungsregisterauszug — обов'язковий документ для оренди"
            ],
            premiumTips: [
                "🏠 Facebook групи українців — часто є пропозиції без посередників",
                "💰 Comparis.ch — найкращий порівнювач страховок та квартир"
            ],
            tasks: [
                LevelTask(id: "3-1", title: "Оформити медичне страхування (KK)", description: "Обов'язково протягом 3 місяців!", iconName: "cross.case.fill", type: .checklist, targetId: "insurance", xpReward: 100, isPremiumOnly: false),
                LevelTask(id: "3-2", title: "Пройти чек-лист пошуку житла", description: "Бюджет, дossier, перегляди, договір", iconName: "house.fill", type: .checklist, targetId: "housing", xpReward: 80, isPremiumOnly: false),
                LevelTask(id: "3-3", title: "Вивчити гіди про страхування", description: "Моделі HMO/Telmed, франшизи, субсидії", iconName: "shield.fill", type: .guideCategory, targetId: "insurance", xpReward: 35, isPremiumOnly: false),
                LevelTask(id: "3-4", title: "Порівняти страховки на Comparis", description: "Знайдіть найдешевшу пропозицію", iconName: "chart.bar.fill", type: .action, targetId: "compare-insurance", xpReward: 25, isPremiumOnly: false),
                LevelTask(id: "3-5", title: "Знайти Hausarzt (сімейний лікар)", description: "Зареєструйтесь заздалегідь — черги до 4 тижнів", iconName: "stethoscope", type: .action, targetId: "find-hausarzt", xpReward: 35, isPremiumOnly: false),
                LevelTask(id: "3-6", title: "Вивчити гіди про житло", description: "Дossier, Hausordnung, права орендаря", iconName: "doc.badge.plus", type: .guideCategory, targetId: "housing", xpReward: 30, isPremiumOnly: false),
                LevelTask(id: "3-7", title: "Подати на субсидію Prämienverbilligung", description: "Знижка на страховку при низькому доході", iconName: "tag.fill", type: .action, targetId: "apply-premienverbilligung", xpReward: 40, isPremiumOnly: true)
            ]
        ),

        // LEVEL 4: Альпійські луки
        RoadmapLevel(
            id: 4,
            title: "Альпійські луки",
            subtitle: "Пошук роботи та права на роботі",
            description: "Швейцарське CV, RAV, перша робота, трудовий договір та розуміння зарплатного листка.",
            iconName: "briefcase.fill",
            requiredProgress: 80,
            estimatedDays: "1–3 місяці",
            isPremiumOnly: false,
            relatedChecklistIds: ["work"],
            relatedGuideCategories: ["work", "finance"],
            tips: [
                "LinkedIn і Jobs.ch — основні платформи пошуку",
                "RAV (Regionales Arbeitsvermittlungszentrum) — безкоштовна допомога",
                "Швейцарське CV: фото + зворотня хронологія + максимум 2 сторінки"
            ],
            premiumTips: [
                "📝 Шаблони CV та мотиваційних листів в додатку",
                "🎯 Topf-20 компаній що активно наймають мігрантів"
            ],
            tasks: [
                LevelTask(id: "4-1", title: "Пройти чек-лист пошуку роботи", description: "CV, LinkedIn, RAV, перше інтерв'ю", iconName: "checklist", type: .checklist, targetId: "work", xpReward: 100, isPremiumOnly: false),
                LevelTask(id: "4-2", title: "Зареєструватись в RAV", description: "Безкоштовна допомога з CV та вакансіями", iconName: "building.2.fill", type: .action, targetId: "register-rav", xpReward: 50, isPremiumOnly: false),
                LevelTask(id: "4-3", title: "Вивчити гіди про роботу", description: "CV, інтерв'ю, права працівника, зарплата", iconName: "doc.text.fill", type: .guideCategory, targetId: "work", xpReward: 40, isPremiumOnly: false),
                LevelTask(id: "4-4", title: "Відправити 5 заявок на роботу", description: "Персоналізовані листи — ключ до успіху", iconName: "paperplane.fill", type: .action, targetId: "apply-jobs", xpReward: 50, isPremiumOnly: false),
                LevelTask(id: "4-5", title: "Розібратись з Lohnausweis", description: "AHV, ALV, BVG — що утримується", iconName: "doc.text.magnifyingglass", type: .guideCategory, targetId: "finance", xpReward: 35, isPremiumOnly: false),
                LevelTask(id: "4-6", title: "Перевірити визнання диплому (SBFI)", description: "Для регульованих професій — обов'язково", iconName: "graduationcap.fill", type: .action, targetId: "diploma-recognition", xpReward: 45, isPremiumOnly: false),
                LevelTask(id: "4-7", title: "Створити LinkedIn-профіль", description: "80% вакансій знаходять через мережу", iconName: "person.crop.square.filled.and.at.rectangle", type: .action, targetId: "create-linkedin", xpReward: 30, isPremiumOnly: true)
            ]
        ),

        // LEVEL 5: Перевал
        RoadmapLevel(
            id: 5,
            title: "Перевал",
            subtitle: "Мова, освіта та інтеграція",
            description: "Мовні курси, рівень B1, інтеграційні програми та соціальні зв'язки.",
            iconName: "book.fill",
            requiredProgress: 80,
            estimatedDays: "3–6 місяців",
            isPremiumOnly: false,
            relatedChecklistIds: [],
            relatedGuideCategories: ["education", "integration"],
            tips: [
                "Безкоштовні або субсидовані курси від кантону — запитайте в Gemeinde",
                "Рівень B1 — мінімум для більшості робіт і натуралізації",
                "fide — офіційна платформа мовних курсів для інтеграції"
            ],
            premiumTips: [
                "🎓 Список акредитованих мовних шкіл у вашому кантоні",
                "💡 Tandem-партнери: безкоштовна практика з носієм мови"
            ],
            tasks: [
                LevelTask(id: "5-1", title: "Записатись на мовні курси", description: "Канти часто субсидують — дізнайтесь в Gemeinde", iconName: "character.bubble.fill", type: .action, targetId: "enroll-language", xpReward: 80, isPremiumOnly: false),
                LevelTask(id: "5-2", title: "Вивчити гіди про освіту", description: "Школа, університет, курси підвищення", iconName: "book.closed.fill", type: .guideCategory, targetId: "education", xpReward: 35, isPremiumOnly: false),
                LevelTask(id: "5-3", title: "Вивчити гіди про інтеграцію", description: "Vereine, програми, культура", iconName: "person.3.fill", type: .guideCategory, targetId: "integration", xpReward: 30, isPremiumOnly: false),
                LevelTask(id: "5-4", title: "Знайти Tandem-партнера", description: "Безкоштовна мовна практика з носієм", iconName: "person.2.fill", type: .action, targetId: "find-tandem", xpReward: 25, isPremiumOnly: false),
                LevelTask(id: "5-5", title: "Досягти рівня A2 або вище", description: "Підтвердіть прогрес тестом на fide-info.ch", iconName: "checkmark.seal.fill", type: .action, targetId: "language-test-a2", xpReward: 60, isPremiumOnly: false),
                LevelTask(id: "5-6", title: "Приєднатись до місцевого клубу або Verein", description: "Найкращий спосіб познайомитись зі швейцарцями", iconName: "figure.socialdance", type: .action, targetId: "join-club", xpReward: 40, isPremiumOnly: false)
            ]
        ),

        // LEVEL 6: Високогір'я
        RoadmapLevel(
            id: 6,
            title: "Високогір'я",
            subtitle: "Фінансове планування та пенсія",
            description: "3-й стовп, податкова декларація, бюджет та довгострокова фінансова стабільність.",
            iconName: "chart.line.uptrend.xyaxis",
            requiredProgress: 80,
            estimatedDays: "1–2 місяці",
            isPremiumOnly: false,
            relatedChecklistIds: [],
            relatedGuideCategories: ["finance", "lifestyle"],
            tips: [
                "Säule 3a — до 7 258 CHF/рік відраховується від оподатковуваного доходу",
                "Подати декларацію вчасно — термін зазвичай 31 березня",
                "VIAC, Frankly, Finpension — популярні 3a провайдери з інвестиціями"
            ],
            premiumTips: [
                "📊 Калькулятор пенсійних накопичень і 3a стратегій",
                "🎯 Як відкрити 5 рахунків 3a та оптимізувати оподаткування"
            ],
            tasks: [
                LevelTask(id: "6-1", title: "Відкрити рахунок Säule 3a", description: "Економія ~2 100 CHF на податках на рік", iconName: "banknote.fill", type: .action, targetId: "open-3a", xpReward: 100, isPremiumOnly: false),
                LevelTask(id: "6-2", title: "Перевірити свій Pensionskasse (Säule 2)", description: "Запитайте виписку у роботодавця", iconName: "doc.text.magnifyingglass", type: .action, targetId: "check-pillar2", xpReward: 40, isPremiumOnly: false),
                LevelTask(id: "6-3", title: "Вивчити гіди про фінанси", description: "Déclaration, Steuern, 3a — все разом", iconName: "chart.pie.fill", type: .guideCategory, targetId: "finance", xpReward: 35, isPremiumOnly: false),
                LevelTask(id: "6-4", title: "Прочитати гід «3-й стовп»", description: "Як і де відкрити, скільки вносити", iconName: "sparkles", type: .guideCategory, targetId: "lifestyle", xpReward: 40, isPremiumOnly: false),
                LevelTask(id: "6-5", title: "Подати першу податкову декларацію", description: "Використайте всі відрахування", iconName: "tray.and.arrow.up.fill", type: .action, targetId: "file-tax-return", xpReward: 60, isPremiumOnly: false),
                LevelTask(id: "6-6", title: "Налаштувати автоматичний внесок в 3a", description: "Регулярні внески = фінансова звичка", iconName: "arrow.clockwise", type: .action, targetId: "setup-3a-autopay", xpReward: 30, isPremiumOnly: true)
            ]
        ),

        // LEVEL 7: Льодовик
        RoadmapLevel(
            id: 7,
            title: "Льодовик",
            subtitle: "Транспорт та мобільність",
            description: "GA, Halbtax, SBB Mobile, велосипед та водійські права у Швейцарії.",
            iconName: "tram.fill",
            requiredProgress: 80,
            estimatedDays: "1–6 місяців",
            isPremiumOnly: false,
            relatedChecklistIds: [],
            relatedGuideCategories: ["transport"],
            tips: [
                "Halbtax — 50% знижка на весь транспорт за 185 CHF/рік",
                "Українські права дійсні 12 місяців, потім потрібен обмін",
                "SBB Mobile — додаток для квитків, розкладу та подорожей"
            ],
            premiumTips: [
                "🚗 Найдешевші автошколи по кантонах",
                "🎫 Коли GA вигідніше за Halbtax — особистий калькулятор"
            ],
            tasks: [
                LevelTask(id: "7-1", title: "Оформити Halbtax або SuperSaver", description: "50% знижка на весь транспорт SBB", iconName: "ticket.fill", type: .action, targetId: "get-halbtax", xpReward: 60, isPremiumOnly: false),
                LevelTask(id: "7-2", title: "Завантажити SBB Mobile", description: "Квитки, розклад, підписки прямо в телефоні", iconName: "iphone.gen3", type: .action, targetId: "download-sbb", xpReward: 20, isPremiumOnly: false),
                LevelTask(id: "7-3", title: "Вивчити гіди про транспорт", description: "SBB, трамваї, автобуси та GA/Halbtax", iconName: "bus.fill", type: .guideCategory, targetId: "transport", xpReward: 30, isPremiumOnly: false),
                LevelTask(id: "7-4", title: "Обміняти водійські права", description: "12 місяців — дедлайн для обміну", iconName: "car.fill", type: .action, targetId: "exchange-license", xpReward: 70, isPremiumOnly: false),
                LevelTask(id: "7-5", title: "Порахувати: GA чи Halbtax", description: "Що вигідніше для вашого маршруту", iconName: "equal.circle.fill", type: .action, targetId: "calculate-ga-vs-halbtax", xpReward: 20, isPremiumOnly: false),
                LevelTask(id: "7-6", title: "Зареєструвати велосипед", description: "Velopass або страхування від крадіжки", iconName: "bicycle", type: .action, targetId: "register-bicycle", xpReward: 15, isPremiumOnly: true)
            ]
        ),

        // LEVEL 8: Гірський хребет
        RoadmapLevel(
            id: 8,
            title: "Гірський хребет",
            subtitle: "Сім'я, діти та здоров'я",
            description: "Возз'єднання сім'ї, школа для дітей, Kinderzulagen та глибше розуміння медицини.",
            iconName: "figure.2.and.child.holdinghands",
            requiredProgress: 80,
            estimatedDays: "2–6 місяців",
            isPremiumOnly: false,
            relatedChecklistIds: ["family", "healthcare"],
            relatedGuideCategories: ["education", "healthcare"],
            tips: [
                "Школа безкоштовна та обов'язкова з 4–6 років",
                "Kinderzulagen — 200–300 CHF/місяць на дитину — подавайте через роботодавця",
                "Лікар за направленням (HMO/Telmed) — дешевше і правильніше"
            ],
            premiumTips: [
                "📚 Рейтинг шкіл по районах та кантонах",
                "👨‍👩‍👧 Покроковий гід возз'єднання сім'ї з документами"
            ],
            tasks: [
                LevelTask(id: "8-1", title: "Пройти чек-лист сімейного возз'єднання", description: "Документи, подача, терміни", iconName: "person.2.badge.plus", type: .checklist, targetId: "family", xpReward: 100, isPremiumOnly: false),
                LevelTask(id: "8-2", title: "Пройти чек-лист медичної допомоги", description: "Hausarzt, аптека, невідкладна", iconName: "cross.case.fill", type: .checklist, targetId: "healthcare", xpReward: 80, isPremiumOnly: false),
                LevelTask(id: "8-3", title: "Вивчити гіди про освіту", description: "Система шкіл, садки, DaZ-підтримка", iconName: "graduationcap.fill", type: .guideCategory, targetId: "education", xpReward: 35, isPremiumOnly: false),
                LevelTask(id: "8-4", title: "Оформити Kinderzulagen (дитячу допомогу)", description: "200–300 CHF/місяць через роботодавця", iconName: "banknote.fill", type: .action, targetId: "apply-kinderzulagen", xpReward: 60, isPremiumOnly: false),
                LevelTask(id: "8-5", title: "Знайти дитячі гуртки та секції", description: "Спорт, музика, мови в місцевих клубах", iconName: "figure.run", type: .action, targetId: "find-activities", xpReward: 25, isPremiumOnly: false),
                LevelTask(id: "8-6", title: "Вивчити гіди про медицину", description: "Спеціалісти, щеплення, психологія", iconName: "heart.text.square.fill", type: .guideCategory, targetId: "healthcare", xpReward: 30, isPremiumOnly: false),
                LevelTask(id: "8-7", title: "Зробити профілактичний огляд у лікаря", description: "Checkup кожні 2 роки — рекомендовано", iconName: "waveform.path.ecg", type: .action, targetId: "health-checkup", xpReward: 30, isPremiumOnly: true)
            ]
        ),

        // LEVEL 9: Передвершина
        RoadmapLevel(
            id: 9,
            title: "Передвершина",
            subtitle: "Право, захист та дозвіл C",
            description: "Права як резидента, дозвіл C, підготовка до натуралізації та правовий захист.",
            iconName: "person.badge.shield.checkmark.fill",
            requiredProgress: 80,
            estimatedDays: "1–10 років",
            isPremiumOnly: false,
            relatedChecklistIds: ["legal"],
            relatedGuideCategories: ["legal", "lifestyle"],
            tips: [
                "Дозвіл C — після 5 (ЄС) або 10 (інші) років з хорошою інтеграцією",
                "Мова B1 + без боргів + без правопорушень = умови для C",
                "Безкоштовна юридична допомога: Caritas, HEKS, SFH"
            ],
            premiumTips: [
                "📋 Повний чек-лист документів для Permit C",
                "🎯 Кантони з найшвидшим процесом натуралізації"
            ],
            tasks: [
                LevelTask(id: "9-1", title: "Пройти чек-лист правового захисту", description: "Права, юридична допомога, Migrationsamt", iconName: "checklist", type: .checklist, targetId: "legal", xpReward: 80, isPremiumOnly: false),
                LevelTask(id: "9-2", title: "Вивчити гіди про правовий захист", description: "Права орендаря, трудові права, міграція", iconName: "hammer.fill", type: .guideCategory, targetId: "legal", xpReward: 40, isPremiumOnly: false),
                LevelTask(id: "9-3", title: "Прочитати гід «Дозвіл C і громадянство»", description: "Умови, документи, терміни", iconName: "person.badge.key.fill", type: .guideCategory, targetId: "lifestyle", xpReward: 50, isPremiumOnly: false),
                LevelTask(id: "9-4", title: "Скласти мовний тест B1 (fide)", description: "Мінімальна вимога для дозволу C", iconName: "checkmark.seal.fill", type: .action, targetId: "fide-b1-test", xpReward: 80, isPremiumOnly: false),
                LevelTask(id: "9-5", title: "Перевірити свій статус Betreibungsregister", description: "Відсутність боргів — умова для C і натуралізації", iconName: "doc.text.magnifyingglass", type: .action, targetId: "check-betreibung", xpReward: 30, isPremiumOnly: false),
                LevelTask(id: "9-6", title: "Дізнатись про умови натуралізації", description: "Кантональні вимоги суттєво різняться", iconName: "flag.checkered.2.crossed", type: .action, targetId: "naturalization-check", xpReward: 40, isPremiumOnly: false),
                LevelTask(id: "9-7", title: "Подати заявку на Permit C", description: "Крок до постійного проживання", iconName: "tray.and.arrow.up.fill", type: .action, targetId: "apply-permit-c", xpReward: 150, isPremiumOnly: true)
            ]
        ),

        // LEVEL 10: Вершина
        RoadmapLevel(
            id: 10,
            title: "Вершина",
            subtitle: "Повна інтеграція",
            description: "Ви — частина Швейцарії. Швейцарська культура, Verein, волонтерство та громадянство.",
            iconName: "star.fill",
            requiredProgress: 80,
            estimatedDays: "Постійно",
            isPremiumOnly: false,
            relatedChecklistIds: [],
            relatedGuideCategories: ["lifestyle", "integration"],
            tips: [
                "Verein (клуб) — найкращий спосіб познайомитись зі швейцарцями",
                "Волонтерство зараховується в анкеті при натуралізації",
                "Діліться своїм досвідом — надихайте нових мігрантів"
            ],
            premiumTips: [
                "🤝 Нетворкінг події для українців у Швейцарії",
                "🏆 Ексклюзивна спільнота тих, хто пройшов весь шлях"
            ],
            tasks: [
                LevelTask(id: "10-1", title: "Вивчити гіди «Життя в Швейцарії»", description: "Культура, сусіди, Verein, звичаї", iconName: "sun.horizon.fill", type: .guideCategory, targetId: "lifestyle", xpReward: 50, isPremiumOnly: false),
                LevelTask(id: "10-2", title: "Приєднатись до місцевого Verein", description: "Спорт, музика, хобі — знайдіть своє", iconName: "person.3.fill", type: .action, targetId: "join-verein", xpReward: 80, isPremiumOnly: false),
                LevelTask(id: "10-3", title: "Вивчити гіди про інтеграцію", description: "Швейцарська ментальність та суспільство", iconName: "globe.europe.africa.fill", type: .guideCategory, targetId: "integration", xpReward: 35, isPremiumOnly: false),
                LevelTask(id: "10-4", title: "Стати волонтером у Швейцарії", description: "Плюс при натуралізації та знайомства", iconName: "heart.fill", type: .action, targetId: "volunteer", xpReward: 80, isPremiumOnly: false),
                LevelTask(id: "10-5", title: "Взяти участь у місцевому голосуванні", description: "Після отримання громадянства — ваше право", iconName: "checkmark.rectangle.stack.fill", type: .action, targetId: "vote", xpReward: 50, isPremiumOnly: false),
                LevelTask(id: "10-6", title: "Розпочати процес натуралізації", description: "Подайте заявку в Gemeinde", iconName: "flag.checkered", type: .action, targetId: "start-naturalization", xpReward: 200, isPremiumOnly: false),
                LevelTask(id: "10-7", title: "Поділитись своєю історією", description: "Надихніть тих, хто тільки починає", iconName: "quote.bubble.fill", type: .action, targetId: "share-story", xpReward: 100, isPremiumOnly: true)
            ]
        )
    ]
}

// MARK: - Mountain Theme Colors
struct MountainTheme {
    static let skyGradient = LinearGradient(
        colors: [
            Theme.Colors.primaryBackground,
            Theme.Colors.secondaryBackground,
            Theme.Colors.primaryBackground
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let snowColor = Theme.Colors.adaptiveSurface
    static let rockColor = Theme.Colors.secondaryBackground
    static let grassColor = Theme.Colors.primary.opacity(0.18)
    static let pathColor = Theme.Colors.accent
    static let lockedColor = Theme.Colors.adaptiveSurface
    static let glowColor = Theme.Colors.primary
    
    static func altitudeColor(for altitude: Int) -> Color {
        switch altitude {
        case 0..<1500: return grassColor
        case 1500..<3000: return rockColor
        case 3000..<4000: return Color(red: 0.6, green: 0.6, blue: 0.65)
        default: return snowColor
        }
    }
}

