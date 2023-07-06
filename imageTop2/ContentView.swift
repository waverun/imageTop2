import SwiftUI
import UniformTypeIdentifiers
import AppKit
import GameplayKit
import HotKey

//var gShowWatch = true

class StateObjectVariables: ObservableObject {
    @Published var firstVideoPath = ""
    @Published var secondVideoPath = ""
    @Published var viewAppeared = false
//    @Published var loadImagesAndVideos = false
    @Published var ignoreFirstLoadImagesAndVideos = true
}

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

    @StateObject var stateObject = StateObjectVariables()

    @State  var directoryWatcher: DirectoryWatcher?

    //    @State var eventMonitor: Any?

    @EnvironmentObject var appDelegate: AppDelegate

    @State  var loadingImage = true

    @State var firstImage: NSImage? = nil
    @State var secondImage: NSImage? = nil
    @State var firstImagePath = ""
    @State var secondImagePath = ""
    @State var firstPhotographer = ""
    @State var secondPhotographer = ""
    @State var showVideo = false

//    @State var stateObject.firstVideoPath = ""
//    @State var stateObject.secondVideoPath = ""
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
    @AppStorage("useVideosFromPexels") var useVideosFromPexels: Bool = true

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
                debugPrint("Error creating pexels directory: \(error)")
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
                backgroundView
                videoPlayerView
                imageView
                if index == 0 {
                    DigitalWatchView(x: x, y: y)
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
        .onChange(of: usePhotosFromPexels, perform: handleUsePhotosFromPexelsChange)
        .onChange(of: useVideosFromPexels, perform: handleUseVideosFromPexelsChange)
        .onDisappear(perform: onDisappearAction)
        .onReceive(appDelegate.$showWindow, perform: handleShowWindowChange)
        .onReceive(appDelegate.$startTimer, perform: handleStartTimerChange)
        .onReceive(appDelegate.$loadImagesAndVideos, perform: handleLoadImagesAndVideosChange)
        .onReceive(appDelegate.$networkIsReachable, perform: handleNetworkReachabilityChange)
    }

    var backgroundView: some View {
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

    var videoPlayerView: some View {
        ZStack {
            videoPlayerBuilder(videoPath: stateObject.firstVideoPath, photographer: firstPhotographer, condition: showVideo && !showSecondVideo)
            videoPlayerBuilder(videoPath: stateObject.secondVideoPath, photographer: secondPhotographer, condition: showVideo && showSecondVideo)
        }
    }

    func videoPlayerBuilder(videoPath: String, photographer: String, condition: Bool) -> some View {
        if videoPath != "",
           let url = videoPath.starts(with: "https:") ? URL(string: videoPath) : URL(fileURLWithPath: videoPath) {
            return AnyView(
                VideoPlayerView(url: url, index: index) {
                    changeScreenImageVideoOrColor()
                }
                    .opacity(condition ? 1 : 0)
                    .animation(.easeIn(duration: condition ? 4 : 4), value: condition)
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
                                    .animation(.easeIn(duration: condition ? 4 : 4), value: condition)
                                Spacer()
                            }
                        }
                    )
            )
        } else {
            return AnyView(EmptyView())
        }
    }

