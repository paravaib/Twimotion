//
//  LegalView.swift
//  Twimotion
//
//  Created by Vaibhav Parashar on 10/21/25.
//

import SwiftUI
import WebKit

/// Legal documents viewer with HTML content
struct LegalView: View {
    let title: String
    let htmlFileName: String
    
    var body: some View {
        NavigationView {
            WebView(htmlFileName: htmlFileName)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.large)
        }
    }
}

/// WebView wrapper for displaying HTML content
struct WebView: UIViewRepresentable {
    let htmlFileName: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        loadHTMLFile(webView: webView)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func loadHTMLFile(webView: WKWebView) {
        guard let htmlPath = Bundle.main.path(forResource: htmlFileName, ofType: "html"),
              let htmlString = try? String(contentsOfFile: htmlPath) else {
            return
        }
        
        webView.loadHTMLString(htmlString, baseURL: Bundle.main.bundleURL)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: WebView
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Handle external links
            if let url = navigationAction.request.url, url.scheme != "file" {
                if url.scheme == "mailto" {
                    // Open email client
                    UIApplication.shared.open(url)
                    decisionHandler(.cancel)
                    return
                }
            }
            
            decisionHandler(.allow)
        }
    }
}

#Preview {
    LegalView(title: "Privacy Policy", htmlFileName: "PrivacyPolicy")
}
