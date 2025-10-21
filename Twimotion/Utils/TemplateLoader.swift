//
//  TemplateLoader.swift
//  Twimotion
//
//  Created by Vaibhav Parashar on 10/21/25.
//

import Foundation

/// Simple utility to load templates from local bundle
class TemplateLoader {
    
    /// Load templates from local bundle
    /// - Returns: Array of templates
    static func loadTemplates() -> [Template] {
        guard let url = Bundle.main.url(forResource: "templates", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let templates = try? JSONDecoder().decode([Template].self, from: data) else {
            return createDefaultTemplates()
        }
        
        return templates
    }
    
    /// Create default templates as fallback
    /// - Returns: Array of default templates
    private static func createDefaultTemplates() -> [Template] {
        return [
            Template(
                id: "typewriter_dark",
                name: "Typewriter — Dark",
                backgroundAsset: "typewriter_bg.png",
                defaultDuration: 4.0,
                defaultFPS: 24,
                tokens: Template.ColorTokens(bg: "#0B0F14", primary: "#FFFFFF"),
                placeholder: Template.TextPlaceholder(role: "headline", font: "Inter-Bold", fontSize: 56, maxLines: 3, safeInset: 36),
                animation: Template.AnimationConfig(family: "typewriter", minDuration: 3.0, maxDuration: 6.0)
            )
        ]
    }
}
