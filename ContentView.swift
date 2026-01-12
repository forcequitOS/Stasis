import Combine
import SwiftUI

// MARK: - Initial View
struct ContentView: View {
    @StateObject private var manager = StasisManager() // Handles basically all variables and logic externally now
    @Environment(\.scenePhase) private var scenePhase
    
    // Version stuff
    let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "x.y.z"
    let tvVersion = ProcessInfo.processInfo.operatingSystemVersionString
    
    var body: some View {
        if #available(tvOS 16.0, *) {
            NavigationStack {
                mainView
            }
        } else {
            // Required for tvOS 15 and below, I really do hate supporting older versions when working with SwiftUI.
            NavigationView {
                mainView
            }
        }
    }
    
    // MARK: - Main View
    private var mainView: some View {
        VStack {
            // Status label (top)
            Text("Software Updates are currently " + (manager.updatesDisabled ? "disabled." : "enabled."))
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
            
            // The grand toggle button (middle)
            Button {
                manager.toggleUpdates()
            } label: {
                VStack(spacing: 20) {
                    Image(systemName: "gear")
                        .font(.system(size: 150))
                    Text(manager.updatesDisabled ? "Enable Updates" : "Disable Updates")
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
                Text("Stasis is incompatible with other update blockers.")
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
            resyncState()
        }
        // Another dated API I have to use for legacy compatibility
        .onChange(of: scenePhase) { _ in
            resyncState() // Just to be completely sure, when closing/opening the app
        }
        // Alert when applying, shows either a success message or failure.
        .alert(isPresented: $manager.showingAlert) {
            // Yet another thing I could've done in a more modern, simple way if I only supported tvOS 15.0+
            Alert(
                title: Text(manager.alertTitle),
                message: Text(manager.alertMessage),
                dismissButton: .default(Text("Got it"))
            )
        }
    }
    // Keeps the app and system state in sync
    func resyncState() {
        withAnimation(.snappy(duration: 0.25)) {
            manager.checkState()
        }
        manager.restartDaemons() // For good measure, to make sure the system's state is correct
    }
}

class StasisManager: ObservableObject {
    // MARK: Variables
    @Published var updatesDisabled = false
    @Published var alertMessage = ""
    @Published var alertTitle = ""
    @Published var showingAlert = false
    
    private var betaProfileInstalled = false
    
    // MARK: - Constants
    // These are all private as mainView() doesn't really need to access them, only other stuff in the manager
    // FileManager instance
    private let files = FileManager.default
    
    // File paths
    private let userPath = "/var/mobile/Library/Preferences/com.apple.MobileAsset.plist"
    private let managedPath = "/var/Managed Preferences/mobile/com.apple.MobileAsset.plist" // Path where beta profiles write to, this overrides /var/mobile/Library/Preferences.
    // These files are all pretty irrelevant, but they are installed by beta profiles so I might as well handle erasing them.
    private let feedbackPath = "/var/Managed Preferences/mobile/com.apple.appleseed.FeedbackAssistant.plist"
    private let seedingPath = "/var/Managed Preferences/mobile/com.apple.seeding.plist"
    private let webFilterPath = "/var/Managed Preferences/mobile/com.apple.webcontentfilter.plist"
    
    // File attributes, to set as read-only for every user excluding root
    private let attrs: [FileAttributeKey: Any] = [
        .posixPermissions: 0o444
    ]
    
    // MARK: - Operations
    public func toggleUpdates() {
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
            let successUser = files.createFile(atPath: userPath, contents: data)
            let successManaged = files.createFile(atPath: managedPath, contents: data, attributes: attrs)
            if successUser && successManaged {
                removeProfile()
                writePlaceholders()
                betaProfileInstalled = false
                // Restarting is so 2025.
                restartDaemons()
                checkState() // Rather than just assuming it worked, even though... it did if we got here.
                showAlert("Software Updates have successfully been disabled!", "Updates Disabled")
            } else {
                showAlert("Failed to write to Preferences. Please ensure Stasis was installed via TrollStore or a jailbreak.", "Error")
            }
        } else {
            // If updates ARE disabled, remove plist to enable them again
            do {
                if betaProfileInstalled == false {
                    removeProfile() // Cleans up after ourselves. This would also delete most of a beta profile though.
                }
                try files.removeItem(atPath: userPath)
                // Accounts for Stasis 1.x where this obviously wasn't considered and the path might not even exist (If you don't have a beta profile installed)
                // If you have a beta profile installed and are upgrading from Stasis 1.x to 2.x, it attempts to preserve it when enabling updates.
                if (files.fileExists(atPath: managedPath) && betaProfileInstalled == false) {
                    removeProfile()
                    try files.removeItem(atPath: managedPath)
                }
                restartDaemons()
                checkState()
                showAlert("Software Updates have successfully been enabled, please be careful. To receive beta updates, re-install any tvOS beta profiles.", "Updates Enabled")
            } catch {
                showAlert("Failed to write to Preferences. Please ensure Stasis was installed via TrollStore or a jailbreak.", "Error")
            }
        }
    }
    
    // The logic of this function got way, way more complicated for 2.0.
    func checkState() {
        // Does file in /var/mobile/Library/Preferences exist?
        let userExists = files.fileExists(atPath: userPath)
        
        // Does file in /var/Managed Preferences/mobile exist?
        let managedExists = files.fileExists(atPath: managedPath)
        if managedExists {
            // It does exist
            let url = URL(fileURLWithPath: managedPath)
            do {
                let data = try Data(contentsOf: url)
                let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
                // Does it contain "mesu"? If so, it's probably installed by a beta profile and not by Stasis (and is actively preventing updates from being blocked).
                betaProfileInstalled = containsMesu(plist)
            } catch {
                // No, it doesn't exist.
                betaProfileInstalled = false
            }
        }
        
        if userExists {
            // Updates are disabled IF:
            // File in /var/mobile/Library/Preferences exists, AND a beta profile is not installed (File either exists at /var/Managed Preferences/mobile and doesn't contain "mesu", or file does not exist there)
            updatesDisabled = !betaProfileInstalled
        } else {
            // Updates are disabled IF:
            // File in /var/Managed Preferences/mobile exists and it ISN'T from a beta profile (Doesn't contain "mesu")
            // This is for if the file in /var/mobile/Library/Preferences does NOT exist, but the other one does.
            updatesDisabled = managedExists && !betaProfileInstalled
        }
        
        /* I was thinking of doing this but decided against it.
        if betaProfileInstalled == true {
            showAlert("A tvOS beta profile is installed, it's heavily recommended to remove it before using Stasis.", "Warning")
        }
         */
    }
    
    // Thanks ChatGPT for the following. I would have written it myself but I can't be bothered working with plists like that at all.
    private func containsMesu(_ value: Any) -> Bool {
        if let s = value as? String {
            return s.contains("mesu")
        }
        if let d = value as? [String: Any] {
            return d.values.contains(where: containsMesu)
        }
        if let a = value as? [Any] {
            return a.contains(where: containsMesu)
        }
        return false
    }
    
    func removeProfile() {
        // Installing / removing a beta profile also modifies .GlobalPreferences.plist (adds SeedGroup key), however that has actual user settings in there for Content Restrictions that could be meaningful, so I decided to not overwrite it, and modifying it would be too much effort. It's harmless anyways.
        // Removes files a beta profile would install (and that we create placeholders for in writePlaceholders)
        // This used to check if files existed before trying to delete them, but it kinda doesn't matter, I'm not catching errors anyways.
        try? files.removeItem(atPath: feedbackPath)
        try? files.removeItem(atPath: seedingPath)
        try? files.removeItem(atPath: webFilterPath)
    }
    
    func writePlaceholders() {
        // Writes empty files as read-only to effectively disable the ability to install a new beta profile
        files.createFile(atPath: feedbackPath, contents: nil, attributes: attrs)
        files.createFile(atPath: seedingPath, contents: nil, attributes: attrs)
        files.createFile(atPath: webFilterPath, contents: nil, attributes: attrs)
    }
    
    // MARK: - Helper Functions
    func restartDaemons() {
        killall("cfprefsd") // Killing cfprefsd is optional, but does increase the chances of it applying reliably without a reboot
        killall("mobileassetd")
    }
    
    func showAlert(_ message: String, _ title: String?) {
        alertMessage = message
        alertTitle = title ?? "Status"
        showingAlert = true
    }
}

