import SwiftUI
import AVFoundation
import Combine

// MARK: - Models
struct Headline: Identifiable, Codable {
    let id = UUID()
    let title: String
    let date: String
    let url: String?
    
    init(title: String, date: String, url: String? = nil) {
        self.title = title
        self.date = date
        self.url = url
    }
}

struct HeadlinesResponse: Codable {
    let headlines: [String]
    let strategy: String?
    let timestamp: String?
    let cached: Bool?
    let error: String?
    let nextRefresh: String?
}

struct PodcastGenerationRequest: Codable {
    let headlines: [String]
}

struct AudioGenerationRequest: Codable {
    let scripts: [String]
}

struct ScriptGenerationResponse: Codable {
    let script: String
    let scripts: [String]
    let stats: ScriptStats
}

struct ScriptStats: Codable {
    let storiesProcessed: Int
    let scriptLength: Int
    let estimatedDuration: Int
}

// MARK: - API Service
class APIService: ObservableObject {
    @Published var headlines: [Headline] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let baseURL = "https://ai-news-podcast.vercel.app" // Your deployed backend
    private var cancellables = Set<AnyCancellable>()
    
    func fetchHeadlines() {
        isLoading = true
        error = nil
        
        guard let url = URL(string: "\(baseURL)/api/headlines") else {
            error = "Invalid URL"
            isLoading = false
            return
        }
        
        URLSession.shared.dataTaskPublisher(for: url)
            .tryMap { data, response in
                // Handle HTTP errors
                if let httpResponse = response as? HTTPURLResponse {
                    print("🌐 [iOS] HTTP Status: \(httpResponse.statusCode)")
                    if httpResponse.statusCode == 500 {
                        // Try to parse error response
                        if let errorObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let errorMsg = errorObj["error"] as? String {
                            throw APIError.serverError("Backend error: \(errorMsg)")
                        } else {
                            throw APIError.serverError("Backend is currently experiencing issues. Please try again later.")
                        }
                    }
                }
                return data
            }
            .decode(type: HeadlinesResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        if let apiError = error as? APIError {
                            self?.error = apiError.localizedDescription
                        } else {
                            self?.error = "Network error: Please check your internet connection"
                        }
                        print("🔍 [iOS] API Error Details: \(error)")
                    }
                },
                receiveValue: { [weak self] response in
                    print("🎉 [iOS] Headlines received: \(response.headlines.count)")
                    
                    // Check if there's an API error in the response
                    if let apiError = response.error {
                        self?.error = "API Error: \(apiError)"
                        return
                    }
                    
                    // Convert headline strings to Headline objects
                    self?.headlines = response.headlines.map { headlineString in
                        // Parse format: "**Title** (Date)" or just "Title"
                        let cleanTitle = self?.extractTitleFromHeadline(headlineString) ?? headlineString
                        let date = self?.extractDateFromHeadline(headlineString) ?? "Recent"
                        return Headline(title: cleanTitle, date: date, url: nil)
                    }
                    
                    print("🔍 [iOS] Processed \(self?.headlines.count ?? 0) headlines")
                }
            )
            .store(in: &cancellables)
    }
    
    private func extractTitleFromHeadline(_ headline: String) -> String {
        // Extract title from format: "**Title** (Date)"
        if headline.hasPrefix("**") {
            let components = headline.components(separatedBy: "** (")
            if components.count >= 2 {
                return String(components[0].dropFirst(2)) // Remove "**"
            }
        }
        return headline
    }
    
    private func extractDateFromHeadline(_ headline: String) -> String {
        // Extract date from format: "**Title** (Date)"
        if let startIndex = headline.lastIndex(of: "("),
           let endIndex = headline.lastIndex(of: ")") {
            let dateString = String(headline[headline.index(after: startIndex)..<endIndex])
            return dateString
        }
        return "Recent"
    }
    

    
    func generateDetailedScript(selectedHeadlines: [String], completion: @escaping (Result<[String], Error>) -> Void) {
        print("🔗 [API] generateDetailedScript called with \(selectedHeadlines.count) headlines")
        print("🔗 [API] Headlines: \(selectedHeadlines)")
        
        guard let url = URL(string: "\(baseURL)/api/generate-detailed-script") else {
            print("❌ [API] Invalid URL for generate-detailed-script")
            completion(.failure(APIError.invalidURL))
            return
        }
        
        print("🔗 [API] Making request to: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = PodcastGenerationRequest(headlines: selectedHeadlines)
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ [API] generateDetailedScript network error: \(error)")
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🌐 [API] generateDetailedScript HTTP Status: \(httpResponse.statusCode)")
            }
            
            guard let data = data else {
                print("❌ [API] generateDetailedScript no data received")
                completion(.failure(APIError.noData))
                return
            }
            
            print("📦 [API] generateDetailedScript received \(data.count) bytes")
            
            do {
                // The API returns { script: string, scripts: [string], stats: object }
                let response = try JSONDecoder().decode(ScriptGenerationResponse.self, from: data)
                print("✅ [API] generateDetailedScript decoded \(response.scripts.count) scripts")
                completion(.success(response.scripts))
            } catch {
                print("❌ [API] generateDetailedScript decode error: \(error)")
                // Try to print raw response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📄 [API] Raw response: \(responseString)")
                }
                completion(.failure(error))
            }
        }.resume()
    }
    
    func generateAudio(scripts: [String], completion: @escaping (Result<Data, Error>) -> Void) {
        print("🎵 [API] generateAudio called with \(scripts.count) scripts")
        
        guard let url = URL(string: "\(baseURL)/api/generate-audio") else {
            print("❌ [API] Invalid URL for generate-audio")
            completion(.failure(APIError.invalidURL))
            return
        }
        
        print("🔗 [API] Making audio request to: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = AudioGenerationRequest(scripts: scripts)
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ [API] generateAudio network error: \(error)")
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🌐 [API] generateAudio HTTP Status: \(httpResponse.statusCode)")
            }
            
            guard let data = data else {
                print("❌ [API] generateAudio no data received")
                completion(.failure(APIError.noData))
                return
            }
            
            print("✅ [API] generateAudio received \(data.count) bytes of audio data")
            completion(.success(data))
        }.resume()
    }
}

