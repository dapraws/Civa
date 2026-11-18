//
//  InstallLocationTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 18/11/26.
//

import Testing
@testable import Civa

struct InstallLocationTests {
    @Test func installedCopiesAreFine() {
        #expect(!InstallLocation.needsMove(bundlePath: "/Applications/Civa.app"))
        #expect(!InstallLocation.needsMove(bundlePath: "/Users/rina/Applications/Civa.app"))
    }

    /// Opened straight from the disk image, or from Downloads (macOS runs those from a translocated copy).
    @Test func diskImageAndTranslocatedCopiesNeedAMove() {
        #expect(InstallLocation.needsMove(bundlePath: "/Volumes/Civa/Civa.app"))
        #expect(InstallLocation.needsMove(bundlePath: "/private/var/folders/x/AppTranslocation/1A2B/d/Civa.app"))
    }
}
