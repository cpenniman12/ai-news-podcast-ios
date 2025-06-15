# 📱 AI News Podcast - iOS App

## 🎯 **Overview**
This is a native iOS app that brings the AI News Podcast experience to your iPhone. The app connects to your existing Next.js backend to fetch headlines, generate podcast scripts, and create audio content.

## 🚀 **Quick Start**

### **Open in Xcode**
1. **Open the project**: Double-click `SimpleTestApp.xcodeproj` to open in Xcode
2. **Select target**: Choose your iPhone simulator or connected device
3. **Run**: Press `Cmd+R` or click the Play button

### **First Run Experience**
- App launches with a black background (matching your web design)
- Displays "Loading latest AI news..." while fetching headlines
- Shows curated headlines from your backend API
- Tap headlines to select them (white dots appear)
- "Generate Podcast" button enables when headlines are selected

## 🔧 **Technical Architecture**

### **Backend Integration**
The app connects to your deployed Next.js backend at `https://ai-news-podcast.vercel.app`:

```
GET /api/headlines - Fetches curated AI news headlines
POST /api/generate-detailed-script - Generates podcast scripts 
POST /api/generate-audio - Creates TTS audio files
```

### **Key Features**
- **Real API Integration**: Fetches live headlines from your backend
- **Native Audio Playback**: Uses AVAudioPlayer for professional audio experience
- **Background Audio**: Supports background playback and lock screen controls
- **Network Resilience**: Handles API failures gracefully with retry options
- **iOS Compatibility**: Works on iOS 14.0+ with broad device support

## 📱 **User Experience**

### **Main Screen**
```
┌─────────────────────────────────┐
│ The latest AI news, by AI       │
│ curate, generate, listen        │
├─────────────────────────────────┤
│ TODAY'S HEADLINES               │
│                                 │
│ ● Selected headline with dot    │
│ □ Unselected headline           │
│ ● Another selected headline     │
│                                 │
├─────────────────────────────────┤
│     [Generate Podcast]          │
└─────────────────────────────────┘
```

### **Audio Player Screen**
```
┌─────────────────────────────────┐
│ ← AI News Podcast               │
│                                 │
│                                 │
│    Your AI News Podcast         │
│  3 stories • Generated with AI  │
│                                 │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│ 1:23                      5:47  │
│                                 │
│     ⏪    ▶️    ⏩              │
│    -15s       +30s             │
│                                 │
└─────────────────────────────────┘
```

## 🎛️ **Controls & Gestures**

### **Headline Selection**
- **Tap**: Select/deselect headlines
- **Visual Feedback**: White dots appear for selected items
- **Multi-select**: Choose 1-6 headlines for your podcast

### **Audio Player**
- **Play/Pause**: Central button toggles playback
- **Scrubbing**: Drag progress bar to seek
- **Skip**: -15s and +30s buttons for quick navigation
- **Back**: Return to headline selection

## 🔧 **Technical Details**

### **iOS Compatibility**
- **Minimum iOS Version**: 14.0
- **Device Support**: iPhone (Portrait orientation)
- **Audio**: Background playback enabled
- **Network**: HTTPS connections to your backend

### **SwiftUI Implementation**
The app uses modern SwiftUI with backward-compatible syntax:
```swift
// Compatible with older Xcode versions
Color.white.opacity(0.6)  // Not .white.opacity(0.6)
VStack                    // Not LazyVStack
.edgesIgnoringSafeArea(.all)  // Not .ignoresSafeArea()
```

### **API Service Architecture**
```swift
APIService: Handles all backend communication
├── fetchHeadlines(): Gets curated news
├── generateDetailedScript(): Creates podcast scripts
└── generateAudio(): Produces final audio file

AudioPlayerManager: Native iOS audio playback
├── AVAudioPlayer integration
├── Background audio support
└── Lock screen controls
```

## 🛠️ **Development**

### **Project Structure**
```
SimpleTestApp/
├── SimpleTestAppApp.swift     # App entry point
├── ContentView.swift          # Main UI implementation
└── Info.plist                # App configuration
```

### **Key Components**
- **ContentView**: Main app logic and UI
- **APIService**: Backend communication
- **AudioPlayerManager**: Audio playback
- **HeaderView**: App title and tagline
- **HeadlineListView**: Scrollable news list
- **AudioPlayerView**: Full-screen audio player

## 🎨 **Design System**

### **Colors**
- **Background**: Pure black (`#000000`)
- **Primary Text**: White (`rgba(255, 255, 255, 0.9)`)
- **Secondary Text**: White with opacity (`rgba(255, 255, 255, 0.6)`)
- **Accent**: White dots for selection

### **Typography**
- **Headlines**: System font, 17pt, medium weight
- **Titles**: Large title, semibold
- **Captions**: Small caps, 12pt, tracking

## 🔍 **Testing**

### **Testing Steps**
1. **Launch**: App opens to loading screen
2. **Headlines**: Verify headlines load from backend
3. **Selection**: Tap headlines to select/deselect
4. **Generation**: Tap "Generate Podcast" button
5. **Audio**: Verify audio plays with controls

### **Expected Behavior**
- Headlines load within 5-10 seconds
- Selection indicators appear immediately
- Podcast generation takes 30-60 seconds
- Audio playback starts automatically
- All controls respond smoothly

## 🚨 **Troubleshooting**

### **Common Issues**
1. **Headlines not loading**: Check internet connection
2. **Audio generation fails**: Backend may be busy, try again
3. **Audio doesn't play**: Check device volume and mute switch
4. **App crashes**: Restart and try with fewer headlines

### **Debug Information**
The app logs detailed information to Xcode console:
```
🔍 [API] Fetching headlines from backend...
✅ [API] Headlines loaded: 20 stories
🎙️ [AUDIO] Generating podcast with 3 stories...
✅ [AUDIO] Playback started successfully
```

## 📦 **Deployment**

### **App Store Preparation**
1. **Bundle ID**: Set unique identifier
2. **App Icons**: Add required icon sizes
3. **Launch Screen**: Configure startup screen
4. **Privacy Settings**: Add usage descriptions

### **TestFlight Distribution**
1. Archive the app in Xcode
2. Upload to App Store Connect
3. Add external testers
4. Distribute for testing

## 🎉 **Success Criteria**

### **Core Functionality**
- ✅ App launches without crashes
- ✅ Headlines load from backend API
- ✅ Selection mechanism works perfectly
- ✅ Podcast generation completes successfully
- ✅ Audio plays with native iOS controls
- ✅ UI matches web app design

### **User Experience**
- ✅ Smooth animations and transitions
- ✅ Responsive touch interactions
- ✅ Professional audio playback
- ✅ Intuitive navigation
- ✅ Error handling and recovery

---

**Ready to use!** 🚀 Open `SimpleTestApp.xcodeproj` in Xcode and start exploring your AI News Podcast iOS app! 