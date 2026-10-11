import 'package:flutter/material.dart';

import '../../shared/models/app_models.dart';
import 'v3_locale_copy.dart';

/// Real nodes grouped by ISO country code. Auto routes and malformed codes
/// (anything beyond two letters) stay out, so the region chips answer
/// "what is a region" from one source of truth.
Map<String, List<NodeModel>> v3GroupNodesByCountry(List<NodeModel> nodes) {
  final groups = <String, List<NodeModel>>{};
  for (final node in nodes) {
    if (node.isAuto) continue;
    final code = node.code.trim().toUpperCase();
    if (RegExp(r'^[A-Z]{2}$').hasMatch(code)) {
      groups.putIfAbsent(code, () => []).add(node);
    }
  }
  return groups;
}

/// Localized country name for a region code; unknown codes fall back to the
/// code itself.
String v3NodeCountryName(BuildContext context, String code) => v3Copy(context,
  zh: _names[code] ?? code,
  en: _englishNames[code] ?? code,
  tw: _traditionalNames[code] ?? code);

const Map<String, String> _names = {
  'US': '美国', 'CA': '加拿大', 'MX': '墨西哥', 'BR': '巴西',
  'GB': '英国', 'FR': '法国', 'DE': '德国', 'NL': '荷兰',
  'ES': '西班牙', 'IT': '意大利', 'RU': '俄罗斯', 'IN': '印度',
  'HK': '香港', 'TW': '台湾', 'JP': '日本', 'KR': '韩国',
  'SG': '新加坡', 'MY': '马来西亚', 'TH': '泰国', 'VN': '越南',
  'PH': '菲律宾', 'ID': '印度尼西亚', 'AU': '澳大利亚',
  'NZ': '新西兰', 'ZA': '南非', 'AE': '阿联酋', 'TR': '土耳其',
};
const Map<String, String> _englishNames = {
  'US': 'United States', 'CA': 'Canada', 'MX': 'Mexico', 'BR': 'Brazil',
  'GB': 'United Kingdom', 'FR': 'France', 'DE': 'Germany',
  'NL': 'Netherlands', 'ES': 'Spain', 'IT': 'Italy', 'RU': 'Russia',
  'IN': 'India', 'HK': 'Hong Kong', 'TW': 'Taiwan', 'JP': 'Japan',
  'KR': 'South Korea', 'SG': 'Singapore', 'MY': 'Malaysia',
  'TH': 'Thailand', 'VN': 'Vietnam', 'PH': 'Philippines',
  'ID': 'Indonesia', 'AU': 'Australia', 'NZ': 'New Zealand',
  'ZA': 'South Africa', 'AE': 'United Arab Emirates', 'TR': 'Turkey',
};
const Map<String, String> _traditionalNames = {
  'US': '美國', 'CA': '加拿大', 'MX': '墨西哥', 'BR': '巴西',
  'GB': '英國', 'FR': '法國', 'DE': '德國', 'NL': '荷蘭',
  'ES': '西班牙', 'IT': '義大利', 'RU': '俄羅斯', 'IN': '印度',
  'HK': '香港', 'TW': '台灣', 'JP': '日本', 'KR': '韓國',
  'SG': '新加坡', 'MY': '馬來西亞', 'TH': '泰國', 'VN': '越南',
  'PH': '菲律賓', 'ID': '印尼', 'AU': '澳洲', 'NZ': '紐西蘭',
  'ZA': '南非', 'AE': '阿拉伯聯合大公國', 'TR': '土耳其',
};
