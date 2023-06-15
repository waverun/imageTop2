import SwiftUI
import UniformTypeIdentifiers
import AppKit
import GameplayKit
import HotKey

//var gShowWatch = true

func calculateWatchPosition(parentSize: CGSize) -> (CGFloat, CGFloat) {
    var seed = UInt64(Date().timeIntervalSince1970)
    let seedData = Data(bytes: &seed, count: MemoryLayout<UInt64>.size)
    let generator = GKARC4RandomSource(seed: seedData)

    let x = CGFloat(generator.nextUniform()) * (parentSize.width * 0.8 - parentSize.width * 0.2) + parentSize.width * 0.2
    let y = CGFloat(generator.nextUniform()) * (parentSize.height * 0.8 - parentSize.height * 0.2) + parentSize.height * 0.2

    return (x, y)
}

struct ContentView: View {
    var index: Int

    @State  var directoryWatcher: DirectoryWatcher?

    //    @State var eventMonitor: Any?

    @EnvironmentObject var appDelegate: AppDelegate

    @State  var loadingImage = true

    @State var firstImage: NSImage? = nil
    @State var secondImage: NSImage? = nil
    @State var firstImagePath = ""
    @State var secondImagePath = ""
    @State var photographer = ""
    @State var showVideo = false
    @State var firstVideoPath = ""
    @State var secondVideoPath = ""
    @State var firstSetTimer = true

    @State var hotkey: HotKey? = HotKey(key: .escape, modifiers: [.control, .command])

    @State var testText: String = ""

    @AppStorage("replaceImageAfter")  var replaceImageAfter: TimeInterval = 10
    @AppStorage("selectedFolderPath")  var selectedFolderPath: String = ""
    @AppStorage("imageTopFolderBookmark")  var imageTopFolderBookmarkData: Data?
    @AppStorage("hotKeyString")  var hotKeyString: String = "escape"
    @AppStorage("modifierKeyString1")  var keyString1: String = "command"
    @AppStorage("modifierKeyString2")  var keyString2: String = "control"
    @AppStorage("usePhotosFromPexels")  var usePhotosFromPexels: Bool = false

    //    @State  var imageName: String?
    //    @State  var timer: Timer? = nil
    @State var imageNames: [String] = []
    @State var pexelsImages: [String] = []
    @State var imageOrBackgroundChangeTimer: Timer? = nil
    @State var backgroundColor: Color = Color.clear
    @State var imageMode = false
    @State var fadeColor: Color = Color.clear
    @State var showFadeColor: Bool = false
    //    @State  var secondImageName: String?
    @State var showSecondImage: Bool = false
    @State var showSecondVideo: Bool = false
    @State var x: CGFloat = {
        if let screenSize = NSScreen.main?.frame.size {
            return calculateWatchPosition(parentSize: screenSize).0
        }
        return 0
    }()

    @State var y: CGFloat = {
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

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundColor
                    .edgesIgnoringSafeArea(.all)
                    .opacity(showFadeColor ? 0 : 1)
                fadeColor
                    .opacity(showFadeColor ? 1 : 0)
                    .edgesIgnoringSafeArea(.all)

                if firstVideoPath != "",
                   let url = URL(string: firstVideoPath) {
                    VideoPlayerView(url: url, index: index) {
                        loadRandomImage()
                    }
                    .opacity(showVideo && !showSecondVideo ? 1 : 0)
                    .animation(.linear(duration: 1), value: showSecondVideo)
                    .edgesIgnoringSafeArea(.all)
                }

                if secondVideoPath != "",
                   let url = URL(string: secondVideoPath) {
                    VideoPlayerView(url: url, index: index) {
                        loadRandomImage()
                    }
                    .opacity(showVideo && showSecondVideo ? 1 : 0)
                    .animation(.linear(duration: 1), value: showSecondVideo)
                    .edgesIgnoringSafeArea(.all)
                }

//                if !loadingImage {
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
                            .opacity(showSecondImage || showVideo || loadingImage ? 0 : 1)
                            .animation(.linear(duration: 1), value: showSecondImage || showVideo || loadingImage)
                    } else {
                        Color.clear
                    }

