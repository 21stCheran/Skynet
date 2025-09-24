//
//  ContentView.swift
//  Skynet
//
//  Created by Apple on 24/09/25.
//

import SwiftUI

struct ContentView: View {
    @State private var ip: String = ""
    @State private var port: String = ""
    @State private var message: String = ""
    @State private var showAlert = false
    
    var body: some View {
        VStack(spacing: 18) {
            Text("Skynet Messenger")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            
            TextField("IP Address", text: $ip)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.decimalPad)
            
            TextField("Port", text: $port)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.numberPad)
            
            TextField("Message", text: $message)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Button(action: sendData ) {
                Text("Send Data")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10.0)
            }
        }.padding(20)
        
        
        
    }
    
    func sendData() {
        print("-- sending data --")
        print("IP Address: \(ip)")
        print("Port \(port)")
        print("Message \(message)")
    }
}
