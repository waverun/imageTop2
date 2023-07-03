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
    @State var startShowVideo = false
    @State var startShowImage = false
    @State var networkIsReachableOrNotShowingVideos = false

    @State var hotkey: HotKey? = HotKey(key: .escape, modifiers: [.control, .command])

    @State var testText: String = ""

    @AppStorage("replaceImageAfter") var replaceImageAfter: TimeInterval = 10
    @AppStorage("selectedFolderPath") var selectedFolderPath: String = ""
    @AppStorage("imageTopFolderBookmark") var imageTopFolderBookmarkData: Data?
    @AppStorage("hotKeyString") var hotKeyString: String = "escape"
    @AppStorage("modifierKeyString1") var keyString1: String = "command"
    @AppStorage("modifierKeyString2") var keyString2: String = "control"
    @AppStorage("usePhotosFromPexels") var usePhotosFromPexels: Bool = false
    @AppStorage("useVideosFromPexels") var useVideosFromPexels: Bool = false

    //    @State  var imageName: String?
    //    @State  var timer: Timer? = nil
    @State var imageAndVideoNames: [String] = []
    @State var imageOrBackgroundChangeTimer: Timer? = nil
    @State var backgroundColor: Color = Color.clear
    @State var imageOrVideoMode = false
    @State var fadeColor: Color = Color.clear
    @State var showFadeColor: Bool = false
    @State var showSecondImage: Bool = false
    @State var showSecondVideo: Bool = false
    @State var x: CGFloat = 0

    @State var y: CGFloat = 0

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

    func resetWatchPosition() {
        if let screenSize = NSScreen.main?.frame.size {
            let (xValue, yValue) = calculateWatchPosition(parentSize: screenSize)
            x = xValue
            y = yValue
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundColor
                    .opacity(showFadeColor ? 0 : 1)
                    .animation(.linear(duration: 1), value: showFadeColor)
                    .edgesIgnoringSafeArea(.all)
                fadeColor
                    .opacity(showFadeColor ? 1 : 0)
                    .animation(.linear(duration: 1), value: showFadeColor)
                    .edgesIgnoringSafeArea(.all)

                if firstVideoPath != "",
                   let url = URL(string: firstVideoPath) {
                    VideoPlayerView(url: url, index: index) {
                        changeScreenImageVideoOrColor()
                    }
                    .opacity(showVideo && !showSecondVideo ? 1 : 0)
                    .animation(.easeIn(duration: showVideo && !showSecondVideo ? 4 : 4), value: showVideo && !showSecondVideo)
                    .edgesIgnoringSafeArea(.all)
                }

                if secondVideoPath != "",
                   let url = URL(string: secondVideoPath) {
                    VideoPlayerView(url: url, index: index) {
                        changeScreenImageVideoOrColor()
                    }
                    .opacity(showVideo && showSecondVideo ? 1 : 0)
                    .animation(.easeIn(duration: showVideo && showSecondVideo ? 4 : 4), value: showVideo && showSecondVideo)
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
                            .animation(.linear(duration: startShowVideo ? 4 : 1), value: showSecondImage || showVideo || loadingImage)
                    } else {
                        Color.clear
                    }

                    if let image = secondImage {
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
                            .opacity(showSecondImage && !showVideo && !loadingImage ? 1 : 0)
                            .animation(.linear(duration: startShowVideo ? 4 : 1), value: showSecondImage && !showVideo && !loadingImage)
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
                handlePexelsVideos()
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
                    clearPexelImages(folderPath: pexelsDirectoryUrl.path, filesToKeep: [".imageTop", "videoList.txt"])
                    appDelegate.pexelsImages = []
                    imageAndVideoNames = loadImageAndVideoNames()
                    //                    appDelegate.loadImages.toggle()
                }
            }
        }
        .onChange(of: useVideosFromPexels) { newValue in
            if newValue {
                if index == 0 {
                    handlePexelsVideos()
                }
            } else {
                if let pexelsDirectoryUrl = pexelsDirectoryUrl {
                    clearPexelVideos(folderURL: pexelsDirectoryUrl, fileName: "videoList.txt")
                    appDelegate.pexelsVideos = []
                    imageAndVideoNames = loadImageAndVideoNames()
                    //                    appDelegate.loadImages.toggle()
                }
            }
        }
        .onDisappear {
            print("before onDisapear")
            //            timer?.invalidate()
            resetWatchPosition()
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
            if !showVideo {
                startScreenChangeTimer()
                changeScreenImageVideoOrColor()
            }
            startMonitoringUserInput()
        })
        .onReceive(appDelegate.$loadImages, perform: { _ in
            print("loadImages: \(index)")
            if index > 0 {
                appDelegate.pexelsImages = loadImageAndVideoNames(from: pexelsDirectoryUrl)
            }
            imageAndVideoNames = loadImageAndVideoNames()
        })
        .onReceive(appDelegate.$networkIsReachable, perform: { _ in
            print("onReceive \(index) gNetworkIsReachable: \(gNetworkIsReachable) imageOrBackgroundChangeTimer == nil:   \(imageOrBackgroundChangeTimer == nil)")
            showAccordingToNetworkReachability()
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

    func showAccordingToNetworkReachability () {
        if !imageAndVideoNames.contains(where: { imageOrVideo in
            imageOrVideo.starts(with: "https:")
        }) {
            networkIsReachableOrNotShowingVideos = true
            return
        }
        if gNetworkIsReachable {
            networkIsReachableOrNotShowingVideos = true
            imageOrVideoMode = imageAndVideoNames.count > 2
            if imageOrBackgroundChangeTimer == nil {
                startScreenChangeTimer()
            }
        } else {
            networkIsReachableOrNotShowingVideos = false
            showVideo = false
            if imageOrVideoMode {
                firstImage = nil
                secondImage = nil
                firstVideoPath = ""
                secondVideoPath = ""
                imageOrVideoMode = false
                imageOrVideoMode = false
            }
            if imageOrBackgroundChangeTimer == nil {
                startScreenChangeTimer()
            }
        }
    }

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
                        imageAndVideoNames = loadImageAndVideoNames()
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
        showAccordingToNetworkReachability()

        if showVideo, networkIsReachableOrNotShowingVideos,
           let player = gPlayers[index] {
            print("video1 play \(index)")
            player.play()
            if let timer = gTimers[index] {
                timer.resume()
            }
        }
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

        if appDelegate.firstSetTimer[index] == nil {
            appDelegate.firstSetTimer[index] = false
            print("firstsettime changeScreenImageOrColor \(index)")
            changeScreenImageVideoOrColor()
        }

        print("startScreenChangeTimer \(index)")

        imageOrBackgroundChangeTimer = Timer.scheduledTimer(withTimeInterval: replaceImageAfter, repeats: true) { [self] _ in
            changeScreenImageVideoOrColor()
        }
    }

    func changeScreenImageVideoOrColor() {
        debugPrint("changeScreenImageOrColor gNetworkIsReachable: \(gNetworkIsReachable) \(index)")
        _ = imageOrVideoMode && networkIsReachableOrNotShowingVideos ? loadRandomImageOrVideo() : changeBackgroundColor()
    }

    func loadRandomImageOrVideo() {
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
                if let newRandomImageName = imageAndVideoNames.randomElement() {
                    newRandomImageOrVideoPath = "\(newRandomImageName)"
                }
            } while (newRandomImageOrVideoPath == firstImagePath && !showSecondImage)
            || (newRandomImageOrVideoPath == secondImagePath && showSecondImage)
            || (newRandomImageOrVideoPath == firstVideoPath)
            || (newRandomImageOrVideoPath == secondVideoPath)

            print("video newRandoImage \(newRandomImageOrVideoPath) \(index)")

            if newRandomImageOrVideoPath.starts(with: "https:") {
                if showSecondVideo {
                    firstVideoPath = firstVideoPath == newRandomImageOrVideoPath ? "https://media.istockphoto.com/id/1389532697/video/choosing-the-right-shade-from-color-palette-collection-closeup.mp4?s=mp4-640x640-is&k=20&c=2ZJHKhw1tu7x_uu75Ab0gI9InHHfS-wqYCOPhdNb9i0=" : newRandomImageOrVideoPath
                } else {
                    secondVideoPath = secondVideoPath == newRandomImageOrVideoPath ? "https://media.istockphoto.com/id/1389532697/video/choosing-the-right-shade-from-color-palette-collection-closeup.mp4?s=mp4-640x640-is&k=20&c=2ZJHKhw1tu7x_uu75Ab0gI9InHHfS-wqYCOPhdNb9i0=" : newRandomImageOrVideoPath
                }
                startShowVideo = false
                if !showVideo {
                    stopChangeTimer()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        startShowVideo = true
                        showVideo = true
                        showSecondVideo.toggle()
                    }
                } else {
                    showSecondVideo.toggle()
                }
                return
            }

            guard let nsImage = NSImage(contentsOfFile: newRandomImageOrVideoPath)
            else {
                imageAndVideoNames = loadImageAndVideoNames()
                loadingImage = true
                return
            }

            if newRandomImageOrVideoPath.contains("/pexels/") {
                photographer = extractNameFromFilePath(filePath: newRandomImageOrVideoPath)
            } else {
                photographer = ""
            }

            self.showSecondImage.toggle()
            startShowImage = false
            DispatchQueue.main.async {
                if showVideo {
                    startShowImage = true
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

    func handlePexelsVideos() {
        print("handlePexelsVideos: \(index)")
        if useVideosFromPexels,
           let pexelsDirectoryUrl = pexelsDirectoryUrl {
//            if let videosList = loadVideoNames(from: pexelsDirectoryUrl) {
//                pexelsVideos = videosList
//                return
//            }
            getPexelsVideoList(pexelsFolder: pexelsDirectoryUrl) { videosList in
                DispatchQueue.main.async {
                    appDelegate.pexelsVideos = videosList
                }
            }
//            DispatchQueue.global().async {
//                pexelDownloadSemaphore.wait()
//                if pexelsImages.count == 0 {
//                    downloadPexelPhotos(pexelsFolder: pexelsDirectoryUrl) {
//                        //                        let loadedPexelsImages = loadImageNames(from: pexelsDirectoryUrl)
//                        //                        DispatchQueue.main.async {
//                        pexelsImages = loadImageNames(from: pexelsDirectoryUrl)
//                        pexelDownloadSemaphore.signal()
//                        appDelegate.loadImages.toggle()
//                        //                        }
//                    }
//                } else {
//                    pexelDownloadSemaphore.signal()
//                }
//            }
        }
    }

    func handlePexelsPhotos() {
        print("handlePexelsPhotos: \(index)")
        if usePhotosFromPexels,
           let pexelsDirectoryUrl = pexelsDirectoryUrl {
            appDelegate.pexelsImages = loadImageAndVideoNames(from: pexelsDirectoryUrl)
            DispatchQueue.global().async {
                pexelDownloadSemaphore.wait()
                if appDelegate.pexelsImages.count == 0 {
                    downloadPexelPhotos(pexelsFolder: pexelsDirectoryUrl) {
                        //                        let loadedPexelsImages = loadImageNames(from: pexelsDirectoryUrl)
                        //                        DispatchQueue.main.async {
                        appDelegate.pexelsImages = loadImageAndVideoNames(from: pexelsDirectoryUrl)
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
        imageAndVideoNames = loadImageAndVideoNames()
    }

    func startWatchingFolder(imageFolder: String) {
        do {
            try directoryWatcher = DirectoryWatcher(directoryPath: imageFolder, onChange: callLoadImageNames)
        } catch let error {
            print("failed to watch directory: \(imageFolder) - \(error.localizedDescription)")
        }
    }

    func loadImageAndVideoNames(from: URL? = nil) -> [String] {
        debugPrint("loadImageNames")
        let imageFolder = selectedFolderPath

        let folderURL = from == nil ? URL(fileURLWithPath: imageFolder) : from!
        let fileManager = FileManager.default
        imageOrVideoMode = false
        startShowVideo = false
        var imageOrVideoNames: [String] = []
        do {
            let contents = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            imageOrVideoNames = contents.compactMap { $0.pathExtension.lowercased() == "webp" || $0.pathExtension.lowercased() == "avif" || $0.pathExtension.lowercased() == "jpeg" || $0.pathExtension.lowercased() == "jpg" || $0.pathExtension.lowercased() == "png" ? $0.lastPathComponent : nil }
            let folderString = folderURL.path
            imageOrVideoNames = imageOrVideoNames.map { image in
                folderString + "/" + image
            }
            if from == nil {
                imageOrVideoNames.append(contentsOf: appDelegate.pexelsImages)
                print("pexelImages: \(appDelegate.pexelsImages.count)")
                imageOrVideoNames.append(contentsOf: appDelegate.pexelsVideos)
                print("pexelVideos: \(appDelegate.pexelsVideos.count)")
            }
//            imageNames = []
//            imageNames.append("https://player.vimeo.com/external/342571552.hd.mp4?s=6aa6f164de3812abadff3dde86d19f7a074a8a66&profile_id=175&oauth2_token_id=57447761")
//            imageNames.append("https://player.vimeo.com/external/269971860.m3u8?s=ac08929c597387cc77ae3d88bfe2ad66a9c4d31f&oauth2_token_id=57447761")
//            debugPrint("imageNames: \(imageNames)")
            imageOrVideoMode = imageOrVideoNames.count >= 2
            debugPrint("imageMode: \(imageOrVideoMode)")
            if !imageOrVideoMode {
                firstImage = nil
                secondImage = nil
            }
        } catch {
            debugPrint("Error loading image names: \(error)")
        }
        return imageOrVideoNames
    }
}
