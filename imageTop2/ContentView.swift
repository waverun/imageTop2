import SwiftUI
import UniformTypeIdentifiers
import AppKit
import GameplayKit
import HotKey

//var gShowWatch = true

private func calculateWatchPosition(parentSize: CGSize) -> (CGFloat, CGFloat) {
    var seed = UInt64(Date().timeIntervalSince1970)
    let seedData = Data(bytes: &seed, count: MemoryLayout<UInt64>.size)
    let generator = GKARC4RandomSource(seed: seedData)

    let x = CGFloat(generator.nextUniform()) * (parentSize.width * 0.8 - parentSize.width * 0.2) + parentSize.width * 0.2
    let y = CGFloat(generator.nextUniform()) * (parentSize.height * 0.8 - parentSize.height * 0.2) + parentSize.height * 0.2

    return (x, y)
}

struct ContentView: View {
    var index: Int

//    @State private var shouldDisplayWatch: Bool = false

    @State var eventMonitor: Any?

    @EnvironmentObject var appDelegate: AppDelegate
//    @EnvironmentObject var appDelegate: CustomAppDelegate


//    @NSApplicationDelegateAdaptor(CustomAppDelegate.self) var appDelegate

    @State private var hotkey: HotKey? = HotKey(key: .escape, modifiers: [.control, .command])

    @State private var testText: String = ""

    @AppStorage("replaceImageAfter") private var replaceImageAfter: TimeInterval = 10
    @AppStorage("selectedFolderPath") private var selectedFolderPath: String = ""
    @AppStorage("imageTopFolderBookmark") private var imageTopFolderBookmarkData: Data?
    @AppStorage("hotKeyString") private var hotKeyString: String = "escape"
    @AppStorage("modifierKeyString1") private var keyString1: String = "command"
    @AppStorage("modifierKeyString2") private var keyString2: String = "control"

    @State private var imageName: String?
    @State private var timer: Timer? = nil
    @State private var imageNames: [String] = []
    @State private var imageOrBackgroundChangeTimer: Timer? = nil
    @State private var backgroundColor: Color = Color.clear
    @State private var imageMode = false
    @State private var fadeColor: Color = Color.clear
    @State private var showFadeColor: Bool = false
    @State private var secondImageName: String?
    @State private var showSecondImage: Bool = false
    @State private var x: CGFloat = {
        if let screenSize = NSScreen.main?.frame.size {
            return calculateWatchPosition(parentSize: screenSize).0
        }
        return 0
    }()

    @State private var y: CGFloat = {
        if let screenSize = NSScreen.main?.frame.size {
            return calculateWatchPosition(parentSize: screenSize).1
        }
        return 0
    }()


    init(index: Int) {
        if let screenSize = NSScreen.main?.frame.size {
            let (xValue, yValue) = calculateWatchPosition(parentSize: screenSize)
            _x = State(initialValue: xValue)
            _y = State(initialValue: yValue)
            debugPrint("_x, -Y (\(_x), \(_y)")
        }
        self.index = index
    }

//    private func startMonitoring() {
//        debugPrint("startMonitoring")
//        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .mouseMoved]) { event in
//            debugPrint("in startMonitoring")
//            self.hideApp()
//            return event
//        }
//    }