//    var videoPlayerView: some View {
//        ZStack {
//            if stateObject.firstVideoPath != "",
//               let url = stateObject.firstVideoPath.starts(with: "https:") ? URL(string: stateObject.firstVideoPath) : URL(fileURLWithPath: stateObject.firstVideoPath) {
//                VideoPlayerView(url: url, index: index) {
//                    changeScreenImageVideoOrColor()
//                }
//                .opacity(showVideo && !showSecondVideo ? 1 : 0)
//                .animation(.easeIn(duration: showVideo && !showSecondVideo ? 4 : 4), value: showVideo && !showSecondVideo)
//                .edgesIgnoringSafeArea(.all)
//                .overlay(
//                    VStack {
//                        Spacer()
//                        HStack {
//                            Text(firstPhotographer)
//                                .foregroundColor(.white)
//                                .font(.custom("Noteworthy", size: 20))
//                                .shadow(color: .black, radius: 3, x: 0, y: 0)
//                                .padding(.bottom, 50)
//                                .padding(.leading, 50)
//                                .opacity(showVideo && !showSecondVideo ? 1 : 0)
//                                .animation(.easeIn(duration: showVideo && !showSecondVideo ? 4 : 4), value: showVideo && !showSecondVideo)
//                            Spacer()
//                        }
//                    }
//                )
//            }
//
//            if stateObject.secondVideoPath != "",
//               let url = stateObject.secondVideoPath.starts(with: "https:") ? URL(string: stateObject.secondVideoPath) : URL(fileURLWithPath: stateObject.secondVideoPath) {
//                VideoPlayerView(url: url, index: index) {
//                    changeScreenImageVideoOrColor()
//                }
//                .opacity(showVideo && showSecondVideo ? 1 : 0)
//                .animation(.easeIn(duration: showVideo && showSecondVideo ? 4 : 4), value: showVideo && showSecondVideo)
//                .edgesIgnoringSafeArea(.all)
//                .overlay(
//                    VStack {
//                        Spacer()
//                        HStack {
//                            Text(secondPhotographer)
//                                .foregroundColor(.white)
//                                .font(.custom("Noteworthy", size: 20))
//                                .shadow(color: .black, radius: 3, x: 0, y: 0)
//                                .padding(.bottom, 50)
//                                .padding(.leading, 50)
//                                .opacity(showVideo && showSecondVideo ? 1 : 0)
//                                .animation(.easeIn(duration: showVideo && showSecondVideo ? 4 : 4), value: showVideo && showSecondVideo)
//                            Spacer()
//                        }
//                    }
//                )
//            }
//        }
//    }

    var imageView: some View {
        ZStack {
            imageViewBuilder(image: firstImage, photographer: firstPhotographer, condition: !(showSecondImage || showVideo || loadingImage))
            imageViewBuilder(image: secondImage, photographer: secondPhotographer, condition: showSecondImage && !showVideo && !loadingImage)

            if index == 0 {
                DigitalWatchView(x: x, y: y)
            }
        }
    }

    func imageViewBuilder(image: NSImage?, photographer: String, condition: Bool) -> some View {
        if let image = image {
            return AnyView(
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
                                    .animation(.linear(duration: startShowVideo ? 4 : 1), value: condition)
                                Spacer()
                            }
                        }
                    )
                    .opacity(condition ? 1 : 0)
                    .animation(.linear(duration: startShowVideo ? 4 : 1), value: condition)
            )
        } else {
            return AnyView(Color.clear)
        }
    }

