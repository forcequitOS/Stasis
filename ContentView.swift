import SwiftUI

struct ContentView: View {
    // Revolutionary variables
    @State private var updatesDisabled = false
    @State private var showingAlert = false
    @State private var message = ""
    
    let path = "/var/mobile/Library/Preferences/com.apple.MobileAsset.plist"
    var appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown Version"
    var tvVersion = ProcessInfo.processInfo.operatingSystemVersionString
    
    var body: some View {
        if #available(tvOS 16.0, *) {
            NavigationStack {
                MainView
            }
        } else {
            // Required for tvOS 15 and below, I really do hate supporting older versions when working with SwiftUI.
            NavigationView {
                MainView
            }
        }
    }
    
    private var MainView: some View {
        VStack {
            // Status label (top)
            Text("Software Updates are currently " + (updatesDisabled ? "disabled." : "enabled."))
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
            
            // The grand toggle button (middle)
            Button {
                toggleUpdates()
            } label: {
                VStack(spacing: 20) {
                    Image(systemName: "gear")
                        .font(.system(size: 150))
                    Text(updatesDisabled ? "Enable Updates" : "Disable Updates")
                        .font(.headline)
                }
                .frame(width: 300, height: 300)
                // Previously: Label(updatesDisabled ? "Enable Updates" : "Disable Updates", systemImage: "gear")
                // Kinda looked better, kinda looked worse, I don't know. Wanted to try something that looked more like the Control Center Power Off button.
            }
            
            Spacer()
            
            // Note and version info (bottom)
            VStack(spacing: 8) {
                Text("After toggling updates, feel free to delete this.")
                    .font(.caption)
                Text("Stasis \(appVersion) on tvOS \(tvVersion)")
                    //.font(.caption2)
                    .font(.system(.caption2, design: .monospaced))
                    //.monospaced()
            }
        }
        .padding()
        .navigationTitle("Stasis")
        // Checks if updates are enabled or disabled on startup
        .onAppear() {
            withAnimation(.snappy(duration: 0.25)) {
                checkState()
            }
        }
        // Another dated API I have to use for legacy compatibility
        .onChange(of: message) { _ in
            showingAlert = true
        }
        // Alert when applying, shows either a success message or failure.
        .alert(isPresented: $showingAlert) {
            // Yet another thing I could've done in a more modern, simple way if I only supported tvOS 15.0+
            Alert(
                title: Text("Status"),
                message: Text(message),
                dismissButton: .default(Text("Got it"))
            )
        }
    }
    func toggleUpdates() {
        // I probably could do something a little bit more complex and a bit more elaborate for the plist to not be stored in the binary like this, but I don't really care.
        let plist = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>MobileAssetAssetAudience</key>
                <string>null</string>
                <key>MobileAssetSUAllowOSVersionChange</key>
                <false/>
                <key>MobileAssetSUAllowSameVersionFullReplacement</key>
                <false/>
                <key>MobileAssetServerURL-com.apple.MobileAsset.MobileSoftwareUpdate.UpdateBrain</key>
                <string>null</string>
                <key>MobileAssetServerURL-com.apple.MobileAsset.RecoveryOSUpdate</key>
                <string>null</string>
                <key>MobileAssetServerURL-com.apple.MobileAsset.RecoveryOSUpdateBrain</key>
                <string>null</string>
                <key>MobileAssetServerURL-com.apple.MobileAsset.SoftwareUpdate</key>
                <string>null</string>
            </dict>
            </plist>
            """
        let data = plist.data(using: .utf8)
        
        if !updatesDisabled {
            // If updates are NOT disabled, write plist to disable them
            let success = FileManager.default.createFile(atPath: path, contents: data)
            if success {
                updatesDisabled.toggle()
                message = "Software Updates have successfully been disabled! Please restart to apply." // I originally wanted to not require a reboot, but I tried to terminate a LOT of processes to no avail.
            } else {
                message = "Failed to write to Preferences. Please ensure Stasis was installed via TrollStore or a jailbreak."
            }
        } else {
            // If updates ARE disabled, remove plist to enable them again
            do {
                try FileManager.default.removeItem(atPath: path)
                updatesDisabled.toggle()
                message = "Software Updates have successfully been enabled, be careful. Please restart to apply."
            } catch {
                message = "Failed to remove file from Preferences. Please ensure Stasis was installed via TrollStore or a jailbreak"
            }
        }
    }
    
    // Not a very in-depth check, if a file exists at <path>, assumes updates are disabled
    func checkState() {
        let fileExists = FileManager.default.fileExists(atPath: path)
        if fileExists {
            updatesDisabled = true
        } else {
            updatesDisabled = false
        }
    }
    
}
