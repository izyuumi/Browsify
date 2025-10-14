//
//  URLCleaner.swift
//  Browsify
//

import Foundation

class URLCleaner {
    static let shared = URLCleaner()

    private let trackingParameters = [
        // Google Analytics
        "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
        "utm_name", "utm_cid", "utm_reader", "utm_viz_id", "utm_pubreferrer",
        "utm_swu",

        // Facebook
        "fbclid", "fb_action_ids", "fb_action_types", "fb_source", "fb_ref",
        "action_object_map", "action_type_map", "action_ref_map",

        // Google
        "gclid", "gclsrc", "dclid", "gbraid", "wbraid",

        // Twitter
        "twclid", "twsrc",

        // TikTok
        "ttclid",

        // Microsoft
        "msclkid",

        // Mail clients
        "mc_cid", "mc_eid",

        // Other common tracking
        "_hsenc", "_hsmi", "mkt_tok", "hmb_campaign", "hmb_medium", "hmb_source",
        "icid", "igshid", "ref", "ref_", "referrer",

        // Amazon
        "pd_rd_i", "pd_rd_r", "pd_rd_w", "pd_rd_wg", "pf_rd_i", "pf_rd_m",
        "pf_rd_p", "pf_rd_r", "pf_rd_s", "pf_rd_t",

        // Generic tracking
        "source", "campaign", "medium", "content", "term",
    ]

    private init() {}

    func cleanURL(_ url: URL, stripTracking: Bool = true) -> URL {
        guard stripTracking else { return url }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        // Remove tracking parameters
        if var queryItems = components?.queryItems {
            queryItems.removeAll { item in
                trackingParameters.contains(item.name.lowercased())
            }

            // If no query items left, set to nil to remove the "?" from URL
            components?.queryItems = queryItems.isEmpty ? nil : queryItems
        }

        return components?.url ?? url
    }

    func shouldStripTracking() -> Bool {
        // This could be user-configurable in preferences
        return UserDefaults.standard.bool(forKey: "stripTrackingParameters")
    }
}