// Robbed straight from TSUtil.m, converted to Swift entirely by ChatGPT.
func enumerateProcesses(
    _ body: (_ pid: pid_t, _ execPath: String, _ stop: inout Bool) -> Void
) {
    var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL]
    var length: size_t = 0
    guard mib.withUnsafeMutableBufferPointer({
        sysctl($0.baseAddress, 3, nil, &length, nil, 0)
    }) == 0 else { return }
    let count = length / MemoryLayout<kinfo_proc>.stride
    let procs = UnsafeMutablePointer<kinfo_proc>.allocate(capacity: count)
    defer { procs.deallocate() }
    guard mib.withUnsafeMutableBufferPointer({
        sysctl($0.baseAddress, 3, procs, &length, nil, 0)
    }) == 0 else { return }
    let argBufferSize = 256 * 1024
    for i in 0..<count {
        let pid = procs[i].kp_proc.p_pid
        if pid == 0 { continue }
        let buffer = UnsafeMutableRawPointer.allocate(
            byteCount: argBufferSize,
            alignment: MemoryLayout<Int>.alignment
        )
        defer { buffer.deallocate() }
        var size = argBufferSize
        var argsMib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        let result = argsMib.withUnsafeMutableBufferPointer {
            sysctl($0.baseAddress, 3, buffer, &size, nil, 0)
        }
        if result != 0 { continue }
        let execPtr = buffer
            .advanced(by: MemoryLayout<Int>.size)
            .assumingMemoryBound(to: CChar.self)

        let path = String(cString: execPtr)
        var stop = false
        body(pid, path, &stop)
        if stop { break }
    }
}

func killall(_ processName: String) {
    enumerateProcesses { pid, path, _ in
        if URL(fileURLWithPath: path).lastPathComponent == processName {
            kill(pid, SIGKILL)
        }
    }
}
