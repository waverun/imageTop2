import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var appDelegate: AppDelegate
//    @Environment(\.presentationMode) var presentationMode

    @AppStorage("replaceImageAfter") var replaceImageAfter: TimeInterval = 10
    @AppStorage("startAfter") var startAfter: TimeInterval = 600
    @AppStorage("selectedFolderPath") var storedFolderPath: String = ""
    @AppStorage("imageTopFolderBookmark") var imageTopFolderBookmarkData: Data?
    @AppStorage("hotKeyString") var keyString: String = "escape"
    @AppStorage("modifierKeyString1") var keyString1: String = "command"
    @AppStorage("modifierKeyString2") var keyString2: String = "control"
    @AppStorage("usePhotosFromPexels") var usePhotosFromPexels: Bool = false
    @AppStorage("useLocalImagesAndVideos") var useLocalImagesAndVideos: Bool = false
    @AppStorage("useVideosFromPexels") var useVideosFromPexels: Bool = false
    @AppStorage("showWatch") var showWatch = true 
    @AppStorage("showCpu") var showCpu = false

    @State var usePhotosFromPexelsIsOn: Bool = false
    @State var useLocalImageAndVideosIsOn: Bool = false
    @State var showWatchIsOn: Bool = false
    @State var showCpuIsOn: Bool = false
    @State var useVideosFromPexelsIsOn: Bool = true
    @State var selectedFolderPath = ""
    @State var disabled = false
    @State var numberOfLocalImagesAndVideos = 0
    @State var numberOfPexelsPhotos = 0
    @State var numberOfPexelsVideos = 0
    @State var filteredModKeyNames1: [String] = Keyboard.modKeyNames
    @State var filteredModKeyNames2: [String] = Keyboard.modKeyNames
    @State var keyStringSymbol = ""

    let allKeyNames = Keyboard.keyNames
    let modKeyNames = Keyboard.modKeyNames

    var filteredKeys: [String] {
        let searchString = ""
        return allKeyNames.filter { $0.lowercased().hasPrefix(searchString) }
    }

    func filterModKeys(otherModeValue: String) -> [String] {
//        let searchString = ""
//        return allKeyNames.filter { $0.lowercased().hasPrefix(searchString) }
        return modKeyNames.filter { $0 != otherModeValue }
    }

    @ViewBuilder var body: some View {
        VStack {
            Text("Settings")
                .font(.title)
                .padding()

            GeometryReader { geometry in
                Form {
                    VStack {
                        HStack {
                            Text("Hot key")
                                .frame(width: geometry.size.width * 0.35, alignment: .leading)

                            if !filteredKeys.isEmpty {
                                Menu {
                                    ForEach(filteredKeys, id: \.self) { key in
                                        Button(action: {
                                            keyString = key
                                            keyStringSymbol = Keyboard.keySymbol(from: key)
                                        }, label: {
                                            Text(Keyboard.keySymbol(from: key))
                                        })
                                    }
                                } label: {
                                    Text("Keys")
                                }.frame(width: 60)

                            }
                            TextField("", text: $keyStringSymbol)
                                .frame(width: 120)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .allowsHitTesting(false)
                            Spacer()
                        }.padding(.leading)
                        HStack {
                            Text("Modifier key 1")
                                .frame(width: geometry.size.width * 0.35, alignment: .leading)
                            Menu {
                                ForEach(filteredModKeyNames1, id: \.self) { mod in
                                    Button(action: {
                                        keyString1 = mod
                                    }, label: {
                                        Text(mod)
                                    })
                                }
                            } label: {
                                Text("Mods")
                            }.frame(width: 62)
                            TextField("", text: $keyString1)
                                .frame(width: 120)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .allowsHitTesting(false)
                            Spacer()
                        }.padding(.leading)
                        HStack {
                            Text("Modifier key 2")
                                .frame(width: geometry.size.width * 0.35, alignment: .leading)
                            Menu {
                                ForEach(filteredModKeyNames2, id: \.self) { mod in
                                    Button(action: {
                                        keyString2 = mod
                                    }, label: {
                                        Text(mod)
                                    })
                                }
                            } label: {
                                Text("Mods")
                            }.frame(width: 62)
                            TextField("", text: $keyString2)
                                .frame(width: 120)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .allowsHitTesting(false)
                            Spacer()
                        }.padding(.leading)

                        HStack {
                            Text("Replace Image After (seconds)")
                                .frame(width: geometry.size.width * 0.635, alignment: .leading)
                            FocusableTextField(text: Binding(get: {
                                String(replaceImageAfter)
                            }, set: { newValue in
                                if let value = TimeInterval(newValue) {
                                    replaceImageAfter = value
                                }
                            }), formatter: NumberFormatter())
                            .multilineTextAlignment(.trailing)
                            .frame(width: 50)
                            Spacer()
                        }.padding(.leading)
                        HStack {
                            Text("Start after (Inactiviy seconds)")
                                .frame(width: geometry.size.width * 0.635, alignment: .leading)
                                .opacity(appDelegate.autoStart ? 1.0 : 0.5) // Add this line
                            FocusableTextField(text: Binding(get: {
                                String(startAfter)
                            }, set: { newValue in
                                if let value = TimeInterval(newValue) {
                                    startAfter = value
                                }
                            }), formatter: NumberFormatter())
                            .multilineTextAlignment(.trailing)
                            .frame(width: 50)
                            Spacer()
                        }.padding(.leading)
                        HStack {
                            Toggle("Images and Videos Folder (\(numberOfLocalImagesAndVideos))", isOn: $useLocalImageAndVideosIsOn)
//                            Text("Images and Videos Folder (\(numberOfLocalImagesAndVideos))")
//                                .frame(width: geometry.size.width * 0.60, alignment: .leading)
                            Button("Select...") {
                                openFolderPicker()
                            }
                            Spacer()
                        }.padding(.leading)
                        Text(selectedFolderPath)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        HStack {
                            VStack(alignment: .leading) {
                                Toggle("Photos from Pexels (\(numberOfPexelsPhotos))", isOn: $usePhotosFromPexelsIsOn)
                                Spacer()
                                    .buttonStyle(PlainButtonStyle())
                                Toggle("Videos from Pexels (\(numberOfPexelsVideos))", isOn: $useVideosFromPexelsIsOn)
                                Spacer()
                            }
                            Spacer()
                            ZStack {
                                Button(action: {
                                    if let url = URL(string: "https://www.pexels.com") {
                                        NSWorkspace.shared.open(url)
                                    }
                                }) {
                                    Image("pexels")
                                        .resizable()
                                        .frame(width: 32, height: 32)
                                        .offset(y: -3)  // This line moves the button up by 10 points
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.trailing, 50) // Add a gap on the right side of the button
                                if disabled {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .scaleEffect(0.75)  // This line reduces the size of the spinner to half
                                        .offset(x: -25, y: -4) // This line moves the spinner 15 points to the left
                                }
                            }
                        }
                        .padding(.leading)
                        HStack {
                            VStack(alignment: .leading) {
                                Toggle("Show Watch", isOn: $showWatchIsOn)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading) // Add this line
                        .padding(.leading)
                        HStack {
                            VStack(alignment: .leading) {
                                Toggle("Show System CPU", isOn: $showCpuIsOn)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading) // Add this line
                        .padding(.leading)
                        Spacer()
                    }
                }
            }
        }
        .disabled(disabled)
//        Button(action: { appDelegate.hideSettings() }) {
//            EmptyView()
//        }.keyboardShortcut(.cancelAction)
        .buttonStyle(PlainButtonStyle())
        .onChange(of: usePhotosFromPexelsIsOn) { newValue in
           iPrint("isOn: \(usePhotosFromPexelsIsOn)")
            usePhotosFromPexels = usePhotosFromPexelsIsOn
        }
        .onChange(of: useLocalImageAndVideosIsOn) { newValue in
           iPrint("isOn: \(useLocalImageAndVideosIsOn)")
            useLocalImagesAndVideos = useLocalImageAndVideosIsOn
        }
        .onChange(of: useVideosFromPexelsIsOn) { newValue in
           iPrint("isOn: \(useVideosFromPexelsIsOn)")
            useVideosFromPexels = useVideosFromPexelsIsOn
        }
        .onChange(of: appDelegate.pexelsPhotos) { pexelsPhotos in
            if pexelsPhotos.count < 2 {
                usePhotosFromPexelsIsOn = false
                usePhotosFromPexels = false
            }
        }
        .onChange(of: appDelegate.pexelsVideos) { pexelsVideos in
            if pexelsVideos.count < 2 {
                useVideosFromPexelsIsOn = false
                useVideosFromPexels = false
            }
        }
        .onChange(of: showWatchIsOn) { newValue in
            iPrint("isOn: \(showWatchIsOn)")
            showWatch = showWatchIsOn
            appDelegate.showWatchOrCpu = showWatch
            if showWatch {
                showCpuIsOn = false
//                showCpu = false
//                appDelegate.showCpu = false
            }
        }
        .onChange(of: showWatch) { newValue in
            iPrint("showWatch: \(showWatch)")
            showWatchIsOn = newValue
        }
        .onChange(of: showCpuIsOn) { newValue in
            iPrint("cpu isOn: \(showCpuIsOn)")
            showCpu = showCpuIsOn
            appDelegate.showCpu = showCpu
            if showCpu {
                showWatchIsOn = false
//                showWatch = false
            }
        }
        .onChange(of: showCpu) { newValue in
            iPrint("showCpu: \(showCpu)")
            showCpuIsOn = newValue
        }
        .onChange(of: keyString) { _ in
            iPrint("keyString: \(keyString)")
            appDelegate.updateShowItem()
        }
        .onChange(of: keyString1) { newValue in
            iPrint("keyString1: \(keyString1)")
            filteredModKeyNames2 = filterModKeys(otherModeValue: newValue)
            appDelegate.updateShowItem()
        }
        .onChange(of: keyString2) { newValue in
            iPrint("keyString2: \(keyString2)")
            filteredModKeyNames1 = filterModKeys(otherModeValue: newValue)
            appDelegate.updateShowItem()
        }
//        .onReceive(NSEvent.keyEventPublisher(for: .escape), perform: { _ in
//            self.presentationMode.wrappedValue.dismiss()
//        })
        .onReceive(appDelegate.$downloading) { newValue in
            iPrint("appDelegate.$downloading: \(appDelegate.downloading)")
            disabled = newValue
        }
        .onReceive(appDelegate.$numberOfLocalImagesAndVideos) { newValue in
//            iPrint("appDelegate.$downloading: \(appDelegate.downloading)")
            numberOfLocalImagesAndVideos = newValue
        }
        .onReceive(appDelegate.$numberOfPexelsPhotos) { newValue in
//            iPrint("appDelegate.$downloading: \(appDelegate.downloading)")
            numberOfPexelsPhotos = newValue
        }
        .onReceive(appDelegate.$numberOfPexelsVideos) { newValue in
//            iPrint("appDelegate.$downloading: \(appDelegate.downloading)")
            numberOfPexelsVideos = newValue
        }
        .frame(width: 350, height: 360)
        .onAppear {
            selectedFolderPath = storedFolderPath
            usePhotosFromPexelsIsOn = usePhotosFromPexels
            useLocalImageAndVideosIsOn = useLocalImagesAndVideos
            useVideosFromPexelsIsOn = useVideosFromPexels
            showWatchIsOn = showWatch
            showCpuIsOn = showCpu
            keyStringSymbol = Keyboard.keySymbol(from: keyString)
            filteredModKeyNames1 = filterModKeys(otherModeValue: keyString2)
            filteredModKeyNames2 = filterModKeys(otherModeValue: keyString1)
        }
    }

    func openFolderPicker() {
        appDelegate.settingsWindow.level = .normal

        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.allowedContentTypes = [UTType.folder]
        openPanel.allowsOtherFileTypes = false

        openPanel.begin { result in
            appDelegate.settingsWindow.level = .floating

            if result == .OK, let url = openPanel.url {
                do {
                    let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                    imageTopFolderBookmarkData = bookmarkData
                    selectedFolderPath = url.path
                    storedFolderPath = selectedFolderPath
                } catch {
                    iPrint("Error creating security-scoped bookmark: \(error)")
                }
            }
        }
    }
}
