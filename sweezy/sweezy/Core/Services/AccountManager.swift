//
//  AccountManager.swift
//  sweezy
//
//  Lightweight local registration state
//

import SwiftUI

final class AccountManager: ObservableObject {
    @AppStorage("userName") var userName: String = ""
    @AppStorage("userEmail") var userEmail: String = ""
    @AppStorage("userPassword") var userPassword: String = "" // local only
    @AppStorage("isRegistered") var isRegistered: Bool = false {
        didSet { objectWillChange.send() }
    }
    
    func register(name: String, email: String, password: String) {
        userName = name
        userEmail = email
        userPassword = password
        withAnimation(.easeInOut(duration: 0.4)) {
            isRegistered = true
        }
    }
    
    func logout() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isRegistered = false
        }
        userName = ""
        userEmail = ""
        userPassword = ""
    }
}