enum APIError: Error, LocalizedError {
    case invalidURL
    case noData
    case invalidResponse
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .invalidResponse:
            return "Invalid response format"
        case .serverError(let message):
            return message
        }
    }
}

// MARK: - Audio Player Manager
class AudioPlayerManager: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var error: String?
    
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    
    func loadAudio(data: Data) {
        print("🎵 [AUDIO] Loading audio data: \(data.count) bytes")
        
        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.delegate = self
            
            let prepareResult = audioPlayer?.prepareToPlay() ?? false
            print("🎵 [AUDIO] Prepare to play result: \(prepareResult)")
            
            duration = audioPlayer?.duration ?? 0
            print("🎵 [AUDIO] Audio duration: \(duration) seconds")
            
            if let player = audioPlayer {
                print("🎵 [AUDIO] Audio format: \(player.format?.description ?? "Unknown")")
                print("🎵 [AUDIO] Audio channels: \(player.numberOfChannels)")
            }
            
            error = nil
            print("✅ [AUDIO] Audio loaded successfully")
        } catch {
            print("❌ [AUDIO] Failed to load audio: \(error)")
            self.error = "Failed to load audio: \(error.localizedDescription)"
        }
    }
    
    func play() {
        guard let player = audioPlayer else { return }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            player.play()
            isPlaying = true
            startTimer()
        } catch {
            self.error = "Failed to play audio: \(error.localizedDescription)"
        }
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopTimer()
    }
    
    func stop() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        isPlaying = false
        currentTime = 0
        stopTimer()
    }
    
    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.currentTime = self.audioPlayer?.currentTime ?? 0
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - AVAudioPlayerDelegate
extension AudioPlayerManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.currentTime = 0
            self.stopTimer()
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                self.error = "Audio decode error: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @StateObject private var apiService = APIService()
    @StateObject private var audioPlayer = AudioPlayerManager()
    @State private var selectedHeadlineIndices: Set<Int> = []
    @State private var isGenerating = false
    @State private var generationStep = ""
    @State private var audioData: Data?
    @State private var showingPlayer = false
    
    var selectedHeadlines: [String] {
        selectedHeadlineIndices.compactMap { index in
            guard index < apiService.headlines.count else { return nil }
            // Return the original headline string format that the API expects
            let headline = apiService.headlines[index]
            return "**\(headline.title)** (\(headline.date))"
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if showingPlayer && audioData != nil {
                    // Audio Player View
                    AudioPlayerView(
                        audioPlayer: audioPlayer,
                        selectedCount: selectedHeadlines.count,
                        onBack: {
                            showingPlayer = false
                            audioData = nil
                            audioPlayer.stop()
                        }
                    )
                } else {
                    // Main Headlines View
                    VStack(spacing: 0) {
                        // Header
                        HeaderView()
                        
                        // Content
                        if apiService.isLoading {
                            LoadingView()
                        } else if let error = apiService.error {
                            ErrorView(error: error) {
                                apiService.fetchHeadlines()
                            }
                        } else if isGenerating {
                            GeneratingView(step: generationStep)
                        } else {
                            HeadlineListView(
                                headlines: apiService.headlines,
                                selectedIndices: $selectedHeadlineIndices
                            )
                        }
                        
                        Spacer()
                    }
                    
                    // Fixed Bottom Button
                    VStack {
                        Spacer()
                        BottomActionBar(
                            isEnabled: !selectedHeadlineIndices.isEmpty && !isGenerating,
                            isGenerating: isGenerating,
                            action: generatePodcast
                        )
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            apiService.fetchHeadlines()
        }
        .onReceive(audioPlayer.$error) { error in
            if let error = error {
                // Handle audio player errors
                print("Audio player error: \(error)")
            }
        }
    }
    
    private func generatePodcast() {
        print("🎙️ [iOS] Generate podcast button pressed")
        print("🎙️ [iOS] Selected headlines count: \(selectedHeadlines.count)")
        print("🎙️ [iOS] Selected headlines: \(selectedHeadlines)")
        
        guard !selectedHeadlines.isEmpty else { 
            print("❌ [iOS] No headlines selected, returning")
            return 
        }
        
        print("🎙️ [iOS] Starting podcast generation...")
        isGenerating = true
        generationStep = "Researching selected stories..."
        
        // Step 1: Generate detailed scripts
        print("🎙️ [iOS] Calling generateDetailedScript API...")
        apiService.generateDetailedScript(selectedHeadlines: selectedHeadlines) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let scripts):
                    print("✅ [iOS] Scripts generated successfully: \(scripts.count) scripts")
                    self.generationStep = "Generating audio..."
                    
                    // Step 2: Generate audio from scripts
                    print("🎵 [iOS] Calling generateAudio API...")
                    self.apiService.generateAudio(scripts: scripts) { audioResult in
                        DispatchQueue.main.async {
                            switch audioResult {
                            case .success(let data):
                                print("✅ [iOS] Audio generated successfully: \(data.count) bytes")
                                self.audioData = data
                                self.audioPlayer.loadAudio(data: data)
                                self.isGenerating = false
                                self.showingPlayer = true
                            case .failure(let error):
                                print("❌ [iOS] Audio generation failed: \(error)")
                                self.generationStep = "Error: \(error.localizedDescription)"
                                self.isGenerating = false
                            }
                        }
                    }
                case .failure(let error):
                    print("❌ [iOS] Script generation failed: \(error)")
                    self.generationStep = "Error: \(error.localizedDescription)"
                    self.isGenerating = false
                }
            }
        }
    }
}

