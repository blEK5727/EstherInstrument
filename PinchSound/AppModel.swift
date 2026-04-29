//
//  AppModel.swift
//  PinchSound
//

import SwiftUI

@MainActor
@Observable
class AppModel {
    let instrumentSpaceID = "InstrumentSpace"
    let ringSpaceID       = "RingSpace"
    let staggerSpaceID    = "StaggerSpace"
    let ambientSpaceID    = "AmbientSpace"
    
    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }
    var immersiveSpaceState = ImmersiveSpaceState.closed
    var activeSpaceID: String? = nil   // tracks which space is currently open
}
