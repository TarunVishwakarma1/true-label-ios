//
//  ContentView.swift
//  truelable
//
//  Created by Tarun Vishwakarma on 08/09/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            DotGridBackground()

            ScanButton {
                print("Scan tapped")
            }
            .padding(.bottom, 48)
        }
    }
}

#Preview {
    ContentView()
}
