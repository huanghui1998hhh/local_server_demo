//
//  ContentView.swift
//  test_wave
//
//  Created by HuangHui on 2021/8/26.
//

import SwiftUI
import Telegraph
import SafariServices
//import Kanna

class MobileConfigModel: ObservableObject {
    static let shared = MobileConfigModel()
    private init() {}
    
    @Published var mobileConfig: MobileConfig = MobileConfig(configName: "配置名", configDesc: "配置描述", content: [])
    
    func toData() -> Data {
        try! PropertyListEncoder().encode(self.mobileConfig)
    }
}

struct ContentView: View {
    @ObservedObject private var mobileConfigModel: MobileConfigModel = .shared
    @State private var safariView: SFSafariViewController!
    
    var body: some View {
        NavigationView{
            List{
                TextField("输入描述文件的名称", text: $mobileConfigModel.mobileConfig.PayloadDisplayName)
                    .textFieldStyle(.roundedBorder)
                TextField("输入描述文件的描述", text: $mobileConfigModel.mobileConfig.PayloadDescription)
                    .textFieldStyle(.roundedBorder)
                ForEach(mobileConfigModel.mobileConfig.PayloadContent, id: \.self.PayloadUUID) { item in
                    HStack{
                        Image(uiImage: UIImage(data: item.Icon) ?? UIImage())
                            .resizable()
                            .frame(width: 64, height: 64)
                            .cornerRadius(8)
                        VStack(alignment: .leading){
                            Text(item.Label)
                            Text(item.URL)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                Button("安装", action: goToInstall)
                    .foregroundColor(.accentColor)
            }
            .onOpenURL { _ in
                safariView.dismiss(animated: true) {
                    MobileConfigServer.shared.dismiss()
                    UIApplication.shared.open(URL(string: "App-prefs:General&path=ManagedConfigurationList")!)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: addButton)
        }
    }
    
    var addButton: some View {
        NavigationLink {
            EditPage()
        } label: {
            Text("ADD")
        }
    }
    
    func goToInstall() {
        DispatchQueue.global().async {
            let config = SFSafariViewController.Configuration()
            config.entersReaderIfAvailable = false
            
            self.safariView = SFSafariViewController(url: URL(string: "http://localhost:9000/mobileconfig")!, configuration: config)
            self.safariView.preferredControlTintColor = UIColor(named: "AccentColor")
            
            MobileConfigServer.shared.start(data: mobileConfigModel.toData())
            
            DispatchQueue.main.async {
                UIApplication.shared.windows.first?.rootViewController?.present(safariView, animated: true)
            }
        }
    }
}

struct EditPage: View {
    @State private var data: PayloadContentItem = PayloadContentItem(name: "奇异kiwi", url: "kiWidget://", icon: Data())
    @ObservedObject private var mobileConfigModel: MobileConfigModel = .shared
    
    @State private var showPhotoPicker: Bool = false
    
    @Environment(\.presentationMode) private var presentationMode
    
    var body: some View {
        VStack{
            TextField("输入图标的显示名称", text: $data.Label)
                .textFieldStyle(.roundedBorder)
            TextField("输入URL", text: $data.URL)
                .textFieldStyle(.roundedBorder)
            Image(uiImage: UIImage(data: data.Icon) ?? UIImage())
                .resizable()
                .frame(width: 64, height: 64)
                .cornerRadius(8)
                .background(Color.black.opacity(0.1))
                .contentShape(Rectangle())
                .onTapGesture {
                    showPhotoPicker.toggle()
                }
                .sheet(isPresented: $showPhotoPicker) {
                    ImagePicker(sourceType: UIImagePickerController.SourceType.photoLibrary) { image in
                        self.data.Icon = image.jpegData(compressionQuality: 0.1)!
                    }
                }
        }
        .navigationBarItems(trailing: okButton)
    }
    
    var okButton: some View {
        Button("OK") {
            mobileConfigModel.mobileConfig.PayloadContent.append(data)
            presentationMode.wrappedValue.dismiss()
        }
    }
}

enum KiDecoder {
    case Json
    case Plist
}

func loadFile<T: Codable>(_ fileName: String, type: T.Type, decoder: KiDecoder = .Json) -> T {
    guard let url = Bundle.main.url(forResource: fileName, withExtension: nil) else {
        fatalError("Can not find \(fileName) in main bundle")
    }
    guard let data = try? Data(contentsOf: url) else {
        fatalError("Can not load \(url)")
    }
    switch decoder {
    case .Json:
        guard let t = try? JSONDecoder().decode(type, from: data) else {
            fatalError("Can not parse json data")
        }
        return t
    case .Plist:
        guard let t = try? PropertyListDecoder().decode(type, from: data) else {
            fatalError("Can not parse plist data")
        }
        return t
    }
}

struct MobileConfig: Codable {
    var PayloadDisplayName: String
    var PayloadDescription: String
    var PayloadContent: [PayloadContentItem]
    var PayloadUUID: String
    var PayloadIdentifier: String
    var HasRemovalPasscode: Bool = false
    var PayloadRemovalDisallowed: Bool = false
    var PayloadType: PayloadType = .Configuration
    var PayloadVersion: Int = 1
    
    init(configName: String, configDesc: String, content: [PayloadContentItem]) {
        self.PayloadUUID = UUID().uuidString
        self.PayloadIdentifier = "kiWidget." + UUID().uuidString
        self.PayloadDisplayName = configName
        self.PayloadDescription = configDesc
        self.PayloadContent = content
    }
    
    enum PayloadType: String, Codable {
        case Configuration
    }
}

struct PayloadContentItem: Codable {
    var Label: String
    var URL: String
    var Icon: Data
    var PayloadUUID: String
    var PayloadIdentifier: String
    var PayloadDisplayName: String = "Web Clip"
    var PayloadDescription: String = "Configures settings for a web clip"
    var FullScreen: Bool = true
    var IsRemovable: Bool = true
    var Precomposed: Bool = true
    var IgnoreManifestScope: Bool = false
    var PayloadType: PayloadType = .WebClip
    var PayloadVersion: Int = 1
    
    init(name: String, url: String, icon: Data) {
        self.PayloadUUID = UUID().uuidString
        self.PayloadIdentifier = self.PayloadType.rawValue + "." + self.PayloadUUID
        self.Label = name
        self.URL = url
        self.Icon = icon
    }
    
    enum PayloadType: String, Codable {
        case WebClip = "com.apple.webClip.managed"
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) private var presentationMode
    
    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (UIImage) -> Void
    
    final class Coordinator: NSObject,
                             UINavigationControllerDelegate,
                             UIImagePickerControllerDelegate {
        
        @Binding
        private var presentationMode: PresentationMode
        private let sourceType: UIImagePickerController.SourceType
        private let onImagePicked: (UIImage) -> Void
        
        init(presentationMode: Binding<PresentationMode>,
             sourceType: UIImagePickerController.SourceType,
             onImagePicked: @escaping (UIImage) -> Void) {
            _presentationMode = presentationMode
            self.sourceType = sourceType
            self.onImagePicked = onImagePicked
        }
        
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            let uiImage = info[UIImagePickerController.InfoKey.originalImage] as! UIImage
            onImagePicked(uiImage)
            presentationMode.dismiss()
            
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            presentationMode.dismiss()
        }
        
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(presentationMode: presentationMode,
                           sourceType: sourceType,
                           onImagePicked: onImagePicked)
    }
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<ImagePicker>) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController,
                                context: UIViewControllerRepresentableContext<ImagePicker>) {
        
    }
    
}
