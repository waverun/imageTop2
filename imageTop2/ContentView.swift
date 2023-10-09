import SwiftUI
import UniformTypeIdentifiers
import AppKit
//import GameplayKit
import HotKey

//var gContentViews: [Int:ContentView] = [:]
var gContentViews = ThreadSafeDict<Int, ContentView>()
var gStateObjects = ThreadSafeDict<Int, StateObjects>()
//var gStateObjects: [Int:StateObjects] = [:]
var gHotkey: HotKey? = HotKey(key: .escape, modifiers: [.control, .command])
var gImageAndVideoNames: [String] = []
var gDirectoryWatcher: DirectoryWatcher?
var loadImagesWorkItem: DispatchWorkItem?

struct StateObjects {
    var firstVideoPath: String! = ""
    var secondVideoPath: String! = ""
    var viewAppeared = false
    var unusedPaths = Set<String>()
}

struct ContentView: View {
    var index: Int
    var videoFadeTime = 4.0
    var imageFadeTime = 1.0
//    let cpuUsage = getCpuUsage()

    @EnvironmentObject var appDelegate: AppDelegate

    @State var watchTimerIsActive = true
    @State var loadingImage = true
    @State var showView = true
    @State var firstImage: NSImage? = nil
    @State var secondImage: NSImage? = nil
    @State var firstImagePath = ""
    @State var secondImagePath = ""
    @State var firstPhotographer = ""
    @State var secondPhotographer = ""
    @State var showVideo = false
    @State var hideVideos = false // Used to preveint showing videos when replacing images. Sometime, on old video is sean when images are replaced
    @State var firstVideoPath = ""
    @State var secondVideoPath = ""

    @State var startShowVideo = false
    @State var startShowImage = false
    @State var networkIsReachableOrNotShowingVideos = false

    @State var testText: String = ""

