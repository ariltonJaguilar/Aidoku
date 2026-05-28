//
//  AidokuWidgetBundle.swift
//  AidokuWidget
//
//  Created by Arilton Junior de Aguilar on 27/05/26.
//

import WidgetKit
import SwiftUI

@main
struct AidokuWidgetBundle: WidgetBundle {
    var body: some Widget {
        AidokuWidget()
        AidokuLockScreenWidget()
    }
}
