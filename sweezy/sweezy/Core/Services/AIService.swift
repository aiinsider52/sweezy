//
//  AIService.swift
//  sweezy
//
//  Lightweight OpenAI integration for CV improvement and translation.
//  Premium feature only.
//

import Foundation

actor AIService {
    static let shared = AIService()
    
    private let apiKey: String? = {
        // Try to get from environment or UserDefaults
        if let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !key.isEmpty {
            return key
        }
        if let key = UserDefaults.standard.string(forKey: "openai_api_key"), !key.isEmpty {
            return key
        }
        // Fallback: hardcoded for dev (should be replaced with secure storage in production)
        return nil
    }()
    
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    enum AIError: Error {
        case noAPIKey
        case networkError(Error)
        case invalidResponse
        case rateLimited
    }
    
    // MARK: - Improve CV Text
    func improveCVText(_ text: String, section: String) async throws -> String {
        guard let apiKey = apiKey else {
            throw AIError.noAPIKey
        }
        
        let prompt = """
        You are a professional CV writer specializing in Swiss job market standards.
        Improve the following \(section) section of a CV. Make it:
        - More professional and concise
        - Use action verbs and quantifiable achievements
        - Follow Swiss CV standards
        - Keep the same language as the input
        
        Original text:
        \(text)
        
        Return ONLY the improved text, no explanations.
        """
        
        return try await callOpenAI(prompt: prompt)
    }
    
    // MARK: - Translate to German
    func translateToGerman(_ text: String) async throws -> String {
        guard let apiKey = apiKey else {
            throw AIError.noAPIKey
        }
        
        let prompt = """
        Translate the following CV text to German (Swiss German style, formal).
        Keep the same structure and formatting.
        Use professional business German appropriate for Swiss job applications.
        
        Text to translate:
        \(text)
        
        Return ONLY the translated text, no explanations.
        """
        
        return try await callOpenAI(prompt: prompt)
    }
    
    // MARK: - Generate Summary from Experience
    func generateSummary(name: String, title: String, experience: String, skills: String) async throws -> String {
        guard let apiKey = apiKey else {
            throw AIError.noAPIKey
        }
        
        let prompt = """
        Write a professional CV summary (2-3 sentences) for a job seeker in Switzerland.
        
        Name: \(name)
        Desired position: \(title)
        Experience: \(experience)
        Skills: \(skills)
        
        Make it professional, concise, and highlight key strengths.
        Write in the same language as the experience text.
        Return ONLY the summary text.
        """
        
        return try await callOpenAI(prompt: prompt)
    }
    
    // MARK: - Private API Call
    private func callOpenAI(prompt: String) async throws -> String {
        guard let apiKey = apiKey else {
            throw AIError.noAPIKey
        }
        
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        let body: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 500,
            "temperature": 0.7
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIError.invalidResponse
            }
            
            if httpResponse.statusCode == 429 {
                throw AIError.rateLimited
            }
            
            guard httpResponse.statusCode == 200 else {
                throw AIError.invalidResponse
            }
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let content = message["content"] as? String {
                return content.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            throw AIError.invalidResponse
        } catch let error as AIError {
            throw error
        } catch {
            throw AIError.networkError(error)
        }
    }
}

