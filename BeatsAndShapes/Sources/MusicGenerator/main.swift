import Foundation

struct ElevenLabsMusicRequest: Encodable {
    let text: String
}

@main
struct MusicGenerator {
    static func main() async {
        let args = CommandLine.arguments
        guard args.count >= 4 else {
            print("Usage: swift run MusicGenerator <API_KEY> <PROMPT> <FILENAME>")
            return
        }
        
        let apiKey = args[1]
        let prompt = args[2]
        let filename = args[3]
        
        let url = URL(string: "https://api.elevenlabs.io/v1/text-to-music")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ElevenLabsMusicRequest(text: prompt)
        request.httpBody = try? JSONEncoder().encode(body)
        
        print("🎵 Requesting music generation from ElevenLabs: '\(prompt)'...")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                return
            }
            
            if httpResponse.statusCode == 200 {
                let outputURL = URL(fileURLWithPath: "\(filename).mp3")
                try data.write(to: outputURL)
                print("✅ Success! Music saved to \(filename).mp3")
            } else {
                print("❌ Error: \(httpResponse.statusCode)")
                if let errorString = String(data: data, encoding: .utf8) {
                    print(errorString)
                }
            }
        } catch {
            print("❌ Request failed: \(error)")
        }
    }
}
