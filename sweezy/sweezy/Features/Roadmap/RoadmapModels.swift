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
            description: "Основні документи та реєстрація. Ваш старт у новій країні.",
            iconName: "flag.fill",
            requiredProgress: 0,
            estimatedDays: "1-7 днів",
            isPremiumOnly: false,
            relatedChecklistIds: ["first-7-days"],
            relatedGuideCategories: ["documents"],
            tips: [
                "Зареєструйтесь в міграційній службі протягом 14 днів",
                "Візьміть з собою всі оригінали документів",
                "Зробіть копії паспорта та візи"
            ],
            premiumTips: [
                "🎯 Найкращий час для реєстрації: вівторок-четвер вранці",
                "📍 Уникайте понеділків — найбільші черги"
            ],
            tasks: [
                LevelTask(id: "1-1", title: "Пройти чек-лист «Перші 7 днів»", description: "Базові кроки для старту в Швейцарії", iconName: "checklist", type: .checklist, targetId: "first-7-days", xpReward: 100, isPremiumOnly: false),
                LevelTask(id: "1-2", title: "Прочитати гід про документи", description: "Дізнайтесь які документи потрібні", iconName: "doc.text", type: .guideCategory, targetId: "documents", xpReward: 30, isPremiumOnly: false),
                LevelTask(id: "1-3", title: "Знайти своє Gemeinde на карті", description: "Локалізуйте міграційну службу поруч", iconName: "map", type: .action, targetId: "map-gemeinde", xpReward: 20, isPremiumOnly: false),
                LevelTask(id: "1-4", title: "Зберегти важливі контакти", description: "Екстрені служби та консульство", iconName: "phone.badge.plus", type: .action, targetId: "save-contacts", xpReward: 15, isPremiumOnly: false)
            ]
        ),
        
        // LEVEL 2: Перший привал
        RoadmapLevel(
            id: 2,
            title: "Перший привал",
            subtitle: "Банк та комунікації",
            description: "Відкриття рахунку, мобільний зв'язок, базова інфраструктура.",
            iconName: "creditcard.fill",
            requiredProgress: 80,
            estimatedDays: "3-10 днів",
            isPremiumOnly: false,
            relatedChecklistIds: ["banking-setup"],
            relatedGuideCategories: ["finance", "banking"],
            tips: [
                "Порівняйте тарифи різних банків",
                "Для відкриття рахунку потрібен Permit",
                "Swisscom, Sunrise, Salt — основні оператори"
            ],
            premiumTips: [
                "💡 Neon та Yuh — безкоштовні цифрові банки",
                "📱 Wingo та M-Budget — найдешевші тарифи"
            ],
            tasks: [
                LevelTask(id: "2-1", title: "Відкрити банківський рахунок", description: "Оберіть банк та подайте заявку", iconName: "building.columns", type: .checklist, targetId: "banking-setup", xpReward: 80, isPremiumOnly: false),
                LevelTask(id: "2-2", title: "Отримати швейцарську SIM-карту", description: "Порівняйте тарифи операторів", iconName: "simcard", type: .guideCategory, targetId: "banking", xpReward: 40, isPremiumOnly: false),
                LevelTask(id: "2-3", title: "Налаштувати TWINT", description: "Популярний спосіб оплати в Швейцарії", iconName: "qrcode", type: .action, targetId: "setup-twint", xpReward: 25, isPremiumOnly: false),
                LevelTask(id: "2-4", title: "Прочитати про податки", description: "Базове розуміння Quellensteuer", iconName: "doc.text", type: .guideCategory, targetId: "finance", xpReward: 30, isPremiumOnly: false)
            ]
        ),
        
        // LEVEL 3: Гірська хатина
        RoadmapLevel(
            id: 3,
            title: "Гірська хатина",
            subtitle: "Житло та страхування",
            description: "Пошук постійного житла та обов'язкове медичне страхування.",
            iconName: "house.fill",
            requiredProgress: 80,
            estimatedDays: "2-8 тижнів",
            isPremiumOnly: false,
            relatedChecklistIds: ["housing-search", "health-insurance"],
            relatedGuideCategories: ["housing", "insurance"],
            tips: [
                "Homegate, Immoscout24 — основні платформи",
                "Медичне страхування обов'язкове протягом 3 місяців",
                "Порівняйте франшизи страховок"
            ],
            premiumTips: [
                "🏠 Facebook групи українців — часто є пропозиції",
                "💰 Comparis.ch — найкращий порівнювач страховок"
            ],
            tasks: [
                LevelTask(id: "3-1", title: "Оформити медичне страхування", description: "Обов'язково протягом 3 місяців!", iconName: "cross.case", type: .checklist, targetId: "health-insurance", xpReward: 100, isPremiumOnly: false),
                LevelTask(id: "3-2", title: "Почати пошук житла", description: "Homegate, Immoscout24, Facebook", iconName: "house.fill", type: .checklist, targetId: "housing-search", xpReward: 80, isPremiumOnly: false),
                LevelTask(id: "3-3", title: "Вивчити гід по страхуванню", description: "Франшизи, моделі, порівняння", iconName: "shield", type: .guideCategory, targetId: "insurance", xpReward: 35, isPremiumOnly: false),
                LevelTask(id: "3-4", title: "Порівняти страховки на Comparis", description: "Знайдіть найкращу пропозицію", iconName: "chart.bar", type: .action, targetId: "compare-insurance", xpReward: 25, isPremiumOnly: false),
                LevelTask(id: "3-5", title: "Підготувати документи для оренди", description: "Betreibungsauszug, довідка про зарплату", iconName: "doc.badge.plus", type: .guideCategory, targetId: "housing", xpReward: 30, isPremiumOnly: true)
            ]
        ),
        
        // LEVEL 4: Альпійські луки
        RoadmapLevel(
            id: 4,
            title: "Альпійські луки",
            subtitle: "Робота та податки",
            description: "Пошук роботи, трудовий договір, податкова реєстрація.",
            iconName: "briefcase.fill",
            requiredProgress: 80,
            estimatedDays: "1-3 місяці",
            isPremiumOnly: false,
            relatedChecklistIds: ["job-search", "tax-registration"],
            relatedGuideCategories: ["work", "finance"],
            tips: [
                "LinkedIn — головна платформа для пошуку",
                "RAV — служба зайнятості, безкоштовна допомога",
                "Податки сплачуються щомісяця (Quellensteuer)"
            ],
            premiumTips: [
                "📝 Шаблони CV та мотиваційних листів в додатку",
                "🎯 Топ-20 компаній що наймають українців"
            ],
            tasks: [
                LevelTask(id: "4-1", title: "Оновити CV під швейцарський ринок", description: "Формат, мова, ключові слова", iconName: "doc.text", type: .checklist, targetId: "job-search", xpReward: 60, isPremiumOnly: false),
                LevelTask(id: "4-2", title: "Зареєструватись в RAV", description: "Безкоштовна допомога у працевлаштуванні", iconName: "building.2", type: .action, targetId: "register-rav", xpReward: 50, isPremiumOnly: false),
                LevelTask(id: "4-3", title: "Вивчити податкову систему", description: "Quellensteuer vs звичайні податки", iconName: "percent", type: .guideCategory, targetId: "finance", xpReward: 40, isPremiumOnly: false),
                LevelTask(id: "4-4", title: "Подати 5 заявок на роботу", description: "Практика — ключ до успіху", iconName: "paperplane", type: .action, targetId: "apply-jobs", xpReward: 50, isPremiumOnly: false),
                LevelTask(id: "4-5", title: "Пройти чек-лист податкової реєстрації", description: "Steuererklärung крок за кроком", iconName: "checklist", type: .checklist, targetId: "tax-registration", xpReward: 70, isPremiumOnly: true)
            ]
        ),
        
        // LEVEL 5: Перевал
        RoadmapLevel(
            id: 5,
            title: "Перевал",
            subtitle: "Мова та освіта",
            description: "Мовні курси, визнання дипломів, інтеграційні програми.",
            iconName: "book.fill",
            requiredProgress: 80,
            estimatedDays: "3-6 місяців",
            isPremiumOnly: false,
            relatedChecklistIds: ["language-courses", "diploma-recognition"],
            relatedGuideCategories: ["education", "integration"],
            tips: [
                "Безкоштовні курси від кантону",
                "SWISSUNIVERSITIES — визнання дипломів",
                "Рівень B1 — мінімум для більшості робіт"
            ],
            premiumTips: [
                "🎓 Список акредитованих мовних шкіл",
                "💡 Лайфхак: Tandem партнери для практики"
            ],
            tasks: [
                LevelTask(id: "5-1", title: "Записатись на мовні курси", description: "Німецька, французька або італійська", iconName: "character.bubble", type: .checklist, targetId: "language-courses", xpReward: 80, isPremiumOnly: false),
                LevelTask(id: "5-2", title: "Подати на визнання диплому", description: "SWISSUNIVERSITIES або SBFI", iconName: "graduationcap", type: .checklist, targetId: "diploma-recognition", xpReward: 70, isPremiumOnly: false),
                LevelTask(id: "5-3", title: "Вивчити 50 базових фраз", description: "Для щоденного спілкування", iconName: "text.bubble", type: .action, targetId: "learn-phrases", xpReward: 30, isPremiumOnly: false),
                LevelTask(id: "5-4", title: "Знайти Tandem партнера", description: "Безкоштовна мовна практика", iconName: "person.2", type: .action, targetId: "find-tandem", xpReward: 25, isPremiumOnly: false),
                LevelTask(id: "5-5", title: "Прочитати про інтеграційні програми", description: "Курси, воркшопи, нетворкінг", iconName: "person.3", type: .guideCategory, targetId: "integration", xpReward: 35, isPremiumOnly: false)
            ]
        ),
        
        // LEVEL 6: Високогір'я
        RoadmapLevel(
            id: 6,
            title: "Високогір'я",
            subtitle: "Пенсія та накопичення",
            description: "Pillar 2, Pillar 3a, довгострокове фінансове планування.",
            iconName: "chart.line.uptrend.xyaxis",
            requiredProgress: 80,
            estimatedDays: "1-2 місяці",
            isPremiumOnly: false,
            relatedChecklistIds: ["pension-setup"],
            relatedGuideCategories: ["finance"],
            tips: [
                "Pillar 3a — податкові переваги до 7056 CHF/рік",
                "Перевірте чи роботодавець робить внески в Pillar 2",
                "VIAC, Frankly — популярні 3a провайдери"
            ],
            premiumTips: [
                "📊 Калькулятор пенсійних накопичень",
                "🎯 Оптимальна стратегія інвестування 3a"
            ],
            tasks: [
                LevelTask(id: "6-1", title: "Відкрити рахунок Pillar 3a", description: "Податкова економія до 2000 CHF/рік", iconName: "banknote", type: .checklist, targetId: "pension-setup", xpReward: 100, isPremiumOnly: false),
                LevelTask(id: "6-2", title: "Перевірити свій Pillar 2", description: "Запитайте виписку у роботодавця", iconName: "doc.text.magnifyingglass", type: .action, targetId: "check-pillar2", xpReward: 40, isPremiumOnly: false),
                LevelTask(id: "6-3", title: "Порівняти 3a провайдерів", description: "VIAC, Frankly, банки", iconName: "chart.bar", type: .guideCategory, targetId: "finance", xpReward: 35, isPremiumOnly: false),
                LevelTask(id: "6-4", title: "Налаштувати автоплатіж в 3a", description: "Регулярні внески = звичка", iconName: "arrow.clockwise", type: .action, targetId: "setup-autopay", xpReward: 30, isPremiumOnly: true),
                LevelTask(id: "6-5", title: "Вивчити інвестиційні стратегії", description: "Акції vs облігації в 3a", iconName: "chart.pie", type: .action, targetId: "learn-investing", xpReward: 40, isPremiumOnly: true)
            ]
        ),
        
        // LEVEL 7: Льодовик
        RoadmapLevel(
            id: 7,
            title: "Льодовик",
            subtitle: "Транспорт та мобільність",
            description: "Водійські права, GA/Halbtax, велосипед та авто.",
            iconName: "car.fill",
            requiredProgress: 80,
            estimatedDays: "1-6 місяців",
            isPremiumOnly: false,
            relatedChecklistIds: ["driving-license", "transport"],
            relatedGuideCategories: ["transport"],
            tips: [
                "Український permit дійсний 12 місяців",
                "Halbtax — 50% знижка на транспорт за 185 CHF/рік",
                "Обмін прав без іспиту для деяких країн"
            ],
            premiumTips: [
                "🚗 Найдешевші автошколи по кантонах",
                "🎫 Коли GA вигідніше ніж Halbtax — калькулятор"
            ],
            tasks: [
                LevelTask(id: "7-1", title: "Оформити Halbtax карту", description: "50% знижка на весь транспорт", iconName: "ticket", type: .checklist, targetId: "transport", xpReward: 60, isPremiumOnly: false),
                LevelTask(id: "7-2", title: "Обміняти водійські права", description: "Або записатись в автошколу", iconName: "car", type: .checklist, targetId: "driving-license", xpReward: 80, isPremiumOnly: false),
                LevelTask(id: "7-3", title: "Вивчити транспортну систему", description: "SBB, ZVV, регіональні абонементи", iconName: "tram", type: .guideCategory, targetId: "transport", xpReward: 30, isPremiumOnly: false),
                LevelTask(id: "7-4", title: "Завантажити SBB Mobile", description: "Квитки, розклад, GA/Halbtax", iconName: "iphone", type: .action, targetId: "download-sbb", xpReward: 15, isPremiumOnly: false),
                LevelTask(id: "7-5", title: "Порахувати: GA чи Halbtax?", description: "Що вигідніше для вас", iconName: "equal.circle", type: .action, targetId: "calculate-ga", xpReward: 25, isPremiumOnly: true)
            ]
        ),
        
        // LEVEL 8: Гірський хребет
        RoadmapLevel(
            id: 8,
            title: "Гірський хребет",
            subtitle: "Сім'я та діти",
            description: "Школа, дитячий садок, сімейні виплати, возз'єднання.",
            iconName: "figure.2.and.child.holdinghands",
            requiredProgress: 80,
            estimatedDays: "2-6 місяців",
            isPremiumOnly: false,
            relatedChecklistIds: ["school-enrollment", "family-reunification"],
            relatedGuideCategories: ["education"],
            tips: [
                "Школа безкоштовна та обов'язкова з 4 років",
                "Kinderzulagen — сімейні виплати ~200-300 CHF/дитина",
                "Возз'єднання сім'ї — через міграційну службу"
            ],
            premiumTips: [
                "📚 Рейтинг шкіл по районах",
                "👨‍👩‍👧 Покроковий гід возз'єднання сім'ї"
            ],
            tasks: [
                LevelTask(id: "8-1", title: "Записати дитину в школу/садок", description: "Безкоштовна освіта з 4 років", iconName: "building.columns", type: .checklist, targetId: "school-enrollment", xpReward: 80, isPremiumOnly: false),
                LevelTask(id: "8-2", title: "Оформити Kinderzulagen", description: "200-300 CHF/місяць на дитину", iconName: "banknote", type: .action, targetId: "apply-kinderzulagen", xpReward: 60, isPremiumOnly: false),
                LevelTask(id: "8-3", title: "Вивчити освітню систему", description: "Kindergarten, Primarschule, Gymnasium", iconName: "graduationcap", type: .guideCategory, targetId: "education", xpReward: 35, isPremiumOnly: false),
                LevelTask(id: "8-4", title: "Подати на возз'єднання сім'ї", description: "Якщо родичі за кордоном", iconName: "person.2.badge.plus", type: .checklist, targetId: "family-reunification", xpReward: 100, isPremiumOnly: false),
                LevelTask(id: "8-5", title: "Знайти дитячі гуртки", description: "Спорт, музика, мови", iconName: "figure.run", type: .action, targetId: "find-activities", xpReward: 25, isPremiumOnly: true)
            ]
        ),
        
        // LEVEL 9: Передвершина
        RoadmapLevel(
            id: 9,
            title: "Передвершина",
            subtitle: "Громадянство та права",
            description: "Permit C, натуралізація, політичні права.",
            iconName: "person.badge.shield.checkmark.fill",
            requiredProgress: 80,
            estimatedDays: "5-10 років",
            isPremiumOnly: true,
            relatedChecklistIds: ["permit-c", "naturalization"],
            relatedGuideCategories: ["legal", "integration"],
            tips: [
                "Permit C — після 5-10 років (залежить від кантону)",
                "Натуралізація — мінімум 10 років проживання",
                "Знання мови та інтеграції — ключові критерії"
            ],
            premiumTips: [
                "📋 Чек-лист документів для Permit C",
                "🎯 Як прискорити процес натуралізації",
                "💡 Кантони з найшвидшим процесом"
            ],
            tasks: [
                LevelTask(id: "9-1", title: "Подати на Permit C", description: "Постійний дозвіл на проживання", iconName: "person.badge.key", type: .checklist, targetId: "permit-c", xpReward: 150, isPremiumOnly: true),
                LevelTask(id: "9-2", title: "Вивчити вимоги натуралізації", description: "Мова B1+, інтеграція, проживання", iconName: "doc.text.magnifyingglass", type: .guideCategory, targetId: "legal", xpReward: 50, isPremiumOnly: true),
                LevelTask(id: "9-3", title: "Скласти мовний іспит", description: "Сертифікат рівня B1 або вище", iconName: "checkmark.seal", type: .action, targetId: "language-exam", xpReward: 80, isPremiumOnly: true),
                LevelTask(id: "9-4", title: "Пройти курс громадянознавства", description: "Історія, політика, культура", iconName: "book.closed", type: .action, targetId: "civics-course", xpReward: 60, isPremiumOnly: true),
                LevelTask(id: "9-5", title: "Почати процес натуралізації", description: "Заявка в кантональну службу", iconName: "flag.checkered", type: .checklist, targetId: "naturalization", xpReward: 200, isPremiumOnly: true)
            ]
        ),
        
        // LEVEL 10: Вершина
        RoadmapLevel(
            id: 10,
            title: "Вершина",
            subtitle: "Повна інтеграція",
            description: "Ви — частина Швейцарії. Громадська активність, волонтерство, нетворкінг.",
            iconName: "star.fill",
            requiredProgress: 80,
            estimatedDays: "Постійно",
            isPremiumOnly: true,
            relatedChecklistIds: [],
            relatedGuideCategories: ["integration"],
            tips: [
                "Приєднуйтесь до місцевих клубів та асоціацій",
                "Волонтерство — найкращий спосіб інтеграції",
                "Діліться досвідом з новоприбулими"
            ],
            premiumTips: [
                "🤝 Нетворкінг події для українців",
                "🎯 Як стати ментором для новачків",
                "🏆 Ексклюзивна спільнота випускників Sweezy"
            ],
            tasks: [
                LevelTask(id: "10-1", title: "Приєднатись до місцевого клубу", description: "Verein — серце швейцарського життя", iconName: "person.3", type: .action, targetId: "join-verein", xpReward: 80, isPremiumOnly: true),
                LevelTask(id: "10-2", title: "Стати волонтером", description: "Допомагайте громаді та новачкам", iconName: "heart.fill", type: .action, targetId: "volunteer", xpReward: 100, isPremiumOnly: true),
                LevelTask(id: "10-3", title: "Взяти участь у голосуванні", description: "Реалізуйте свої політичні права", iconName: "checkmark.rectangle.stack", type: .action, targetId: "vote", xpReward: 50, isPremiumOnly: true),
                LevelTask(id: "10-4", title: "Стати ментором у Sweezy", description: "Допомагайте новоприбулим українцям", iconName: "person.badge.plus", type: .action, targetId: "become-mentor", xpReward: 150, isPremiumOnly: true),
                LevelTask(id: "10-5", title: "Поділитись своєю історією", description: "Надихніть інших своїм досвідом", iconName: "quote.bubble", type: .action, targetId: "share-story", xpReward: 100, isPremiumOnly: true)
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

