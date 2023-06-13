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

    @State private var directoryWatcher: DirectoryWatcher?

    //    @State var eventMonitor: Any?

    @EnvironmentObject var appDelegate: AppDelegate

    @State private var loadingImage = true

    @State private var firstImage: NSImage? = nil
    @State private var secondImage: NSImage? = nil
    @State private var firstImagePath = ""
    @State private var secondImagePath = ""
    @State private var photographer = ""

    @State private var hotkey: HotKey? = HotKey(key: .escape, modifiers: [.control, .command])

    @State private var testText: String = ""

    @AppStorage("replaceImageAfter") private var replaceImageAfter: TimeInterval = 10
    @AppStorage("selectedFolderPath") private var selectedFolderPath: String = ""
    @AppStorage("imageTopFolderBookmark") private var imageTopFolderBookmarkData: Data?
    @AppStorage("hotKeyString") private var hotKeyString: String = "escape"
    @AppStorage("modifierKeyString1") private var keyString1: String = "command"
    @AppStorage("modifierKeyString2") private var keyString2: String = "control"
    @AppStorage("usePhotosFromPexels") private var usePhotosFromPexels: Bool = false

    //    @State private var imageName: String?
    //    @State private var timer: Timer? = nil
    @State private var imageNames: [String] = []
    @State private var pexelsImages: [String] = []
    @State private var imageOrBackgroundChangeTimer: Timer? = nil
    @State private var backgroundColor: Color = Color.clear
    @State private var imageMode = false
    @State private var fadeColor: Color = Color.clear
    @State private var showFadeColor: Bool = false
    //    @State private var secondImageName: String?
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

    //    let appSupportUrl = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first

    let pexelDownloadSemaphore = DispatchSemaphore(value: 1)

    var pexelsDirectoryUrl: URL? {
        let appSupportUrl = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let pexelsUrl = appSupportUrl?.appendingPathComponent("pexels")

        if let url = pexelsUrl {
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Error creating pexels directory: \(error)")
                return nil
            }
        }

        return pexelsUrl
    }

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

    private func startMonitoringUserInput() {
        if index > 0 {
            return
        }

        debugPrint("startMonitoring")

        if appDelegate.keyAndMouseEventMonitor != nil {
            return
        }

        appDelegate.keyAndMouseEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .mouseMoved]) { event in
            debugPrint("in startMonitoringUserInput showWindow: \(appDelegate.$showWindow)")
            //            self.hideApp()
            if !appDelegate.ignoreMonitor {
                appDelegate.showWindow = false
                debugPrint("show - startMonitoringUserInput")
            }
            return event
        }
    }

    private func stopMonitoringUserInput() {
        if let monitor = appDelegate.keyAndMouseEventMonitor {
            debugPrint("stopMonitoringUserInput")
            NSEvent.removeMonitor(monitor)
            appDelegate.keyAndMouseEventMonitor = nil
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
                        imageNames = loadImageNames()
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
//        startMonitoringUserInput()
        //        WindowManager.shared.enterFullScreen()
        setupScreenChangeTimer()
    }

    private func hotkeyPressed() {
        debugPrint("hotkey pressed")
        //        showApp()
        appDelegate.showWindow = true
        appDelegate.hideSettings()
        if index == 0 {
            WindowManager.shared.enterFullScreen()
        }
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
        photographer = ""
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
            stopChangeTimer()
        }

        debugPrint("setupScreenChangeTimer")
        imageOrBackgroundChangeTimer = Timer.scheduledTimer(withTimeInterval: replaceImageAfter, repeats: true) { [self] _ in
            changeScreenImageOrColor()
        }
    }

    private func changeScreenImageOrColor() {
        //        if ScreenLockStatus.shared.isLocked {
        //            return
        //        }
        debugPrint("changeScreenImageOrColor")
        _ = imageMode ? loadRandomImage() : changeBackgroundColor()
    }

    private func loadRandomImage() {
        func extractNameFromFilePath(filePath: String) -> String {
            let components = filePath.components(separatedBy: "/")
            if let pexelsIndex = components.firstIndex(of: "pexels") {
                let fileName = components[pexelsIndex + 1]
                let nameComponents = fileName.components(separatedBy: "_")
                return nameComponents[0]
            }
            return ""
        }
        debugPrint("loadRandomImage \(index)")
        //        let imageFolder = selectedFolderPath

        DispatchQueue.global(qos: .userInitiated).async {
            var newRandomImagePath = ""
            repeat {
                if let newRandomImageName = imageNames.randomElement() {
                    //                    newRandomImagePath = "\(imageFolder)/\(newRandomImageName)"
                    newRandomImagePath = "\(newRandomImageName)"
                }
            } while (newRandomImagePath == firstImagePath && !showSecondImage)
            || (newRandomImagePath == secondImagePath && showSecondImage)

            guard let nsImage = NSImage(contentsOfFile: newRandomImagePath)
            else {
                imageNames = loadImageNames()
                loadingImage = true
                return
            }

            if newRandomImagePath.contains("/pexels/") {
                photographer = extractNameFromFilePath(filePath: newRandomImagePath)
            } else {
                photographer = ""
            }

            self.showSecondImage.toggle()
            DispatchQueue.main.async {
                self.loadingImage = true
                if showSecondImage {
                    self.firstImagePath = newRandomImagePath
                    self.firstImage = nsImage
                } else {
                    self.secondImagePath = newRandomImagePath
                    self.secondImage = nsImage
                }
                self.showSecondImage.toggle()
                self.loadingImage = false
            }
        }
    }

    private func handlePexelsPhotos() {
        print("handlePexelsPhotos: \(index)")
        if usePhotosFromPexels,
           //           pexelDownloadSemaphore.wait(timeout: .now()) == .success,
           let pexelsDirectoryUrl = pexelsDirectoryUrl {
            pexelsImages = loadImageNames(from: pexelsDirectoryUrl)
            DispatchQueue.global().async {
                pexelDownloadSemaphore.wait()
                if pexelsImages.count == 0 {
                    downloadPexelPhotos(pexelsFolder: pexelsDirectoryUrl) {
                        //                        let loadedPexelsImages = loadImageNames(from: pexelsDirectoryUrl)
                        //                        DispatchQueue.main.async {
                        pexelsImages = loadImageNames(from: pexelsDirectoryUrl)
                        pexelDownloadSemaphore.signal()
                        appDelegate.loadImages.toggle()
                        //                        }
                    }
                } else {
                    pexelDownloadSemaphore.signal()
                }
            }
        }
    }

    private func stopChangeTimer () {
        imageOrBackgroundChangeTimer?.invalidate()
        imageOrBackgroundChangeTimer = nil
    }

    private func hideApp() {
        debugPrint("hideApp \(index)")
        stopChangeTimer()
        stopMonitoringUserInput()
        if index == 0 {
            WindowManager.shared.exitFullScreen()
        }
    }

    private func callLoadImageNames() {
        imageNames = loadImageNames()
    }

    private func startWatchingFolder(imageFolder: String) {
        do {
            try directoryWatcher = DirectoryWatcher(directoryPath: imageFolder, onChange: callLoadImageNames)
        } catch let error {
            print("failed to watch directory: \(imageFolder) - \(error.localizedDescription)")
        }
    }

    private func loadImageNames(from: URL? = nil) -> [String] {
        debugPrint("loadImageNames")
        let imageFolder = selectedFolderPath

        let folderURL = from == nil ? URL(fileURLWithPath: imageFolder) : from!
        let fileManager = FileManager.default
        imageMode = false
        var imageNames: [String] = []
        do {
            let contents = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            imageNames = contents.compactMap { $0.pathExtension.lowercased() == "webp" || $0.pathExtension.lowercased() == "avif" || $0.pathExtension.lowercased() == "jpeg" || $0.pathExtension.lowercased() == "jpg" || $0.pathExtension.lowercased() == "png" ? $0.lastPathComponent : nil }
            let folderString = folderURL.path
            imageNames = imageNames.map { image in
                folderString + "/" + image
            }
            if from == nil {
                imageNames.append(contentsOf: pexelsImages)
                print("pexelImages: \(pexelsImages.count)")
            }
            debugPrint("imageNames: \(imageNames)")
            imageMode = imageNames.count >= 2
            debugPrint("imageMode: \(imageMode)")
            if !imageMode {
                firstImage = nil
                secondImage = nil
            }
        } catch {
            debugPrint("Error loading image names: \(error)")
        }
        return imageNames
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

                // Inside your ContentView body
                if !loadingImage {
                    if let image = firstImage {
                        Image(nsImage: image)
                            .resizable()
                            .clipped()
                            .edgesIgnoringSafeArea(.all)
                            .overlay(
                                VStack {
                                    Spacer()
                                    HStack {
                                        Text(photographer)
                                            .foregroundColor(.white)
                                            .font(.custom("Noteworthy", size: 20))
                                            .shadow(color: .black, radius: 3, x: 0, y: 0)
                                            .padding(.bottom, 50)
                                            .padding(.leading, 50)
                                        Spacer()
                                    }
                                }
                            )
                            .opacity(showSecondImage ? 0 : 1)
                            .animation(.linear(duration: 1), value: showSecondImage)
                    } else {
                        Color.clear
                    }

                    if let image = secondImage {
                        Image(nsImage: image)
                            .resizable()
                            .clipped()
                            .edgesIgnoringSafeArea(.all)
                            .opacity(showSecondImage ? 1 : 0)
                            .animation(.linear(duration: 1), value: showSecondImage)
                    }  else {
                        Color.clear
                    }
                }

                //                if !loadingImage {
                //                    if let imageName = imageName {
                //                        LoadableImage(imagePath: imageName, onError: loadImageNames, isLoading: loadingImage)
                //                            .opacity(showSecondImage ? 0 : 1)
                //                            .animation(.linear(duration: 1), value: showSecondImage)
                //                    }
                //
                //                    if let secondImageName = secondImageName {
                //                        LoadableImage(imagePath: secondImageName, onError: loadImageNames, isLoading: loadingImage)
                //                            .opacity(showSecondImage ? 1 : 0)
                //                            .animation(.linear(duration: 1), value: showSecondImage)
                //                    }
                //                }
                //
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
            print("selectedFolderPath: \(selectedFolderPath)")
//            startMonitoringUserInput()
            backgroundColor = randomGentleColor()
            setupScreenChangeTimer()
            startAccessingFolder()
            updateHotKey()
            if index == 0 {
                handlePexelsPhotos()
            }
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
            startWatchingFolder(imageFolder: selectedFolderPath)
        }
        .onChange(of: usePhotosFromPexels) { newValue in
            if newValue {
                if index == 0 {
                    handlePexelsPhotos()
                }
            } else {
                if let pexelsDirectoryUrl = pexelsDirectoryUrl {
                    clearFolder(folderPath: pexelsDirectoryUrl.path, fileToKeep: ".imageTop")
                    pexelsImages = []
                    imageNames = loadImageNames()
                    //                    appDelegate.loadImages.toggle()
                }
            }
        }
        .onDisappear {
            print("before onDisapear")
            //            timer?.invalidate()
            stopChangeTimer()
            if let url = URL(string: selectedFolderPath) {
                url.stopAccessingSecurityScopedResource()
            }
            print("after onDisapear")
        }
        .onReceive(appDelegate.$showWindow, perform: { showWindow in
            print("received showWindow \(showWindow)")
            if showWindow {
                showApp()
            } else {
                hideApp()
            }
        })
        .onReceive(appDelegate.$startTimer, perform: { _ in
            setupScreenChangeTimer()
            startMonitoringUserInput()
        })
        .onReceive(appDelegate.$loadImages, perform: { _ in
            print("loadImages: \(index)")
            if index > 0 {
                pexelsImages = loadImageNames(from: pexelsDirectoryUrl)
            }
            imageNames = loadImageNames()
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
