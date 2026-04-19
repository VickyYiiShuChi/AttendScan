import 'dart:convert';
import 'package:crypto/crypto.dart';

class DiceBearAvatar {
  static const List<String> styles = [
    'adventurer',     
    'avataaars',       
    'bottts',                                
    'micah',          
    'miniavs',            
    'personas',       
    'pixel-art',     
    'big-ears',     
    'big-smile',      
  ];
  
  // default style
  static const String defaultStyle = 'avataaars';
  
  // Generate a DiceBear avatar URL from a seed and options
  static String generateUrl({
    required String seed,
    String style = 'avataaars',
    int size = 200,
    String backgroundColor = 'transparent',
    bool randomize = false,
    String format = 'png',
  }) {
    // Clean seed string
    String cleanSeed = seed.trim().toLowerCase();
    
    // If randomize is requested, append a timestamp to vary the seed
    if (randomize) {
      cleanSeed = '$cleanSeed${DateTime.now().millisecondsSinceEpoch}';
    }
    
    // Create a hash to ensure consistent avatar output for the same seed
    String hash = md5.convert(utf8.encode(cleanSeed)).toString();
    
    // Build request URL (using specified format, e.g. png)
    return 'https://api.dicebear.com/7.x/$style/$format'
        '?seed=$hash'
        '&size=$size'
        '&backgroundColor=$backgroundColor'
        '&radius=50'
        '&scale=100';
  }
  
  // Build a user-specific avatar URL using email/name/userId as seed
  static String getUserAvatar({
    required String userId,
    String? email,
    String? name,
    String style = 'avataaars',
  }) {
    // Prefer email, then username, then userId as seed
    String seed = email ?? name ?? userId;
    
    return generateUrl(
      seed: seed,
      style: style,
      size: 200,
      backgroundColor: 'transparent',
    );
  }
  
  // List available avatar styles and provide a small preview URL
  static List<Map<String, String>> getAvailableStyles() {
    return styles.map((style) {
      String previewUrl = generateUrl(seed: 'preview', style: style, size: 50);
      
      // Display name for the style (use public helper)
      String displayName = getStyleDisplayName(style);
      
      return {
        'id': style,
        'name': displayName,
        'previewUrl': previewUrl,
      };
    }).toList();
  }
  
  // Map internal style id to a human-friendly display name
  static String getStyleDisplayName(String style) {
    switch (style) {
      case 'adventurer': return 'Adventurer';
      case 'avataaars': return 'Avataaars';
      case 'bottts': return 'Bottts';
      case 'croodles': return 'Croodles';
      case 'fun-emoji': return 'Fun Emoji';
      case 'icons': return 'Icons';
      case 'identicon': return 'Identicon';
      case 'lorelei': return 'Lorelei';
      case 'micah': return 'Micah';
      case 'miniavs': return 'Miniavs';
      case 'open-peeps': return 'Open Peeps';
      case 'personas': return 'Personas';
      case 'pixel-art': return 'Pixel Art';
      default: return style;
    }
  }
}