import AppKit
let pid = pid_t(Int32(CommandLine.arguments[1])!)
if let app = NSRunningApplication(processIdentifier: pid) { print(app.terminate()) } else { print("noapp") }