// MARK: - Header View
struct HeaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("The latest AI news, by AI")
                .font(.largeTitle)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("curate, generate, listen")
                .font(.title3)
                .foregroundColor(Color.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 30)
    }
}

// MARK: - Loading View
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.2)
            
            Text("Loading latest AI news...")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Searching multiple sources for the most recent stories")
                .font(.subheadline)
                .foregroundColor(Color.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Error View
struct ErrorView: View {
    let error: String
    let retry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            Text("Unable to Load Headlines")
                .font(.headline)
                .foregroundColor(.white)
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(Color.white.opacity(0.6))
                .multilineTextAlignment(.center)
            
            Button(action: retry) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.white)
                .cornerRadius(20)
            }
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Generating View
struct GeneratingView: View {
    let step: String
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            
            Text("Generating Your Podcast")
                .font(.headline)
                .foregroundColor(.white)
            
            Text(step)
                .font(.subheadline)
                .foregroundColor(Color.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Headline List View
struct HeadlineListView: View {
    let headlines: [Headline]
    @Binding var selectedIndices: Set<Int>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header
            HStack {
                Text("TODAY'S HEADLINES")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(Color.white.opacity(0.5))
                    .textCase(.uppercase)
                
                Spacer()
                
                Text("\(headlines.count) stories")
                    .font(.caption)
                    .foregroundColor(Color.white.opacity(0.4))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            
            // Headlines List
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(headlines.enumerated()), id: \.offset) { index, headline in
                        HeadlineRow(
                            headline: headline,
                            isSelected: selectedIndices.contains(index),
                            onTap: {
                                if selectedIndices.contains(index) {
                                    selectedIndices.remove(index)
                                } else {
                                    selectedIndices.insert(index)
                                }
                            }
                        )
                        .animation(.easeInOut(duration: 0.2), value: selectedIndices.contains(index))
                    }
                }
            }
        }
    }
}