    private func startMonitoring() {
        if index > 0 {
            return
        }

        debugPrint("startMonitoring")

        if eventMonitor != nil {
            stopMonitoring()
        }

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .mouseMoved]) { event in
            debugPrint("in startMonitoring showWindow: \(appDelegate.$showWindow)")
//            self.hideApp()
            appDelegate.showWindow = false
            return event
        }
    }


    private func stopMonitoring() {
        if let monitor = eventMonitor {
            debugPrint("stopMonitoring")
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func startAccessingFolder() {
        if let bookmarkData = imageTopFolderBookmarkData {
            do {
                var isStale = false
                let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
                if isStale {
                    debugPrint("Bookmark data is stale")
                } else {
                    if url.startAccessingSecurityScopedResource() {
                        debugPrint("Successfully accessed security-scoped resource")
                        loadImageNames()
                    } else {
                        debugPrint("Error accessing security-scoped resource")
                    }
                }
            } catch {
                debugPrint("Error resolving security-scoped bookmark: \(error)")
            }
        }
    }

    private func updateHotKey() {
        if index > 0 {
            return
        }
        if let key = Key(string: hotKeyString) {
            var modifiers: NSEvent.ModifierFlags = []
            if let modifier = Keyboard.stringToModifier(keyString1) {
                modifiers.insert(modifier)
            }
            if let modifier = Keyboard.stringToModifier(keyString2) {
                modifiers.insert(modifier)
            }
            hotkey?.isPaused = true
            hotkey = HotKey(key: key, modifiers: modifiers)
            hotkey!.keyDownHandler = hotkeyPressed
        }
    }

    private func showApp() {
        startMonitoring()
//        WindowManager.shared.enterFullScreen()
        setupScreenChangeTimer()
    }

    private func hotkeyPressed() {
        debugPrint("hotkey pressed")
//        showApp()
        appDelegate.showWindow = true
        appDelegate.hideSettings()
        WindowManager.shared.enterFullScreen()
    }

    private func resetImageOrBackgroundChangeTimer() {
        imageOrBackgroundChangeTimer?.invalidate()
        imageOrBackgroundChangeTimer = nil
        setupScreenChangeTimer()
    }

    private func randomGentleColor() -> Color {
        let colors: [Color] = [
            Color(red: 0.96, green: 0.52, blue: 0.49),
            Color(red: 0.96, green: 0.81, blue: 0.48),
            Color(red: 0.53, green: 0.84, blue: 0.71),
            Color(red: 0.48, green: 0.57, blue: 0.87),
            Color(red: 0.74, green: 0.54, blue: 0.86),
            Color(red: 0.91, green: 0.46, blue: 0.85),
            Color(red: 0.98, green: 0.63, blue: 0.45),
            Color(red: 0.98, green: 0.84, blue: 0.45),
            Color(red: 0.84, green: 0.98, blue: 0.45),
            Color(red: 0.45, green: 0.98, blue: 0.83),
            Color(red: 0.45, green: 0.74, blue: 0.98),
            Color(red: 0.78, green: 0.45, blue: 0.98)
        ]
        return colors.randomElement() ?? Color.white
    }

    private func changeBackgroundColor() {
        imageName = nil
        secondImageName = nil

        var newColor: Color? = nil

        repeat {
            newColor = randomGentleColor()
        } while newColor == backgroundColor && !showFadeColor
        || newColor == fadeColor && showFadeColor

        if showFadeColor {
            backgroundColor = newColor!
        } else {
            fadeColor = newColor!
        }
        withAnimation(.linear(duration: 1)) {
            showFadeColor.toggle()
            debugPrint("backgroundColor: \(backgroundColor) fadeColor: \(fadeColor)")
        }
    }

    private func setupScreenChangeTimer() {
        if imageOrBackgroundChangeTimer != nil {
            debugPrint("invalidate existing timer")
            imageOrBackgroundChangeTimer?.invalidate()
            imageOrBackgroundChangeTimer = nil
        }

        debugPrint("setupScreenChangeTimer")
        imageOrBackgroundChangeTimer = Timer.scheduledTimer(withTimeInterval: replaceImageAfter, repeats: true) { [self] _ in
            changeScreenImageOrColor()
        }
    }

    private func changeScreenImageOrColor() {
        debugPrint("changeScreenImageOrColor")
        _ = imageMode ? loadRandomImage() : changeBackgroundColor()
    }

    private func loadRandomImage() {
        debugPrint("loadRandomImage \(index)")
        var newRandomImageName: String? = nil
        let imageFolder = selectedFolderPath
        var newRandomImagePath = ""
        repeat {
            newRandomImageName = imageNames.randomElement()
            newRandomImagePath = "\(imageFolder)/\(newRandomImageName!)"
        } while (newRandomImagePath == imageName && !showSecondImage)
        || (newRandomImagePath == secondImageName && showSecondImage)

        if let randomImageName = newRandomImageName {
                if showSecondImage {
                    imageName = "\(imageFolder)/\(randomImageName)"
                } else {
                    secondImageName = "\(imageFolder)/\(randomImageName)"
                }
                showSecondImage.toggle()
        }
    }

    private func hideApp() {
        debugPrint("hideApp \(index)")
        imageOrBackgroundChangeTimer?.invalidate()
        imageOrBackgroundChangeTimer = nil
        stopMonitoring()
        WindowManager.shared.exitFullScreen()
    }

    private func loadImageNames() {
        debugPrint("loadImageNames")
        let imageFolder = selectedFolderPath
        let folderURL = URL(fileURLWithPath: imageFolder)
        let fileManager = FileManager.default
        imageMode = false
        do {
            let contents = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            imageNames = []
            imageNames = contents.compactMap { $0.pathExtension.lowercased() == "webp" || $0.pathExtension.lowercased() == "avif" || $0.pathExtension.lowercased() == "jpeg" || $0.pathExtension.lowercased() == "jpg" || $0.pathExtension.lowercased() == "png" ? $0.lastPathComponent : nil }
            debugPrint("imageNames: \(imageNames)")
            imageMode = imageNames.count >= 2
            debugPrint("imageMode: \(imageMode)")
            if !imageMode {
                imageName = nil
                secondImageName = nil
            }
        } catch {
            debugPrint("Error loading image names: \(error)")
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundColor
                    .edgesIgnoringSafeArea(.all)
                    .opacity(showFadeColor ? 0 : 1)
                fadeColor
                    .opacity(showFadeColor ? 1 : 0)
                    .edgesIgnoringSafeArea(.all)

                if let imageName = imageName {
                    LoadableImage(imagePath: imageName, onError: loadImageNames)
                        .opacity(showSecondImage ? 0 : 1)
                        .animation(.linear(duration: 1), value: showSecondImage)
                }

                if let secondImageName = secondImageName {
                    LoadableImage(imagePath: secondImageName, onError: loadImageNames)
                        .opacity(showSecondImage ? 1 : 0)
                        .animation(.linear(duration: 1), value: showSecondImage)
                }

                if index == 0 {
                    DigitalWatchView(x: x, y: y)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: replaceImageAfter) { newValue in
            resetImageOrBackgroundChangeTimer()
        }
        .onAppear {
            backgroundColor = randomGentleColor()
            setupScreenChangeTimer()
            startAccessingFolder()
            startMonitoring()
            updateHotKey()
        }
        .onChange(of: hotKeyString) { _ in
            updateHotKey()
        }
        .onChange(of: keyString1) { _ in
            updateHotKey()
        }
        .onChange(of: keyString2) { _ in
            updateHotKey()
        }
        .onChange(of: selectedFolderPath) { _ in
            startAccessingFolder()
        }
        .onDisappear {
            timer?.invalidate()
            imageOrBackgroundChangeTimer?.invalidate()
            if let url = URL(string: selectedFolderPath) {
                url.stopAccessingSecurityScopedResource()
            }
        }
        .onReceive(appDelegate.$showWindow, perform: { showWindow in
            if showWindow {
                showApp()
            } else {
                hideApp()
            }
        })
        .onReceive(appDelegate.$startTimer, perform: { _ in
            setupScreenChangeTimer()
        })
    }
}

//import SwiftUI
//
//struct ContentView: View {
//    var body: some View {
//        Text("Hello, World!")
//            .frame(maxWidth: .infinity, maxHeight: .infinity)
//    }
//}