    @AppStorage("replaceImageAfter") var replaceImageAfter: TimeInterval = 10
    @AppStorage("selectedFolderPath") var selectedFolderPath: String = ""
    @AppStorage("imageTopFolderBookmark") var imageTopFolderBookmarkData: Data?
    @AppStorage("hotKeyString") var hotKeyString: String = "escape"
    @AppStorage("modifierKeyString1") var keyString1: String = "command"
    @AppStorage("modifierKeyString2") var keyString2: String = "control"
    @AppStorage("usePhotosFromPexels") var usePhotosFromPexels: Bool = false
    @AppStorage("useVideosFromPexels") var useVideosFromPexels: Bool = true

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
                iPrint("Error creating pexels directory: \(error)")
                return nil
            }
        }

        return pexelsUrl
    }

    init(index: Int) {
        if let screenSize = NSScreen.main?.frame.size {
            let (xValue, yValue) = calculateDigitalWatchPosition(parentSize: screenSize)
            _x = State(initialValue: xValue)
            _y = State(initialValue: yValue)
            iPrint("_x, -Y (\(_x), \(_y)")
        }
        self.index = index
        gContentViews[index] = self
        gStateObjects[index] = StateObjects()
    }

    func resetWatchPosition() {
        if let screenSize = NSScreen.main?.frame.size {
            let (xValue, yValue) = calculateDigitalWatchPosition(parentSize: screenSize)
            x = xValue
            y = yValue
        }
    }

    @ViewBuilder var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundView
                if !hideVideos {
                    videoPlayerView
                }
                imageView
                if index == 0 && (appDelegate.showWatchOrCpu || appDelegate.showCpu) {
                    DigitalWatchView(timerIsActive: $watchTimerIsActive, x: x, y: y)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: onAppearAction)
        .onChange(of: replaceImageAfter, perform: handleReplaceImageAfterChange)
        .onChange(of: hotKeyString, perform: handleHotKeyChange)
        .onChange(of: keyString1, perform: handleHotKeyChange)
        .onChange(of: keyString2, perform: handleHotKeyChange)
        .onChange(of: selectedFolderPath, perform: handleSelectedFolderPathChange)
        .onChange(of: usePhotosFromPexels, perform: usePhotosFromPexelsChanged)
        .onChange(of: useVideosFromPexels, perform: useVideosFromPexelsChanged)
        .onChange(of: gImageAndVideoNames, perform: imageAndVideoNamesChanged)
        .onDisappear(perform: onDisappearAction)
        .onReceive(appDelegate.$showWindow, perform: handleShowWindowChange)
        .onReceive(appDelegate.$startMonitoringUserInputTimer, perform: handleStartTimerChange)
        .onReceive(appDelegate.$loadImagesAndVideos, perform: handleLoadImagesAndVideosChange)
        .onReceive(appDelegate.$networkIsReachable, perform: handleNetworkReachabilityChange)
        .onReceive(appDelegate.$setImageOrVideoModeToggle, perform: setImageOrVideoMode)
    }

    @ViewBuilder var backgroundView: some View {
        ZStack {
            backgroundColor
                .opacity(showFadeColor ? 0 : 1)
                .animation(.linear(duration: 1), value: showFadeColor)
                .edgesIgnoringSafeArea(.all)

            fadeColor
                .opacity(showFadeColor ? 1 : 0)
                .animation(.linear(duration: 1), value: showFadeColor)
                .edgesIgnoringSafeArea(.all)
        }
    }

    @ViewBuilder var videoPlayerView: some View {
        ZStack {
            videoPlayerBuilder(videoPath: firstVideoPath, photographer: firstPhotographer, condition: showVideo && !showSecondVideo)
//                .transition(showVideo && !showSecondVideo ? .scale : .slide)
            .zIndex(showVideo && !showSecondVideo ? 1 : 0)
//            .animation(.easeIn(duration: showVideo && !showSecondVideo ? videoFadeTime : videoFadeTime), value: showVideo && !showSecondVideo)
            videoPlayerBuilder(videoPath: secondVideoPath, photographer: secondPhotographer, condition: showVideo && showSecondVideo)
//            .transition(showVideo && showSecondVideo ? .scale : .slide)
            .zIndex(showVideo && showSecondVideo ? 1 : 0)
//            .animation(.easeIn(duration: showVideo && showSecondVideo ? videoFadeTime : videoFadeTime), value: showVideo && showSecondVideo)
        }
        .blur(radius: appDelegate.isVideoBlurred ? 20 : 0)
    }

    func videoPlayerBuilder(videoPath: String, photographer: String, condition: Bool) -> some View {
        if videoPath != "",
           let url = videoPath.starts(with: "https:") ? URL(string: videoPath) : URL(fileURLWithPath: videoPath) {
            return AnyView(
                VideoPlayerView(url: url, index: index) {
                    changeScreenImageVideoOrColor()
                }
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
                                    .opacity(condition ? 1 : 0)
//                                    .animation(.easeIn(duration: condition ? videoFadeTime : videoFadeTime), value: condition)
                                Spacer()
                            }
                        }
                    )
            )
        }
        return AnyView(EmptyView())
    }

    @ViewBuilder var firstImageView: some View {
        imageViewBuilder(image: firstImage, photographer: firstPhotographer, condition: !(showSecondImage || showVideo || loadingImage))
    }

    @ViewBuilder var secondImageView: some View {
        imageViewBuilder(image: secondImage, photographer: secondPhotographer, condition: showSecondImage && !showVideo && !loadingImage)
    }

    @ViewBuilder var imageView: some View {
        ZStack {
            firstImageView
            secondImageView
        }
    }

    func imageViewBuilder(image: NSImage?, photographer: String, condition: Bool) -> some View {
        iPrint("imageViewBuilder: \(index) startShowVideo: \(startShowVideo)")
        if let image = image {
            return AnyView (
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
                                    .opacity(condition ? 1 : 0)
                                    .animation(.linear(duration: startShowVideo ? videoFadeTime : imageFadeTime), value: condition)
                                Spacer()
                            }
                        }
                    )
                    .opacity(condition ? 1 : 0)
                    .animation(.linear(duration: startShowVideo ? videoFadeTime : imageFadeTime), value: condition)
            )
        } else {
            return AnyView(Color.clear)
        }
    }

    func onAppearAction() {
        iPrint("onAppear: \(index)")
        guard !gStateObjects[index]!.viewAppeared else { return }
        gStateObjects[index]!.viewAppeared = true
        iPrint("inside onAppear: \(index)")
        backgroundColor = randomGentleColor()

        handleSelectedFolderPathChange("")
        updateHotKey()

        if !usePhotosFromPexels, !useVideosFromPexels {
            gImageAndVideoNames = loadImageAndVideoNames()
        }

        if index == 0 {
            handlePexelsPhotos()
            handlePexelsVideos()
        }

#if DEBUG
        iPrint("Memory: \(index) onAppear: \(reportMemory())")
#endif

    }

    func handleReplaceImageAfterChange(_ newValue: Double) {
        resetImageOrBackgroundChangeTimer()
    }

    func handleHotKeyChange(_ newValue: String) {
        updateHotKey()
    }

    func handleSelectedFolderPathChange(_ newValue: String) {
        startAccessingFolder(loadImages: true)
        startWatchingFolder(imageFolder: selectedFolderPath)
    }

    func usePhotosFromPexelsChanged(_ usePhotosFromPexels: Bool) {
        switch true {
            case usePhotosFromPexels && index == 0:
                    handlePexelsPhotos()

            case usePhotosFromPexels: setImageOrVideoMode()

            default:
                if let pexelsDirectoryUrl = pexelsDirectoryUrl {
                    clearPexelPhotos(folderPath: pexelsDirectoryUrl.path, filesToKeep: [".imageTop", "videoList.txt"])
                    appDelegate.pexelsPhotos.removeAll()
                    gImageAndVideoNames = loadImageAndVideoNames()
                    //                    appDelegate.loadImages.toggle()
                }
        }
    }

    func useVideosFromPexelsChanged(_ useVideosFromPexels: Bool) {
        switch true {
            case useVideosFromPexels && index == 0:
                handlePexelsVideos()

            case useVideosFromPexels: setImageOrVideoMode()
                
            default:
                if let pexelsDirectoryUrl = pexelsDirectoryUrl {
                    clearPexelVideos(folderURL: pexelsDirectoryUrl, fileName: "videoList.txt")
                    appDelegate.pexelsVideos.removeAll()
                    gImageAndVideoNames = loadImageAndVideoNames()
                }
        }
    }

    func imageAndVideoNamesChanged(_ newValue: [String]) {
        gStateObjects[index]!.unusedPaths.removeAll()
    }

    func onDisappearAction() {
        iPrint("before onDisappear")
        NSCursor.unhide()
        resetWatchPosition()
        stopChangeTimer()
        if let url = URL(string: selectedFolderPath) {
            url.stopAccessingSecurityScopedResource()
        }
        iPrint("after onDisappear")
#if DEBUG
        iPrint("Memory: \(index) onDisappear: \(reportMemory())")
#endif
    }

    func handleShowWindowChange(showWindow: Bool) {
        iPrint("received showWindow \(showWindow) \(index)")
        if showWindow {
            showApp()
        } else {
            hideApp()
        }
    }

    func handleStartTimerChange(_ value: Bool) {
        if !showVideo {
            startChangeTimer()
        }
        startMonitoringUserInput()
    }

    func handleLoadImagesAndVideosChange(_ value: Bool) {
        if index > 0 && usePhotosFromPexels,
           let pexelsDirectoryUrl = pexelsDirectoryUrl {
            appDelegate.pexelsPhotos = loadImageAndVideoNames(fromPexelsPhotos: pexelsDirectoryUrl)
        }
        gImageAndVideoNames = loadImageAndVideoNames()
    }

    func handleNetworkReachabilityChange(_ value: Bool) {
        iPrint("onReceive \(index) gNetworkIsReachable: \(gNetworkIsReachable) imageOrBackgroundChangeTimer == nil:   \(imageOrBackgroundChangeTimer == nil)")
        showAccordingToNetworkReachability()
    }

    func showAccordingToNetworkReachability () {
        let showingVideos = gImageAndVideoNames.contains(where: { imageOrVideo in
            imageOrVideo.starts(with: "https:")
        })

        switch true {
            case !showingVideos:

                networkIsReachableOrNotShowingVideos = true
                return

            case gNetworkIsReachable:

                networkIsReachableOrNotShowingVideos = true
                imageOrVideoMode = gImageAndVideoNames.count > 2

            default:

                networkIsReachableOrNotShowingVideos = false
                showVideo = false
                if imageOrVideoMode {
                    firstImage = nil
                    secondImage = nil
                    gStateObjects[index]!.firstVideoPath = ""
                    firstVideoPath = ""
                    gStateObjects[index]!.secondVideoPath = ""
                    secondVideoPath = ""
                    imageOrVideoMode = false
                }
                if imageOrBackgroundChangeTimer == nil {
                    startChangeTimer()
                }
        }
    }

    func startMonitoringUserInput() {
        if index > 0 {
            return
        }

        iPrint("startMonitoring")

        if appDelegate.keyAndMouseEventMonitor != nil {
            return
        }

        appDelegate.keyAndMouseEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .mouseMoved]) { event in
            iPrint("in startMonitoringUserInput showWindow: \(appDelegate.showWindow)")

            if !appDelegate.ignoreMonitor {
                appDelegate.showWindow = false
                NSApp.deactivate()
                iPrint("show - startMonitoringUserInput")
            }
            return event
        }
    }

    func stopMonitoringUserInput() {
        if let monitor = appDelegate.keyAndMouseEventMonitor {
            iPrint("stopMonitoringUserInput")
            NSEvent.removeMonitor(monitor)
            appDelegate.keyAndMouseEventMonitor = nil
        }
    }

    func startAccessingFolder(loadImages: Bool? = nil) {
        if let bookmarkData = imageTopFolderBookmarkData {
            do {
                var isStale = false
                let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
                if isStale {
                    iPrint("Bookmark data is stale")
                } else {
                    if url.startAccessingSecurityScopedResource() {
                        iPrint("Successfully accessed security-scoped resource")
                        if let loadImages = loadImages,
                           loadImages {
                            gImageAndVideoNames = loadImageAndVideoNames()
                        }
                    } else {
                        iPrint("Error accessing security-scoped resource")
                    }
                }
            } catch {
                iPrint("Error resolving security-scoped bookmark: \(error)")
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
            gHotkey?.isPaused = true
            gHotkey = HotKey(key: key, modifiers: modifiers)
            gHotkey!.keyDownHandler = hotkeyPressed
        }
    }

    func showApp() {
        iPrint("showApp: gPausableTimers.count: \(gPausableTimers.count)")
        if ScreenLockStatus.shared.isLocked {
            appDelegate.showWindow = false
            return
        }
        showAccordingToNetworkReachability()
        if showVideo, networkIsReachableOrNotShowingVideos,
           gPlayers.count > index,
           let player = gPlayers[index] {
            iPrint("video1 play: \(index) \(index) stateObject.firstVideoPath: \(String(describing: gStateObjects[index]!.firstVideoPath)) stateObject.secondVideoPath: \(String(describing: gStateObjects[index]!.secondVideoPath))")
            player.play()
            if gPausableTimers.count > index {
                if let timer = gPausableTimers[index] {
                    timer.resume()
                }
            }
        }
        if let needToLoadImageOrVideo = gNeedToLoadImageOrVideo[index],
           needToLoadImageOrVideo {
            iPrint("showApp: calling due to c")
            changeScreenImageVideoOrColor()
        }
        watchTimerIsActive = true
    }

    func hotkeyPressed() {
        iPrint("hotkey pressed")
//        appDelegate.hideSettings()
        if index == 0 {
            WindowManager.shared.enterFullScreen()
            if !appDelegate.autoStart {
                appDelegate.handleAutoStart()
            }
        }
    }

    func resetImageOrBackgroundChangeTimer() {
        imageOrBackgroundChangeTimer?.invalidate()
        imageOrBackgroundChangeTimer = nil
        startChangeTimer()
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
        firstPhotographer = ""
        secondPhotographer = ""
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
            iPrint("backgroundColor: \(index) \(backgroundColor) fadeColor: \(fadeColor)")
        }
    }

    func startChangeTimer(addTime: Double = 0) { // Add time is required when changing from video to image. In that case the timer should play longer due to the longer time of the fade.
        if imageOrBackgroundChangeTimer != nil {
            iPrint("invalidate existing timer")
            stopChangeTimer()
        }

        if appDelegate.firstSetTimer.count > index,
            appDelegate.firstSetTimer[index] == nil {
                appDelegate.firstSetTimer[index] = false
                iPrint("firstsettime changeScreenImageOrColor \(index)")
                changeScreenImageVideoOrColor()
        }

        iPrint("startScreenChangeTimer: \(index) \(Date())")

        imageOrBackgroundChangeTimer = Timer.scheduledTimer(withTimeInterval: max(replaceImageAfter, 1) + addTime , repeats: addTime == 0) { _ in
            iPrint("imageOrBackgroundChangeTimer: \(index) \(Date())")
            changeScreenImageVideoOrColor()
            if addTime > 0 { //Start the timer with regular time after fading from image to movie
                startChangeTimer()
            }
        }
    }

    func changeScreenImageVideoOrColor() {
//        print("CPU Usage: \(cpuUsage)%")
        iPrint("changeScreenImageOrColor \(index) imageOrVideoMode: \(imageOrVideoMode) gNetworkIsReachable: \(gNetworkIsReachable)")
        setImageOrVideoMode() // Done since there was an error where after sleep and network unreachable, the colors where changed but videos were not played.
        _ = imageOrVideoMode && networkIsReachableOrNotShowingVideos ? loadRandomImageOrVideo() : changeBackgroundColor()
    }

    func loadRandomImageOrVideo() {
#if DEBUG
        iPrint("Memory: \(index) Start loadRandomImageOrVideo: \(reportMemory())")
#endif
        if !appDelegate.isFullScreen {
            gNeedToLoadImageOrVideo[index] = true
            if gPlayers.count > index {
                gPlayers[index]?.pause()
            }
            if gPausableTimers.count > index {
                gPausableTimers[index]?.pause()
                return
            }
        }
        gNeedToLoadImageOrVideo[index] = false
        if showVideo && gImageAndVideoNames.count < 2 { // may happen after bad loading of videos
            startChangeTimer()
            return
        }
        iPrint("video loadRandomImageOrVideo \(index) appDelegate.showWindow: \(appDelegate.showWindow)")
        let newRandomImageOrVideoPath = generateRandomPath()
        DispatchQueue.global(qos: .userInitiated).async {
            switch true {
                case isVideo(newRandomImageOrVideoPath):
                    hideVideos = false
                    handleVideo(newRandomImageOrVideoPath)
                default:
                    if showVideo == false {
                        hideVideos = true
                    }
                    startShowVideo = false
                    handleImage(newRandomImageOrVideoPath)
            }
        }
    }

     func generateRandomPath() -> String {
        var randomPath: String?

        guard gStateObjects[index] != nil else { return "" }

        repeat {
            if gStateObjects[index]!.unusedPaths.isEmpty {
                gStateObjects[index]!.unusedPaths = Set(gImageAndVideoNames)
            }

            // Get a random unused path
            randomPath = gStateObjects[index]!.unusedPaths.randomElement()
            guard randomPath != nil else { continue }

            // Remove the used path from the unusedPaths array
            if let pathIndex = gStateObjects[index]!.unusedPaths.firstIndex(of: randomPath!) {
                gStateObjects[index]!.unusedPaths.remove(at: pathIndex)
            }
        } while shouldRegeneratePath(randomPath!)
        return randomPath!
    }

     func shouldRegeneratePath(_ path: String) -> Bool {
        return (path == firstImagePath && !showSecondImage)
        || (path == secondImagePath && showSecondImage)
        || (path == gStateObjects[index]!.firstVideoPath && !showSecondVideo)
        || (path == gStateObjects[index]!.secondVideoPath && showSecondVideo)
    }

     func isVideo(_ path: String) -> Bool {
        return path.starts(with: "https:") || isVideoFile(atPath: path)
    }

     func handleVideo(_ path: String) {
        iPrint("isVideFile: \(index) newRandomImageOrVideoPath: \(path)")
        let videoComponents = path.components(separatedBy: ",")
         if videoComponents.count > 0 {
             let newVideoPath = videoComponents[0]
             let photographer = videoComponents.count > 1 ? videoComponents[1] : ""
             setNewVideo(path: newVideoPath, photographer: photographer)
         }
    }

     func setNewVideo(path: String, photographer: String) {
        if showSecondVideo {
//            DispatchQueue.main.async {
                gStateObjects[index]!.firstVideoPath = path
                firstVideoPath = path
                firstPhotographer = photographer
//            }
        } else {
//            DispatchQueue.main.async {
                gStateObjects[index]!.secondVideoPath = path
                secondVideoPath = path
                secondPhotographer = photographer
//            }
        }
        startShowVideo = false
        manageVideoDisplay()
    }

     func manageVideoDisplay() {
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
    }

     func handleImage(_ path: String) {
        guard let nsImage = NSImage(contentsOfFile: path) else {
            gImageAndVideoNames = loadImageAndVideoNames()
            loadingImage = true
            return
        }

        let photographer = path.contains("/pexels/") ? extractNameFromFilePath(filePath: path) : ""
        manageImageDisplay(path: path, nsImage: nsImage, photographer: photographer)
    }

     func manageImageDisplay(path: String, nsImage: NSImage, photographer: String) {
        startShowImage = false
        showSecondImage.toggle()
        DispatchQueue.main.async {
            manageVideoToImageTransition()
            loadingImage = true
            if showSecondImage {
                setFirstImage(path: path, nsImage: nsImage, photographer: photographer)
            } else {
                setSecondImage(path: path, nsImage: nsImage, photographer: photographer)
            }
            showSecondImage.toggle()
            loadingImage = false
        }
    }

     func manageVideoToImageTransition() {
        if showVideo {
            startShowImage = true
            startChangeTimer(addTime: 3)
            showVideo = false
        }
    }

     func setFirstImage(path: String, nsImage: NSImage, photographer: String) {
        firstImagePath = path
        firstImage = nsImage
        firstPhotographer = photographer
    }

     func setSecondImage(path: String, nsImage: NSImage, photographer: String) {
        secondImagePath = path
        secondImage = nsImage
        secondPhotographer = photographer
    }

    func extractNameFromFilePath(filePath: String) -> String {
        let components = filePath.components(separatedBy: "/")
        if let pexelsIndex = components.firstIndex(of: "pexels"),
           components.count > pexelsIndex + 1 {
            let fileName = components[pexelsIndex + 1]
            let nameComponents = fileName.components(separatedBy: "_")
            guard nameComponents.count > 0 else { return "" }
            return nameComponents[0]
        }
        return ""
    }

    func handlePexelsVideos() {
        iPrint("handlePexelsVideos: \(index)")
        if useVideosFromPexels,
           let pexelsDirectoryUrl = pexelsDirectoryUrl {
            getPexelsVideoList(pexelsFolder: pexelsDirectoryUrl, appDelegate: appDelegate) { videosList in
                DispatchQueue.main.async {
                    appDelegate.pexelsVideos = videosList
                    appDelegate.loadImagesAndVideos.toggle()
                }
            }
        }
    }

    func handlePexelsPhotos() {
        iPrint("handlePexelsPhotos: \(index) usePhotosFromPexels: \(usePhotosFromPexels)")
        if usePhotosFromPexels,
           let pexelsDirectoryUrl = pexelsDirectoryUrl {
            appDelegate.pexelsPhotos = loadImageAndVideoNames(fromPexelsPhotos: pexelsDirectoryUrl)
            DispatchQueue.global().async {
                pexelDownloadSemaphore.wait()
                if appDelegate.pexelsPhotos.count < 2 {
                    downloadPexelPhotos(pexelsFolder: pexelsDirectoryUrl, appDelegate: appDelegate) {
                        appDelegate.pexelsPhotos = loadImageAndVideoNames(fromPexelsPhotos: pexelsDirectoryUrl)
                        pexelDownloadSemaphore.signal()
                        if !useVideosFromPexels {
                            appDelegate.loadImagesAndVideos.toggle()
                        }
                    }
                } else {
                    pexelDownloadSemaphore.signal()
                }
            }
        }
    }

    func stopChangeTimer () {
        iPrint("stopChangeTimer \(index)")
        imageOrBackgroundChangeTimer?.invalidate()
        imageOrBackgroundChangeTimer = nil
    }

    func hideApp() {
        iPrint("hideApp \(index)")
        watchTimerIsActive = false
        stopChangeTimer()
        stopMonitoringUserInput()
        if index == 0 {
            WindowManager.shared.exitFullScreen()
        }
    }

    func startWatchingFolder(imageFolder: String) {
        if index > 0 {
            return
        }
        gDirectoryWatcher?.release()
        gDirectoryWatcher = nil
        do {
            try gDirectoryWatcher = DirectoryWatcher(directoryPath: imageFolder) {
                scheduleImageLoad()
            }
        } catch let error {
            iPrint("failed to watch directory: \(imageFolder) - \(error.localizedDescription)")
        }
    }

    func scheduleImageLoad() {
        // Cancel the previous work item if it's still pending
        loadImagesWorkItem?.cancel()

        // Schedule a new one
        let workItem = DispatchWorkItem {
            gImageAndVideoNames = loadImageAndVideoNames()
        }
        loadImagesWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    func loadImageAndVideoNames(fromPexelsPhotos: URL? = nil) -> [String] {
        startShowVideo = false //?
        if index > 0 {
            switch true {
                case fromPexelsPhotos != nil: return appDelegate.pexelsPhotos
                default:
                    setImageOrVideoMode()
                    return gImageAndVideoNames
            }
        }
        iPrint("loadImageNames: \(index) fromPexel: \(fromPexelsPhotos?.absoluteString ?? "")")
        let imageFolder = selectedFolderPath

        let folderURL = fromPexelsPhotos == nil ? URL(fileURLWithPath: imageFolder) : fromPexelsPhotos!
        let fileManager = FileManager.default
        var imageOrVideoNames: [String] = []
        gImageAndVideoNames.removeAll()
        do {
            let contents = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            imageOrVideoNames = contents.compactMap { url -> String? in
                guard let typeIdentifier = try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier,
                      let uti = UTType(typeIdentifier) else {
                    return nil
                }

                if uti.conforms(to: .image) || uti.conforms(to: .movie) {
                    return url.lastPathComponent
                }
                return nil
            }

            let folderString = folderURL.path
            imageOrVideoNames = imageOrVideoNames.map { imageOrVideo in
                folderString + "/" + imageOrVideo
            }

            let numberOfLocalImagesAndVideos = imageOrVideoNames.count
            if fromPexelsPhotos == nil {
                DispatchQueue.main.async {
                    appDelegate.numberOfLocalImagesAndVideos = numberOfLocalImagesAndVideos
                    appDelegate.numberOfPexelsPhotos = appDelegate.pexelsPhotos.count
                    appDelegate.numberOfPexelsVideos = appDelegate.pexelsVideos.count
                }
            }

            if fromPexelsPhotos == nil {
                imageOrVideoNames.append(contentsOf: appDelegate.pexelsPhotos)
                iPrint("pexelImages: \(index) \(appDelegate.pexelsPhotos.count)")
                imageOrVideoNames.append(contentsOf: appDelegate.pexelsVideos)
                iPrint("pexelVideos: \(index) \(appDelegate.pexelsVideos.count)")
            }
        } catch {
            iPrint("Error loading image names: \(error)")
        }
        DispatchQueue.main.async {
            appDelegate.setImageOrVideoModeToggle.toggle()
        }
        return imageOrVideoNames
    }

    func setImageOrVideoMode(_ value: Bool = true) {
        imageOrVideoMode = gImageAndVideoNames.count > 2
        if !imageOrVideoMode {
            firstImage = nil
            secondImage = nil
            gStateObjects[index]!.firstVideoPath = ""
            gStateObjects[index]!.secondVideoPath = ""
        }
    }
}