//    var imageView: some View {
//        ZStack {
//            if let image = firstImage {
//                Image(nsImage: image)
//                    .resizable()
//                    .clipped()
//                    .edgesIgnoringSafeArea(.all)
//                    .overlay(
//                        VStack {
//                            Spacer()
//                            HStack {
//                                Text(firstPhotographer)
//                                    .foregroundColor(.white)
//                                    .font(.custom("Noteworthy", size: 20))
//                                    .shadow(color: .black, radius: 3, x: 0, y: 0)
//                                    .padding(.bottom, 50)
//                                    .padding(.leading, 50)
//                                    .opacity(showSecondImage || showVideo || loadingImage ? 0 : 1)
//                                    .animation(.linear(duration: startShowVideo ? 4 : 1), value: showSecondImage || showVideo || loadingImage)
//                                Spacer()
//                            }
//                        }
//                    )
//                    .opacity(showSecondImage || showVideo || loadingImage ? 0 : 1)
//                    .animation(.linear(duration: startShowVideo ? 4 : 1), value: showSecondImage || showVideo || loadingImage)
//            } else {
//                Color.clear
//            }
//
//            if let image = secondImage {
//                Image(nsImage: image)
//                    .resizable()
//                    .clipped()
//                    .edgesIgnoringSafeArea(.all)
//                    .overlay(
//                        VStack {
//                            Spacer()
//                            HStack {
//                                Text(secondPhotographer)
//                                    .foregroundColor(.white)
//                                    .font(.custom("Noteworthy", size: 20))
//                                    .shadow(color: .black, radius: 3, x: 0, y: 0)
//                                    .padding(.bottom, 50)
//                                    .padding(.leading, 50)
//                                    .opacity(showSecondImage && !showVideo && !loadingImage ? 1 : 0)
//                                    .animation(.linear(duration: startShowVideo ? 4 : 1), value: showSecondImage && !showVideo && !loadingImage)
//                                Spacer()
//                            }
//                        }
//                    )
//                    .opacity(showSecondImage && !showVideo && !loadingImage ? 1 : 0)
//                    .animation(.linear(duration: startShowVideo ? 4 : 1), value: showSecondImage && !showVideo && !loadingImage)
//            }  else {
//                Color.clear
//            }
//            if index == 0 {
//                DigitalWatchView(x: x, y: y)
//            }
//        }
//    }

    func onAppearAction() {
        debugPrint("onAppear: \(index)")
        guard !stateObject.viewAppeared else { return }
        stateObject.viewAppeared = true
        debugPrint("inside onAppear: \(index)")
        backgroundColor = randomGentleColor()

        startAccessingFolder()

        updateHotKey()

        if !usePhotosFromPexels, !useVideosFromPexels {
            imageAndVideoNames = loadImageAndVideoNames()
        }

        if index == 0 {
            handlePexelsPhotos()
            handlePexelsVideos()
        }
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

    func handleUsePhotosFromPexelsChange(_ newValue: Bool) {
        if newValue {
            if index == 0 {
                handlePexelsPhotos()
            }
        } else {
            if let pexelsDirectoryUrl = pexelsDirectoryUrl {
                clearPexelPhotos(folderPath: pexelsDirectoryUrl.path, filesToKeep: [".imageTop", "videoList.txt"])
                appDelegate.pexelsPhotos = []
                imageAndVideoNames = loadImageAndVideoNames()
                //                    appDelegate.loadImages.toggle()
            }
        }
    }

    func handleUseVideosFromPexelsChange(_ newValue: Bool) {
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

    func onDisappearAction() {
        debugPrint("before onDisapear")
        //            timer?.invalidate()
        resetWatchPosition()
        stopChangeTimer()
        if let url = URL(string: selectedFolderPath) {
            url.stopAccessingSecurityScopedResource()
        }
        debugPrint("after onDisapear")
    }

    func handleShowWindowChange(showWindow: Bool) {
        debugPrint("received showWindow \(showWindow) \(index)")
        if showWindow {
            showApp()
        } else {
            hideApp()
        }
    }

    func handleStartTimerChange(_ value: Bool) {
        if !showVideo {
            startScreenChangeTimer()
            //                changeScreenImageVideoOrColor()
        }
        startMonitoringUserInput()
    }

    func handleLoadImagesAndVideosChange(_ value: Bool) {
        debugPrint("loadImagesAndVideos: \(index)")
        if stateObject.ignoreFirstLoadImagesAndVideos {
            stateObject.ignoreFirstLoadImagesAndVideos = false
            return
        }
        if index > 0 && usePhotosFromPexels {
            appDelegate.pexelsPhotos = loadImageAndVideoNames(fromPexel: pexelsDirectoryUrl)
        }
        imageAndVideoNames = loadImageAndVideoNames()
    }

    func handleNetworkReachabilityChange(_ value: Bool) {
        debugPrint("onReceive \(index) gNetworkIsReachable: \(gNetworkIsReachable) imageOrBackgroundChangeTimer == nil:   \(imageOrBackgroundChangeTimer == nil)")
        showAccordingToNetworkReachability()
    }

//    var body: some View {
//        GeometryReader { geometry in
//            ZStack {
//                backgroundColor
//                    .opacity(showFadeColor ? 0 : 1)
//                    .animation(.linear(duration: 1), value: showFadeColor)
//                    .edgesIgnoringSafeArea(.all)
//                fadeColor
//                    .opacity(showFadeColor ? 1 : 0)
//                    .animation(.linear(duration: 1), value: showFadeColor)
//                    .edgesIgnoringSafeArea(.all)
//
//                if stateObject.firstVideoPath != "",
//                   let url = stateObject.firstVideoPath.starts(with: "https:") ? URL(string: stateObject.firstVideoPath) : URL(fileURLWithPath: stateObject.firstVideoPath) {
//                    VideoPlayerView(url: url, index: index) {
//                        changeScreenImageVideoOrColor()
//                    }
//                    .opacity(showVideo && !showSecondVideo ? 1 : 0)
//                    .animation(.easeIn(duration: showVideo && !showSecondVideo ? 4 : 4), value: showVideo && !showSecondVideo)
//                    .edgesIgnoringSafeArea(.all)
//                    .overlay(
//                        VStack {
//                            Spacer()
//                            HStack {
//                                Text(firstPhotographer)
//                                    .foregroundColor(.white)
//                                    .font(.custom("Noteworthy", size: 20))
//                                    .shadow(color: .black, radius: 3, x: 0, y: 0)
//                                    .padding(.bottom, 50)
//                                    .padding(.leading, 50)
//                                    .opacity(showVideo && !showSecondVideo ? 1 : 0)
//                                    .animation(.easeIn(duration: showVideo && !showSecondVideo ? 4 : 4), value: showVideo && !showSecondVideo)
//                                Spacer()
//                            }
//                        }
//                    )
//                }
//
//                if stateObject.secondVideoPath != "",
//                   let url = stateObject.secondVideoPath.starts(with: "https:") ? URL(string: stateObject.secondVideoPath) : URL(fileURLWithPath: stateObject.secondVideoPath) {
//                    VideoPlayerView(url: url, index: index) {
//                        changeScreenImageVideoOrColor()
//                    }
//                    .opacity(showVideo && showSecondVideo ? 1 : 0)
//                    .animation(.easeIn(duration: showVideo && showSecondVideo ? 4 : 4), value: showVideo && showSecondVideo)
//                    .edgesIgnoringSafeArea(.all)
//                    .overlay(
//                        VStack {
//                            Spacer()
//                            HStack {
//                                Text(secondPhotographer)
//                                    .foregroundColor(.white)
//                                    .font(.custom("Noteworthy", size: 20))
//                                    .shadow(color: .black, radius: 3, x: 0, y: 0)
//                                    .padding(.bottom, 50)
//                                    .padding(.leading, 50)
//                                    .opacity(showVideo && showSecondVideo ? 1 : 0)
//                                    .animation(.easeIn(duration: showVideo && showSecondVideo ? 4 : 4), value: showVideo && showSecondVideo)
//                                Spacer()
//                            }
//                        }
//                    )
//                }
//
//                if let image = firstImage {
//                    Image(nsImage: image)
//                        .resizable()
//                        .clipped()
//                        .edgesIgnoringSafeArea(.all)
//                        .overlay(
//                            VStack {
//                                Spacer()
//                                HStack {
//                                    Text(firstPhotographer)
//                                        .foregroundColor(.white)
//                                        .font(.custom("Noteworthy", size: 20))
//                                        .shadow(color: .black, radius: 3, x: 0, y: 0)
//                                        .padding(.bottom, 50)
//                                        .padding(.leading, 50)
//                                        .opacity(showSecondImage || showVideo || loadingImage ? 0 : 1)
//                                        .animation(.linear(duration: startShowVideo ? 4 : 1), value: showSecondImage || showVideo || loadingImage)
//                                    Spacer()
//                                }
//                            }
//                        )
//                        .opacity(showSecondImage || showVideo || loadingImage ? 0 : 1)
//                        .animation(.linear(duration: startShowVideo ? 4 : 1), value: showSecondImage || showVideo || loadingImage)
//                } else {
//                    Color.clear
//                }
//
//                if let image = secondImage {
//                    Image(nsImage: image)
//                        .resizable()
//                        .clipped()
//                        .edgesIgnoringSafeArea(.all)
//                        .overlay(
//                            VStack {
//                                Spacer()
//                                HStack {
//                                    Text(secondPhotographer)
//                                        .foregroundColor(.white)
//                                        .font(.custom("Noteworthy", size: 20))
//                                        .shadow(color: .black, radius: 3, x: 0, y: 0)
//                                        .padding(.bottom, 50)
//                                        .padding(.leading, 50)
//                                        .opacity(showSecondImage && !showVideo && !loadingImage ? 1 : 0)
//                                        .animation(.linear(duration: startShowVideo ? 4 : 1), value: showSecondImage && !showVideo && !loadingImage)
//                                    Spacer()
//                                }
//                            }
//                        )
//                        .opacity(showSecondImage && !showVideo && !loadingImage ? 1 : 0)
//                        .animation(.linear(duration: startShowVideo ? 4 : 1), value: showSecondImage && !showVideo && !loadingImage)
//                }  else {
//                    Color.clear
//                }
//                if index == 0 {
//                    DigitalWatchView(x: x, y: y)
//                }
//            }
//        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
//        .onChange(of: replaceImageAfter) { newValue in
//            resetImageOrBackgroundChangeTimer()
//        }
//        .onAppear {
//            debugPrint("onAppear: \(index)")
//            guard !stateObject.viewAppeared else { return }
//            stateObject.viewAppeared = true
//            debugPrint("inside onAppear: \(index)")
//            backgroundColor = randomGentleColor()
//
//            startAccessingFolder()
//
//            updateHotKey()
//
//            if !usePhotosFromPexels, !useVideosFromPexels {
//                imageAndVideoNames = loadImageAndVideoNames()
//            }
//
//            if index == 0 {
//                handlePexelsPhotos()
//                handlePexelsVideos()
//            }
//        }
//        .onChange(of: hotKeyString) { _ in
//            updateHotKey()
//        }
//        .onChange(of: keyString1) { _ in
//            updateHotKey()
//        }
//        .onChange(of: keyString2) { _ in
//            updateHotKey()
//        }
//        .onChange(of: selectedFolderPath) { _ in
//            startAccessingFolder()
//            startWatchingFolder(imageFolder: selectedFolderPath)
//        }
//        .onChange(of: usePhotosFromPexels) { newValue in
//            if newValue {
//                if index == 0 {
//                    handlePexelsPhotos()
//                }
//            } else {
//                if let pexelsDirectoryUrl = pexelsDirectoryUrl {
//                    clearPexelPhotos(folderPath: pexelsDirectoryUrl.path, filesToKeep: [".imageTop", "videoList.txt"])
//                    appDelegate.pexelsPhotos = []
//                    imageAndVideoNames = loadImageAndVideoNames()
//                    //                    appDelegate.loadImages.toggle()
//                }
//            }
//        }
//        .onChange(of: useVideosFromPexels) { newValue in
//            if newValue {
//                if index == 0 {
//                    handlePexelsVideos()
//                }
//            } else {
//                if let pexelsDirectoryUrl = pexelsDirectoryUrl {
//                    clearPexelVideos(folderURL: pexelsDirectoryUrl, fileName: "videoList.txt")
//                    appDelegate.pexelsVideos = []
//                    imageAndVideoNames = loadImageAndVideoNames()
//                    //                    appDelegate.loadImages.toggle()
//                }
//            }
//        }
//        .onDisappear {
//            debugPrint("before onDisapear")
//            //            timer?.invalidate()
//            resetWatchPosition()
//            stopChangeTimer()
//            if let url = URL(string: selectedFolderPath) {
//                url.stopAccessingSecurityScopedResource()
//            }
//            debugPrint("after onDisapear")
//        }
//        .onReceive(appDelegate.$showWindow, perform: { showWindow in
//            debugPrint("received showWindow \(showWindow) \(index)")
//            if showWindow {
//                showApp()
//            } else {
//                hideApp()
//            }
//        })
//        .onReceive(appDelegate.$startTimer, perform: { _ in
//            if !showVideo {
//                startScreenChangeTimer()
////                changeScreenImageVideoOrColor()
//            }
//            startMonitoringUserInput()
//        })
//        .onReceive(appDelegate.$loadImagesAndVideos, perform: { _ in
//            debugPrint("loadImagesAndVideos: \(index)")
//            if stateObject.ignoreFirstLoadImagesAndVideos {
//                stateObject.ignoreFirstLoadImagesAndVideos = false
//                return
//            }
//            if index > 0 && usePhotosFromPexels {
//                appDelegate.pexelsPhotos = loadImageAndVideoNames(fromPexel: pexelsDirectoryUrl)
//            }
//            imageAndVideoNames = loadImageAndVideoNames()
//        })
//        .onReceive(appDelegate.$networkIsReachable, perform: { _ in
//            debugPrint("onReceive \(index) gNetworkIsReachable: \(gNetworkIsReachable) imageOrBackgroundChangeTimer == nil:   \(imageOrBackgroundChangeTimer == nil)")
//            showAccordingToNetworkReachability()
//        })
//    }

    func showAccordingToNetworkReachability () {
        let showingVideos = imageAndVideoNames.contains(where: { imageOrVideo in
            imageOrVideo.starts(with: "https:")
        })

        switch true {

            case !showingVideos:

                networkIsReachableOrNotShowingVideos = true
                return

            case gNetworkIsReachable:

                networkIsReachableOrNotShowingVideos = true
                imageOrVideoMode = imageAndVideoNames.count > 2

            default:

                networkIsReachableOrNotShowingVideos = false
                showVideo = false
                if imageOrVideoMode {
                    firstImage = nil
                    secondImage = nil
                    stateObject.firstVideoPath = ""
                    stateObject.secondVideoPath = ""
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
            debugPrint("in startMonitoringUserInput showWindow: \(appDelegate.showWindow)")
            //            self.hideApp()
//            stateObject.firstVideoPath = ""
//            stateObject.secondVideoPath = ""
            if !appDelegate.ignoreMonitor {
//                for player in gPlayers.enumerated() {
//                    player.element.value.pause()
//                    WindowManager.shared.windows[player.offset].orderOut(nil)
//                }
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

    func startAccessingFolder(loadImages: Bool? = nil) {
        if let bookmarkData = imageTopFolderBookmarkData {
            do {
                var isStale = false
                let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
                if isStale {
                    debugPrint("Bookmark data is stale")
                } else {
                    if url.startAccessingSecurityScopedResource() {
                        debugPrint("Successfully accessed security-scoped resource")
                        if let loadImages = loadImages,
                           loadImages {
                            imageAndVideoNames = loadImageAndVideoNames()
                        }
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
            debugPrint("video1 play: \(index) \(index) stateObject.firstVideoPath: \(stateObject.firstVideoPath) stateObject.secondVideoPath: \(stateObject.secondVideoPath)")
            player.play()
            if let timer = gTimers[index] {
                timer.resume()
            }
        }
    }

    func hotkeyPressed() {
        debugPrint("hotkey pressed")
        //        showApp()
//        appDelegate.showWindow = true
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
            debugPrint("firstsettime changeScreenImageOrColor \(index)")
            changeScreenImageVideoOrColor()
        }

        debugPrint("startScreenChangeTimer: \(index) \(Date())")

        imageOrBackgroundChangeTimer = Timer.scheduledTimer(withTimeInterval: replaceImageAfter, repeats: true) { [self] _ in
            debugPrint("imageOrBackgroundChangeTimer: \(index) \(Date())")
            changeScreenImageVideoOrColor()
        }
    }

    func changeScreenImageVideoOrColor() {
        debugPrint("changeScreenImageOrColor \(index) imageOrVideoMode: \(imageOrVideoMode) gNetworkIsReachable: \(gNetworkIsReachable)")
        _ = imageOrVideoMode && networkIsReachableOrNotShowingVideos ? loadRandomImageOrVideo() : changeBackgroundColor()
    }

    func loadRandomImageOrVideo() {
        debugPrint("video loadRandomImageOrVideo \(index) appDelegate.showWindow: \(appDelegate.showWindow)")

        DispatchQueue.global(qos: .userInitiated).async {
            if let newRandomImageOrVideoPath = self.generateRandomPath() {
                if self.isVideo(newRandomImageOrVideoPath) {
                    self.handleVideo(newRandomImageOrVideoPath)
                } else {
                    self.handleImage(newRandomImageOrVideoPath)
                }
            }
        }
    }

    private func generateRandomPath() -> String? {
        var newRandomImageOrVideoPath = ""
        repeat {
            if let newRandomImageName = imageAndVideoNames.randomElement() {
                newRandomImageOrVideoPath = "\(newRandomImageName)"
            }
        } while self.shouldRegeneratePath(newRandomImageOrVideoPath)
        return newRandomImageOrVideoPath
    }

    private func shouldRegeneratePath(_ path: String) -> Bool {
        return (path == firstImagePath && !showSecondImage)
        || (path == secondImagePath && showSecondImage)
        || (path == stateObject.firstVideoPath)
        || (path == stateObject.secondVideoPath)
    }

    private func isVideo(_ path: String) -> Bool {
        return path.starts(with: "https:") || isVideoFile(atPath: path)
    }

    private func handleVideo(_ path: String) {
        debugPrint("isVideFile: \(index) newRandomImageOrVideoPath: \(path)")
        let videoComponents = path.components(separatedBy: ",")
        let newVideoPath = videoComponents[0]
        let photographer = videoComponents.count > 1 ? videoComponents[1] : ""
        setNewVideo(path: newVideoPath, photographer: photographer)
    }

    private func setNewVideo(path: String, photographer: String) {
        if showSecondVideo {
            DispatchQueue.main.async {
                stateObject.firstVideoPath = path
                firstPhotographer = photographer
            }
        } else {
            DispatchQueue.main.async {
                stateObject.secondVideoPath = path
                secondPhotographer = photographer
            }
        }
        startShowVideo = false
        manageVideoDisplay()
    }

    private func manageVideoDisplay() {
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

    private func handleImage(_ path: String) {
        guard let nsImage = NSImage(contentsOfFile: path) else {
            imageAndVideoNames = loadImageAndVideoNames()
            loadingImage = true
            return
        }

        let photographer = path.contains("/pexels/") ? extractNameFromFilePath(filePath: path) : ""
        manageImageDisplay(path: path, nsImage: nsImage, photographer: photographer)
    }

    private func manageImageDisplay(path: String, nsImage: NSImage, photographer: String) {
        self.showSecondImage.toggle()
        startShowImage = false
        DispatchQueue.main.async {
            self.manageVideoToImageTransition()
            self.loadingImage = true
            if showSecondImage {
                self.setFirstImage(path: path, nsImage: nsImage, photographer: photographer)
            } else {
                self.setSecondImage(path: path, nsImage: nsImage, photographer: photographer)
            }
            self.showSecondImage.toggle()
            self.loadingImage = false
        }
    }

    private func manageVideoToImageTransition() {
        if showVideo {
            startShowImage = true
            startScreenChangeTimer()
            showVideo = false
        }
    }

    private func setFirstImage(path: String, nsImage: NSImage, photographer: String) {
        self.firstImagePath = path
        self.firstImage = nsImage
        self.firstPhotographer = photographer
    }

    private func setSecondImage(path: String, nsImage: NSImage, photographer: String) {
        self.secondImagePath = path
        self.secondImage = nsImage
        self.secondPhotographer = photographer
    }

    private func extractNameFromFilePath(filePath: String) -> String {
        let components = filePath.components(separatedBy: "/")
        if let pexelsIndex = components.firstIndex(of: "pexels") {
            let fileName = components[pexelsIndex + 1]
            let nameComponents = fileName.components(separatedBy: "_")
            return nameComponents[0]
        }
        return ""
    }

//    func loadRandomImageOrVideo() {
//        func extractNameFromFilePath(filePath: String) -> String {
//            let components = filePath.components(separatedBy: "/")
//            if let pexelsIndex = components.firstIndex(of: "pexels") {
//                let fileName = components[pexelsIndex + 1]
//                let nameComponents = fileName.components(separatedBy: "_")
//                return nameComponents[0]
//            }
//            return ""
//        }
//
//        debugPrint("video loadRandomImageOrVideo \(index) appDelegate.showWindow: \(appDelegate.showWindow)")
//
//        DispatchQueue.global(qos: .userInitiated).async {
//            var newRandomImageOrVideoPath = ""
//            repeat {
//                if let newRandomImageName = imageAndVideoNames.randomElement() {
//                    newRandomImageOrVideoPath = "\(newRandomImageName)"
//                }
//            } while (newRandomImageOrVideoPath == firstImagePath && !showSecondImage)
//            || (newRandomImageOrVideoPath == secondImagePath && showSecondImage)
//            || (newRandomImageOrVideoPath == stateObject.firstVideoPath)
//            || (newRandomImageOrVideoPath == stateObject.secondVideoPath)
//
//            debugPrint("video newRandoImage \(index) \(newRandomImageOrVideoPath)")
//
//            if newRandomImageOrVideoPath.starts(with: "https:")
//            || isVideoFile(atPath: newRandomImageOrVideoPath) {
//                debugPrint("isVideFile: \(index) newRandomImageOrVideoPath: \(newRandomImageOrVideoPath)")
//                let videoComponents = newRandomImageOrVideoPath.components(separatedBy: ",")
//                var photographer = ""
//                newRandomImageOrVideoPath = videoComponents[0]
//                if videoComponents.count > 1 {
//                    photographer = videoComponents[1]
//                }
//                if showSecondVideo {
//                    DispatchQueue.main.async {
//                        stateObject.firstVideoPath = newRandomImageOrVideoPath
//                        firstPhotographer = photographer
//                    }
//                } else {
//                    DispatchQueue.main.async {
//                        stateObject.secondVideoPath = newRandomImageOrVideoPath
//                        secondPhotographer = photographer
//                    }
//                }
//                startShowVideo = false
//                if !showVideo {
//                    stopChangeTimer()
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//                        startShowVideo = true
//                        showVideo = true
//                        showSecondVideo.toggle()
//                    }
//                } else {
//                    showSecondVideo.toggle()
//                }
//                return
//            }
//
//            guard let nsImage = NSImage(contentsOfFile: newRandomImageOrVideoPath)
//            else {
//                imageAndVideoNames = loadImageAndVideoNames()
//                loadingImage = true
//                return
//            }
//
//            var photographer = ""
//            if newRandomImageOrVideoPath.contains("/pexels/") {
//                photographer = extractNameFromFilePath(filePath: newRandomImageOrVideoPath)
//            }
//
//            self.showSecondImage.toggle()
//            startShowImage = false
//            DispatchQueue.main.async {
//                if showVideo {
//                    startShowImage = true
//                    startScreenChangeTimer()
//                    showVideo = false
//                }
//                self.loadingImage = true
//                if showSecondImage {
//                    self.firstImagePath = newRandomImageOrVideoPath
//                    self.firstImage = nsImage
//                    self.firstPhotographer = photographer
//                } else {
//                    self.secondImagePath = newRandomImageOrVideoPath
//                    self.secondImage = nsImage
//                    self.secondPhotographer = photographer
//                }
//                self.showSecondImage.toggle()
//                self.loadingImage = false
//            }
//        }
//    }

    func handlePexelsVideos() {
        debugPrint("handlePexelsVideos: \(index)")
        if useVideosFromPexels,
           let pexelsDirectoryUrl = pexelsDirectoryUrl {
            getPexelsVideoList(pexelsFolder: pexelsDirectoryUrl) { videosList in
                DispatchQueue.main.async {
                    appDelegate.pexelsVideos = videosList
                    appDelegate.loadImagesAndVideos.toggle()
                }
            }
        }
    }

    func handlePexelsPhotos() {
        debugPrint("handlePexelsPhotos: \(index) usePhotosFromPexels: \(usePhotosFromPexels)")
        if usePhotosFromPexels,
           let pexelsDirectoryUrl = pexelsDirectoryUrl {
            appDelegate.pexelsPhotos = loadImageAndVideoNames(fromPexel: pexelsDirectoryUrl)
            DispatchQueue.global().async {
                pexelDownloadSemaphore.wait()
                if appDelegate.pexelsPhotos.count == 0 {
                    downloadPexelPhotos(pexelsFolder: pexelsDirectoryUrl) {
                        appDelegate.pexelsPhotos = loadImageAndVideoNames(fromPexel: pexelsDirectoryUrl)
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
        debugPrint("stopChangeTimer \(index)")
        imageOrBackgroundChangeTimer?.invalidate()
        imageOrBackgroundChangeTimer = nil
    }

    func hideApp() {
        debugPrint("hideApp \(index)")
//        gPlayers[index]?.pause()
//        WindowManager.shared.windows[index].orderOut(nil)
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
            debugPrint("failed to watch directory: \(imageFolder) - \(error.localizedDescription)")
        }
    }

    func loadImageAndVideoNames(fromPexel: URL? = nil) -> [String] {
        debugPrint("loadImageNames: \(index) fromPexel: \(fromPexel?.absoluteString ?? "")")
        let imageFolder = selectedFolderPath

        let folderURL = fromPexel == nil ? URL(fileURLWithPath: imageFolder) : fromPexel!
        let fileManager = FileManager.default
        imageOrVideoMode = false
        startShowVideo = false
        var imageOrVideoNames: [String] = []
        do {
            let contents = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            //            imageOrVideoNames = contents.compactMap { $0.pathExtension.lowercased() == "webp" || $0.pathExtension.lowercased() == "avif" || $0.pathExtension.lowercased() == "jpeg" || $0.pathExtension.lowercased() == "jpg" || $0.pathExtension.lowercased() == "png" ? $0.lastPathComponent : nil }
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
            if fromPexel == nil {
                imageOrVideoNames.append(contentsOf: appDelegate.pexelsPhotos)
                debugPrint("pexelImages: \(index) \(appDelegate.pexelsPhotos.count)")
                imageOrVideoNames.append(contentsOf: appDelegate.pexelsVideos)
                debugPrint("pexelVideos: \(index) \(appDelegate.pexelsVideos.count)")
            }
            imageOrVideoMode = imageOrVideoNames.count >= 2
            debugPrint("imageMode: \(index) \(imageOrVideoMode)")
            if !imageOrVideoMode {
                firstImage = nil
                secondImage = nil
                stateObject.firstVideoPath = ""
                stateObject.secondVideoPath = ""
            }
        } catch {
            debugPrint("Error loading image names: \(error)")
        }
        return imageOrVideoNames
    }
}