                    if let image = secondImage {
                        Image(nsImage: image)
                            .resizable()
                            .clipped()
                            .edgesIgnoringSafeArea(.all)
                            .opacity(showSecondImage && !showVideo && !loadingImage ? 1 : 0)
                            .animation(.linear(duration: 1), value: showSecondImage || showVideo || loadingImage )
                    }  else {
                        Color.clear
                    }
//                }
                //                }
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
            backgroundColor = randomGentleColor()
//            if imageOrBackgroundChangeTimer == nil
//            startScreenChangeTimer()
//            }
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
            print("received showWindow \(showWindow) \(index)")
            if showWindow {
                showApp()
            } else {
                hideApp()
            }
        })
        .onReceive(appDelegate.$startTimer, perform: { _ in
            startScreenChangeTimer()
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
    //     func startMonitoring() {
    //        debugPrint("startMonitoring")
    //        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .mouseMoved]) { event in
    //            debugPrint("in startMonitoring")
    //            self.hideApp()
    //            return event
    //        }
    //    }

    func startMonitoringUserInput() {
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

    func stopMonitoringUserInput() {
        if let monitor = appDelegate.keyAndMouseEventMonitor {
            debugPrint("stopMonitoringUserInput")
            NSEvent.removeMonitor(monitor)
            appDelegate.keyAndMouseEventMonitor = nil
        }
    }

    func startAccessingFolder() {
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

    func updateHotKey() {
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

    func showApp() {
        //        startMonitoringUserInput()
        //        WindowManager.shared.enterFullScreen()
        if showVideo,
           let player = gPlayers[index] {
            print("video1 play \(index)")
            player.play()
        }
        startScreenChangeTimer()
    }

    func hotkeyPressed() {
        debugPrint("hotkey pressed")
        //        showApp()
        appDelegate.showWindow = true
        appDelegate.hideSettings()
        if index == 0 {
            WindowManager.shared.enterFullScreen()
        }
    }

    func resetImageOrBackgroundChangeTimer() {
        imageOrBackgroundChangeTimer?.invalidate()
        imageOrBackgroundChangeTimer = nil
        startScreenChangeTimer()
    }

    func randomGentleColor() -> Color {
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

    func changeBackgroundColor() {
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

    func startScreenChangeTimer() {
        if imageOrBackgroundChangeTimer != nil {
            debugPrint("invalidate existing timer")
            stopChangeTimer()
        }

        if firstSetTimer {
            firstSetTimer = false
            changeScreenImageOrColor()
        }

        print("startScreenChangeTimer \(index)")

        imageOrBackgroundChangeTimer = Timer.scheduledTimer(withTimeInterval: replaceImageAfter, repeats: true) { [self] _ in
            changeScreenImageOrColor()
        }
    }

    func changeScreenImageOrColor() {
        //        if ScreenLockStatus.shared.isLocked {
        //            return
        //        }
        debugPrint("changeScreenImageOrColor \(index)")
        _ = imageMode ? loadRandomImage() : changeBackgroundColor()
    }

    func loadRandomImage() {
        func extractNameFromFilePath(filePath: String) -> String {
            let components = filePath.components(separatedBy: "/")
            if let pexelsIndex = components.firstIndex(of: "pexels") {
                let fileName = components[pexelsIndex + 1]
                let nameComponents = fileName.components(separatedBy: "_")
                return nameComponents[0]
            }
            return ""
        }
        debugPrint("video loadRandomImage \(index)")
//        secondVideoPath = "https://media.istockphoto.com/id/1389532697/video/choosing-the-right-shade-from-color-palette-collection-closeup.mp4?s=mp4-640x640-is&k=20&c=2ZJHKhw1tu7x_uu75Ab0gI9InHHfS-wqYCOPhdNb9i0="

        DispatchQueue.global(qos: .userInitiated).async {
            var newRandomImageOrVideoPath = ""
            repeat {
                if let newRandomImageName = imageNames.randomElement() {
                    newRandomImageOrVideoPath = "\(newRandomImageName)"
                }
            } while (newRandomImageOrVideoPath == firstImagePath && !showSecondImage)
            || (newRandomImageOrVideoPath == secondImagePath && showSecondImage)
            || (newRandomImageOrVideoPath == firstVideoPath && !showSecondVideo)
            || (newRandomImageOrVideoPath == secondVideoPath && showSecondVideo)

            print("video newRandoImage \(newRandomImageOrVideoPath) \(index)")

            if newRandomImageOrVideoPath.starts(with: "https:") {
                if showSecondVideo {
                    firstVideoPath = firstVideoPath == newRandomImageOrVideoPath ? "https://media.istockphoto.com/id/1389532697/video/choosing-the-right-shade-from-color-palette-collection-closeup.mp4?s=mp4-640x640-is&k=20&c=2ZJHKhw1tu7x_uu75Ab0gI9InHHfS-wqYCOPhdNb9i0=" : newRandomImageOrVideoPath
                } else {
                    secondVideoPath = secondVideoPath == newRandomImageOrVideoPath ? "https://media.istockphoto.com/id/1389532697/video/choosing-the-right-shade-from-color-palette-collection-closeup.mp4?s=mp4-640x640-is&k=20&c=2ZJHKhw1tu7x_uu75Ab0gI9InHHfS-wqYCOPhdNb9i0=" : newRandomImageOrVideoPath
                }
                showSecondVideo.toggle()
                if !showVideo {
                    stopChangeTimer()
                    showVideo = true
                }
                return
            }

            guard let nsImage = NSImage(contentsOfFile: newRandomImageOrVideoPath)
            else {
                imageNames = loadImageNames()
                loadingImage = true
                return
            }

            if newRandomImageOrVideoPath.contains("/pexels/") {
                photographer = extractNameFromFilePath(filePath: newRandomImageOrVideoPath)
            } else {
                photographer = ""
            }

            self.showSecondImage.toggle()
            DispatchQueue.main.async {
                if showVideo {
                    startScreenChangeTimer()
                    showVideo = false
                }
                self.loadingImage = true
                if showSecondImage {
                    self.firstImagePath = newRandomImageOrVideoPath
                    self.firstImage = nsImage
                } else {
                    self.secondImagePath = newRandomImageOrVideoPath
                    self.secondImage = nsImage
                }
                self.showSecondImage.toggle()
                self.loadingImage = false
            }
        }
    }

    func handlePexelsPhotos() {
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

    func stopChangeTimer () {
        print("stopChangeTimer \(index)")
        imageOrBackgroundChangeTimer?.invalidate()
        imageOrBackgroundChangeTimer = nil
    }

    func hideApp() {
        debugPrint("hideApp \(index)")
        stopChangeTimer()
        stopMonitoringUserInput()
        if index == 0 {
            WindowManager.shared.exitFullScreen()
        }
    }

    func callLoadImageNames() {
        imageNames = loadImageNames()
    }

    func startWatchingFolder(imageFolder: String) {
        do {
            try directoryWatcher = DirectoryWatcher(directoryPath: imageFolder, onChange: callLoadImageNames)
        } catch let error {
            print("failed to watch directory: \(imageFolder) - \(error.localizedDescription)")
        }
    }

    func loadImageNames(from: URL? = nil) -> [String] {
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
//            imageNames = []
            imageNames.append("https://player.vimeo.com/external/342571552.hd.mp4?s=6aa6f164de3812abadff3dde86d19f7a074a8a66&profile_id=175&oauth2_token_id=57447761")
            imageNames.append("https://player.vimeo.com/external/269971860.m3u8?s=ac08929c597387cc77ae3d88bfe2ad66a9c4d31f&oauth2_token_id=57447761")
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
}
