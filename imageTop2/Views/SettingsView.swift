import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var appDelegate: AppDelegate

    @AppStorage("replaceImageAfter") private var replaceImageAfter: TimeInterval = 10
    @AppStorage("startAfter") private var startAfter: TimeInterval = 600
    @AppStorage("selectedFolderPath") private var storedFolderPath: String = ""
    @AppStorage("imageTopFolderBookmark") private var imageTopFolderBookmarkData: Data?
    @AppStorage("hotKeyString") private var keyString: String = "Escape"
    @AppStorage("modifierKeyString1") private var keyString1: String = "command"
    @AppStorage("modifierKeyString2") private var keyString2: String = "control"
    @AppStorage("usePhotosFromPexels") private var usePhotosFromPexels: Bool = false
    @AppStorage("useVideosFromPexels") private var useVideosFromPexels: Bool = false

    @State private var usePhotosFromPexelsIsOn: Bool = false
    @State private var useVideosFromPexelsIsOn: Bool = false
    @State private var selectedFolderPath = ""

    private let allKeyNames = Keyboard.keyNames
    private let modKeyNames = Keyboard.modKeyNames

    private var filteredKeys: [String] {
        let searchString = ""
        return allKeyNames.filter { $0.lowercased().hasPrefix(searchString) }
    }

    var body: some View {
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
                                        }, label: {
                                            Text(key)
                                        })
                                    }
                                } label: {
                                    Text("Keys")
                                }.frame(width: 60)

                            }
                            TextField("", text: $keyString)
                                .frame(width: 120)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .allowsHitTesting(false)
                            Spacer()
                        }.padding(.leading)
                        HStack {
                            Text("Modifier key 1")
                                .frame(width: geometry.size.width * 0.35, alignment: .leading)
                            Menu {
                                ForEach(modKeyNames, id: \.self) { mod in
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
                                ForEach(modKeyNames, id: \.self) { mod in
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
                            Text("Start after (seconds)")
                                .frame(width: geometry.size.width * 0.635, alignment: .leading)
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
                            Text("Image Folder")
                                .frame(width: geometry.size.width * 0.58, alignment: .leading)
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
                                Toggle("Photos from Pexels", isOn: $usePhotosFromPexelsIsOn)
                                Spacer()
                                    .buttonStyle(PlainButtonStyle())
                                Toggle("Videos from Pexels", isOn: $useVideosFromPexelsIsOn)
                                Spacer()
                            }
                            Spacer()
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
                        }
                        .padding(.leading)
                    }
                }
            }
        }
        Button(action: { appDelegate.hideSettings() }) {
            EmptyView()
        }.keyboardShortcut(.cancelAction)
        .buttonStyle(PlainButtonStyle())
//        .overlay(KeyView(dismiss: { appDelegate.hideSettings() }).allowsHitTesting(false))
        .onChange(of: usePhotosFromPexelsIsOn) { newValue in
            print("isOn: \(usePhotosFromPexelsIsOn)")
            usePhotosFromPexels = usePhotosFromPexelsIsOn
        }
        .onChange(of: useVideosFromPexelsIsOn) { newValue in
            print("isOn: \(useVideosFromPexelsIsOn)")
            useVideosFromPexels = useVideosFromPexelsIsOn
        }
        .frame(width: 350, height: 325)
        .onAppear {
            selectedFolderPath = storedFolderPath
            usePhotosFromPexelsIsOn = usePhotosFromPexels
            useVideosFromPexelsIsOn = useVideosFromPexels
        }
    }

    private func openFolderPicker() {
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
                    debugPrint("Error creating security-scoped bookmark: \(error)")
                }
            }
        }
    }
}

//struct SettingsView_Previews: PreviewProvider {
//    static var previews: some View {
//        SettingsView()
//    }
//}
