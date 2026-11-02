import Foundation

enum GeminiError: LocalizedError {
    case http(Int, String)
    case blocked(String)
    case truncated
    case empty
    case badModel

    var errorDescription: String? {
        switch self {
        case .http(404, let message): return "Model not available for this key. Open Settings > Translate and press Check key to pick one. \(message)"
        case .http(400, let message) where message.contains("API key"): return "The API key is not valid."
        case .http(401, _), .http(403, _): return "Gemini rejected the API key. Check it in Settings > Translate."
        case .http(429, let message): return "Gemini rate limit or quota reached. \(message)"
        case .http(let code, let message): return "Gemini error \(code): \(message)"
        case .blocked(let reason): return "Gemini refused this text (\(reason))."
        case .truncated: return "The translation was cut off. Try a shorter file."
        case .empty: return "Gemini returned no text."
        case .badModel: return "The model name has characters that are not allowed."
        }
    }
}

// Google's Generative Language REST API; the key goes in a header, never in the URL
struct GeminiClient: Sendable {
    // Google retires versioned models every few months; the -latest alias follows the current one
    static let defaultModel = "gemini-flash-latest"
    private static let base = "https://generativelanguage.googleapis.com/v1beta/"

    let apiKey: String
    let model: String

    private var modelPath: String? {
        let name = model.hasPrefix("models/") ? String(model.dropFirst(7)) : model
        return name.range(of: #"^[A-Za-z0-9._-]+$"#, options: .regularExpression) == nil ? nil : "models/" + name
    }

    func translateRequest(system: String, text: String) -> URLRequest? {
        guard let path = modelPath, let url = URL(string: Self.base + path + ":generateContent") else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 120)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "systemInstruction": ["parts": [["text": system]]],
            "contents": [["role": "user", "parts": [["text": text]]]],
            "generationConfig": ["temperature": 0.2],
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }

    func translate(_ text: String, to language: String, onRetry: (@Sendable () -> Void)? = nil) async throws -> String {
        let system = """
        You are a professional translator. Translate the user's text into \(language). Keep the exact formatting: Markdown \
        syntax, line breaks, blank lines, lists and tables. Do not translate code blocks, inline code, URLs, file paths or \
        placeholders such as {name}, %s or {{x}}. Output only the translation, with no comments or explanations.
        """
        guard let request = translateRequest(system: system, text: text) else { throw GeminiError.badModel }
        // free-tier keys hit 429 often; a short wait usually clears it
        for attempt in 0..<3 {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 200 { return try Self.parse(data) }
            if status == 429 || status >= 500, attempt < 2 {
                onRetry?()
                try await Task.sleep(nanoseconds: UInt64(2 << attempt) * 1_000_000_000)
                continue
            }
            throw GeminiError.http(status, Self.errorMessage(in: data))
        }
        throw GeminiError.empty
    }

    // every model this key can see; also proves the key works
    func listModels() async throws -> [String] {
        var names: [String] = []
        var token = ""
        for _ in 0..<5 {
            guard let url = URL(string: Self.base + "models?pageSize=1000" + token) else { throw GeminiError.badModel }
            var request = URLRequest(url: url, timeoutInterval: 30)
            request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200 else { throw GeminiError.http(status, Self.errorMessage(in: data)) }
            let page = Self.parseModels(data)
            names += page.names
            guard let next = page.next else { break }
            token = "&pageToken=" + (next.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
        }
        return names
    }

    // names (without "models/") of the models that can generate text
    static func parseModels(_ data: Data) -> (names: [String], next: String?) {
        let root = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        let names = (root["models"] as? [[String: Any]] ?? []).compactMap { model -> String? in
            guard let name = model["name"] as? String,
                  (model["supportedGenerationMethods"] as? [String])?.contains("generateContent") == true else { return nil }
            return name.hasPrefix("models/") ? String(name.dropFirst(7)) : name
        }
        return (names, (root["nextPageToken"] as? String).flatMap { $0.isEmpty ? nil : $0 })
    }

    private static let notForText = ["image", "tts", "live", "audio", "embedding", "robotics", "computer", "imagen", "veo", "learnlm"]

    // gemini models fit for translating text, newest first
    static func textModels(_ names: [String]) -> [String] {
        names.filter { $0.hasPrefix("gemini-") && !notForText.contains(where: $0.contains) }
            .sorted { version($0) != version($1) ? version($0) > version($1) : $0 < $1 }
    }

    // the model to fall back on: the -latest alias if Google lists it, else the newest plain flash
    static func pickDefault(_ names: [String]) -> String? {
        let texts = textModels(names)
        if texts.contains(defaultModel) { return defaultModel }
        let flash = texts.filter { $0.range(of: #"^gemini-\d+(\.\d+)?-flash(-preview.*)?$"#, options: .regularExpression) != nil }
        // a stable release beats a preview of the same version
        return flash.first { !$0.contains("preview") && version($0) == version(flash[0]) } ?? flash.first
    }

    private static func version(_ name: String) -> Double {
        guard let range = name.range(of: #"\d+(\.\d+)?"#, options: .regularExpression) else { return 0 }
        return Double(name[range]) ?? 0
    }

    static func parse(_ data: Data) throws -> String {
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        if let reason = (root["promptFeedback"] as? [String: Any])?["blockReason"] as? String { throw GeminiError.blocked(reason) }
        guard let candidate = (root["candidates"] as? [[String: Any]])?.first else { throw GeminiError.empty }
        let finish = candidate["finishReason"] as? String
        if finish == "MAX_TOKENS" { throw GeminiError.truncated }
        let parts = (candidate["content"] as? [String: Any])?["parts"] as? [[String: Any]] ?? []
        let text = parts.compactMap { $0["text"] as? String }.joined()
        if text.isEmpty { throw finish.map { GeminiError.blocked($0) } ?? GeminiError.empty }
        return text
    }

    static func errorMessage(in data: Data) -> String {
        let error = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? [String: Any]
        return String((error?["message"] as? String ?? "").prefix(200))
    }
}
