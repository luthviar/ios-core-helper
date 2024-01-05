//
//  ContentView.swift
//  CoreHelperApp
//
//  Created by Luthfi Abdurrahim on 05/01/24.
//

import SwiftUI
import UIKit
import WebKit

class Constants {
    static let privacyPolicyWebPage: String = "https://support.muslimpro.com/hc/en-us/articles/203485970-Privacy-Policy"
    static let apiUploadUrl: String = "https://api.escuelajs.co/api/v1/files/upload"
}

class Utils {
    static func readFile(path: URL) -> String {

        /// Create a URL from the file path
        let fileURL = path

        do {
            /// Read data from the file
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            return content
        } catch {
            return error.localizedDescription
        }
    }
}

extension NSMutableData {
    func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

struct ContentView: View {
    @StateObject private var webViewNavDelegate: WebViewNavigationDelegate = WebViewNavigationDelegate()
    
    @State private var showSuccessSheet: Bool = false
    @State private var showErrorSheet: Bool = false
    @State private var showSheet: Bool = false
    @State private var isNeedToShowWebViewPDF: Bool = true
    
    var body: some View {
        ZStack {
            
            if isNeedToShowWebViewPDF {
                VStack {
                    SimpleWebView(url: URL(string: Constants.privacyPolicyWebPage)!, navigationDelegate: self.webViewNavDelegate)
                        .onReceive(webViewNavDelegate.$didLoadSuccessfully) { didLoad in
                            if didLoad {
                                showSuccessSheet = true
                            }
                        }
                        .onReceive(webViewNavDelegate.$didFailToLoad) { didFail in
                            if didFail {
                                showErrorSheet = true
                            }
                        }
                        .onReceive(self.webViewNavDelegate.$didUploaded) { uploaded in
                            if uploaded {
                                isNeedToShowWebViewPDF = false
                            }
                        }
                }
                .zIndex(1)
                .opacity(0)
            }
            
            VStack {
                Text("This is Top")
                
                Spacer()
                
                Button("Go To Next Page") {
                    showSheet = true
                }
                
                Spacer()
                
                Text("This is Bottom")
            }
            .zIndex(3)
            
        }
        .sheet(isPresented: $showSheet) {
            VStack(spacing: 20) {
                Text("This is the next page")
                Text("the API Response: \(webViewNavDelegate.webUrlResponse)")
            }
        }
    }
        
}

#Preview {
    ContentView()
}

/// Define a class to handle WebView events and communicate with SwiftUI view
class WebViewNavigationDelegate: NSObject, WKNavigationDelegate, ObservableObject {
    /// Use @Published properties to notify SwiftUI view about changes
    @Published var didLoadSuccessfully: Bool = false
    @Published var didFailToLoad: Bool = false
    @Published var didUploaded: Bool = false
    @Published var webUrlResponse: String = ""

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.didLoadSuccessfully = true
        
        let config = WKPDFConfiguration()
        webView.createPDF(configuration: config) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let pdfDocument):
                    self.uploadPDF(pdfData: pdfDocument) { [weak self] webUrl in
                        guard let self = self else { return }
                        self.webUrlResponse = webUrl
                        self.didUploaded = !webUrl.isEmpty
                    }
                case .failure(let error):
                    print("ErrorCreatePDF: \(error.localizedDescription)")
                }
            }
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        self.didFailToLoad = true
        print("ErrorLoadWeb: \(error.localizedDescription)")
    }
    
    func uploadPDF(pdfData: Data, completion: @escaping (String) -> Void) {
        let url = URL(string: Constants.apiUploadUrl)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let body = NSMutableData()
        
        /// Append the PDF data to the request body
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"file\"; filename=\"file.pdf\"\r\n")
        body.appendString("Content-Type: application/pdf\r\n\r\n")
        body.append(pdfData)
        body.appendString("\r\n")
        body.appendString("--\(boundary)--\r\n")
        
        request.httpBody = body as Data
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    print("ErrorUploadPDF: \(error.localizedDescription)")
                    completion("")
                    return
                }
                
                /// Handle the response here
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("ResponseUploadPDF: \(responseString)")
                    completion(responseString)
                }
            }
        }
        
        task.resume()
    }
}

struct SimpleWebView: UIViewRepresentable {
    let url: URL
    let navigationDelegate: WebViewNavigationDelegate
    let webView = WKWebView()

    func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = navigationDelegate
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        /// Update the view when your SwiftUI state changes, if necessary
    }
}
