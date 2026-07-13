#if TONIC_HELPER

import Foundation

@main
enum TonicHelperMain {
    static func main() {
        let delegate = TonicHelperService()
        let listener = NSXPCListener(machServiceName: TonicHelperPolicy.machServiceName)
        listener.setConnectionCodeSigningRequirement(TonicHelperService.clientRequirement)
        listener.delegate = delegate
        listener.resume()
        RunLoop.current.run()
    }
}

#endif
