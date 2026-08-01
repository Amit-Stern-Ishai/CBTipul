import Foundation

/// Supabase project credentials.
///
/// Replace the placeholder anon (publishable) key with your project's key,
/// found in the Supabase dashboard under Settings → API.
enum SupabaseConfig {
    static let urlString = "https://cckklnxteyumsgiptfck.supabase.co"
    static let anonKey = "sb_publishable_FRfa8QyxuwnZ8dr167r39w_3OeXwq_a"

    /// True once the placeholders above have been replaced with real values.
    static var isConfigured: Bool {
        !urlString.contains("YOUR-PROJECT-REF") && anonKey != "YOUR-ANON-KEY"
    }

    static var url: URL {
        URL(string: urlString)!
    }
}
