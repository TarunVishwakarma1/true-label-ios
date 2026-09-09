//
//  ContentView.swift
//  truelable
//
//  Created by Tarun Vishwakarma on 08/09/26.
//

import SwiftUI

struct ContentView: View {
    @State private var isScanning = false

    var body: some View {
        ZStack(alignment: .bottom) {
            DotGridBackground(isPaused: isScanning)

            ScanButton(isPaused: isScanning) {
                isScanning = true
            }
            .padding(.bottom, 48)
        }
        .fullScreenCover(isPresented: $isScanning) {
            ScannerView(onDismiss: {
                print("[ContentView] onDismiss closure fired, setting isScanning = false")
                isScanning = false
            })
        }
    }
}