// MARK: - Headline Row
struct HeadlineRow: View {
    let headline: Headline
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: isSelected ? 20 : 0) {
                // Selection indicator
                Circle()
                    .fill(Color.white)
                    .frame(width: 4, height: 4)
                    .opacity(isSelected ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(headline.title)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(isSelected ? .white : Color.white.opacity(0.9))
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                    
                    Text(headline.date)
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.5))
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Bottom Action Bar
struct BottomActionBar: View {
    let isEnabled: Bool
    let isGenerating: Bool
    let action: () -> Void
    
    var body: some View {
        VStack {
            Button(action: action) {
                Text(isGenerating ? "Generating..." : "Generate Podcast")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isEnabled ? .black : .gray)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(isEnabled ? Color.white : Color.white.opacity(0.2))
                    )
            }
            .disabled(!isEnabled)
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .background(
            Color.black.opacity(0.9)
                .blur(radius: 20)
                .edgesIgnoringSafeArea(.all)
        )
    }
}

// MARK: - Audio Player View
struct AudioPlayerView: View {
    @ObservedObject var audioPlayer: AudioPlayerManager
    let selectedCount: Int
    let onBack: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            // Header
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                Spacer()
                Text("AI News Podcast")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                // Spacer to center the title
                Color.clear.frame(width: 24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            Spacer()
            
            // Podcast Info
            VStack(spacing: 12) {
                Text("Your AI News Podcast")
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("\(selectedCount) stories • Generated with AI")
                    .font(.subheadline)
                    .foregroundColor(Color.white.opacity(0.6))
            }
            
            // Progress Bar
            VStack(spacing: 8) {
                Slider(
                    value: Binding(
                        get: { audioPlayer.currentTime },
                        set: { audioPlayer.seek(to: $0) }
                    ),
                    in: 0...max(audioPlayer.duration, 1)
                )
                .accentColor(.white)
                
                HStack {
                    Text(timeString(from: audioPlayer.currentTime))
                        .font(.caption)
                        .foregroundColor(Color.white.opacity(0.6))
                    
                    Spacer()
                    
                    Text(timeString(from: audioPlayer.duration))
                        .font(.caption)
                        .foregroundColor(Color.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 20)
            
            // Playback Controls
            HStack(spacing: 40) {
                Button(action: {
                    audioPlayer.seek(to: max(0, audioPlayer.currentTime - 15))
                }) {
                    Image(systemName: "gobackward.15")
                        .font(.title)
                        .foregroundColor(.white)
                }
                
                Button(action: {
                    if audioPlayer.isPlaying {
                        audioPlayer.pause()
                    } else {
                        audioPlayer.play()
                    }
                }) {
                    Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }
                
                Button(action: {
                    audioPlayer.seek(to: min(audioPlayer.duration, audioPlayer.currentTime + 30))
                }) {
                    Image(systemName: "goforward.30")
                        .font(.title)
                        .foregroundColor(.white)
                }
            }
            
            Spacer()
        }
        .background(Color.black)
        .onAppear {
            // Auto-play when the view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                audioPlayer.play()
            }
        }
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
} 