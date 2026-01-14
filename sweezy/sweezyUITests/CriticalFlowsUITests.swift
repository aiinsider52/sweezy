//
//  CriticalFlowsUITests.swift
//  sweezyUITests
//
//  UI‑тести ключових сценаріїв: реєстрація → логін → читання гіда.
//

import XCTest

final class CriticalFlowsUITests: XCTestCase {

    private func launchApp(resetOnboarding: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        if resetOnboarding {
            app.launchArguments.append("--reset-onboarding")
        }
        app.launchEnvironment["UITESTS"] = "1"
        app.launch()
        return app
    }

    private func skipOnboardingIfNeeded(_ app: XCUIApplication) {
        let skipButton = app.buttons["onboarding.skipButton"]
        if skipButton.waitForExistence(timeout: 5) {
            skipButton.tap()
            return
        }
        let getStarted = app.buttons["onboarding.getStartedButton"]
        if getStarted.waitForExistence(timeout: 5) {
            getStarted.tap()
        }
    }

    // MARK: - Registration → Guides → Logout → Login

    func testRegistrationLoginAndReadGuide() {
        let app = launchApp()
        skipOnboardingIfNeeded(app)

        // На экране регистрации
        let nameField = app.textFields["Повне ім'я"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 10), "Поле имени должно быть видно на экране регистрации")
        nameField.tap()
        nameField.typeText("UITest User")

        let emailField = app.textFields["Електронна пошта"]
        XCTAssertTrue(emailField.exists)
        let email = "uitest+\(UUID().uuidString.prefix(8))@example.com"
        emailField.tap()
        emailField.typeText(email)

        let passwordField = app.secureTextFields["Пароль"]
        XCTAssertTrue(passwordField.exists)
        passwordField.tap()
        passwordField.typeText("StrongPass1!")

        let registerButton = app.buttons["Зареєструватись"]
        XCTAssertTrue(registerButton.exists)
        registerButton.tap()

        // Ожидаем появления главного таба Home
        let homeTab = app.buttons["Home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 15), "После регистрации должен открыться главный экран")

        // Переход в Довідник и открытие первого гида
        let guidesTab = app.buttons["Довідник"]
        XCTAssertTrue(guidesTab.exists)
        guidesTab.tap()

        // Ищем любую ячейку списка гайдов
        let firstGuideCell = app.scrollViews.firstMatch.descendants(matching: .button).firstMatch
        XCTAssertTrue(firstGuideCell.waitForExistence(timeout: 10), "Должен существовать хотя бы один гайд")
        firstGuideCell.tap()

        // Проверяем, что контент гайда отобразился (есть scrollView или текст)
        XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: 5), "Экран гайда должен содержать scrollView")

        // Возвращаемся назад
        if app.navigationBars.buttons.element(boundBy: 0).waitForExistence(timeout: 5) {
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }

        // Логаут через настройки
        let settingsTab = app.buttons["Налаштування"]
        XCTAssertTrue(settingsTab.exists)
        settingsTab.tap()

        let logoutButton = app.buttons["Вийти"]
        XCTAssertTrue(logoutButton.waitForExistence(timeout: 5))
        logoutButton.tap()

        // Перезапуск приложения → логин существующим пользователем
        app.terminate()
        let app2 = launchApp(resetOnboarding: false)
        skipOnboardingIfNeeded(app2)

        // Экран регистрации, нажимаем "Уже есть аккаунт? Войти"
        let alreadyHaveAccountButton = app2.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", "Уже есть аккаунт")).firstMatch
        XCTAssertTrue(alreadyHaveAccountButton.waitForExistence(timeout: 8))
        alreadyHaveAccountButton.tap()

        let loginEmailField = app2.textFields.element(boundBy: 0)
        XCTAssertTrue(loginEmailField.waitForExistence(timeout: 8))
        loginEmailField.tap()
        loginEmailField.typeText(email)

        let loginPasswordField = app2.secureTextFields.element(boundBy: 0)
        XCTAssertTrue(loginPasswordField.exists)
        loginPasswordField.tap()
        loginPasswordField.typeText("StrongPass1!")

        let loginButton = app2.buttons["Увійти"]
        XCTAssertTrue(loginButton.exists)
        loginButton.tap()

        // Убедимся, что снова на главном экране
        XCTAssertTrue(app2.buttons["Home"].waitForExistence(timeout: 15))
    }
}


