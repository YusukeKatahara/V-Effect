import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 検索結果の1曲を表すモデル
class MusicItem {
  final String title;
  final String artist;
  final String previewUrl;
  final String artworkUrl;

  const MusicItem({
    required this.title,
    required this.artist,
    required this.previewUrl,
    required this.artworkUrl,
  });

  factory MusicItem.fromJson(Map<String, dynamic> json) {
    // artworkUrl100 が 100x100 のサイズなので、必要に応じて解像度を少し高くする(例: 100x100 -> 300x300)
    String artwork = json['artworkUrl100'] ?? '';
    if (artwork.isNotEmpty) {
      artwork = artwork.replaceAll('100x100bb', '300x300bb');
    }

    return MusicItem(
      title: json['trackName'] ?? '',
      artist: json['artistName'] ?? '',
      previewUrl: json['previewUrl'] ?? '',
      artworkUrl: artwork,
    );
  }

  // SharedPreferences保存用のマップ変換
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'artist': artist,
      'previewUrl': previewUrl,
      'artworkUrl': artworkUrl,
    };
  }

  // SharedPreferencesからの復元用
  factory MusicItem.fromMap(Map<String, dynamic> map) {
    return MusicItem(
      title: map['title'] ?? '',
      artist: map['artist'] ?? '',
      previewUrl: map['previewUrl'] ?? '',
      artworkUrl: map['artworkUrl'] ?? '',
    );
  }

  String toJson() => json.encode(toMap());

  factory MusicItem.fromJsonString(String source) => MusicItem.fromMap(json.decode(source));
}

/// iTunes Search API を利用して楽曲を検索するサービス
class MusicApiService {
  MusicApiService._();
  static final MusicApiService instance = MusicApiService._();

  /// キーワードで楽曲を検索します
  /// [query] 検索キーワード (例: 'Official髭男dism')
  Future<List<MusicItem>> searchSongs(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final uri = Uri.parse('https://itunes.apple.com/search').replace(
        queryParameters: {
          'term': query,
          'entity': 'song',
          'country': 'jp',
          'limit': '30',
        },
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> results = data['results'] ?? [];
        
        // プレビューURLが存在するものだけを抽出
        return results
            .where((item) => item['previewUrl'] != null && item['previewUrl'].toString().isNotEmpty)
            .map((item) => MusicItem.fromJson(item))
            .toList();
      } else {
        debugPrint('iTunes Search API failed with status: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('iTunes Search API error: $e');
      return [];
    }
  }

  /// 日本のトップソング（トレンド）を取得します
  Future<List<MusicItem>> getTopSongs() async {
    try {
      final uri = Uri.parse('https://itunes.apple.com/jp/rss/topsongs/limit=30/json');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> entries = data['feed']?['entry'] ?? [];
        
        final List<MusicItem> topSongs = [];
        for (var entry in entries) {
          final title = entry['im:name']?['label'] ?? '';
          final artist = entry['im:artist']?['label'] ?? '';
          
          // 画像URLの取得（一番大きいサイズを選ぶ）
          final images = entry['im:image'] as List<dynamic>? ?? [];
          String artworkUrl = '';
          if (images.isNotEmpty) {
            artworkUrl = images.last['label'] ?? '';
            // 更に高画質にするために置換
            if (artworkUrl.isNotEmpty) {
              artworkUrl = artworkUrl.replaceAll(RegExp(r'\d+x\d+bb'), '300x300bb');
            }
          }

          // プレビューURLの取得
          final links = entry['link'] as List<dynamic>? ?? [];
          String previewUrl = '';
          for (var link in links) {
            final attrs = link['attributes'];
            if (attrs != null && attrs['rel'] == 'enclosure' && attrs['type']?.startsWith('audio') == true) {
              previewUrl = attrs['href'] ?? '';
              break;
            }
          }

          if (previewUrl.isNotEmpty) {
            topSongs.add(MusicItem(
              title: title,
              artist: artist,
              previewUrl: previewUrl,
              artworkUrl: artworkUrl,
            ));
          }
        }
        return topSongs;
      } else {
        debugPrint('iTunes Top Songs API failed: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('iTunes Top Songs API error: $e');
      return [];
    }
  }

  static const _recentSongsKey = 'v_effect_recent_songs';

  /// 最近使った曲のリストを取得します
  Future<List<MusicItem>> getRecentSongs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> recentList = prefs.getStringList(_recentSongsKey) ?? [];
      return recentList.map((str) => MusicItem.fromJsonString(str)).toList();
    } catch (e) {
      debugPrint('Error getting recent songs: $e');
      return [];
    }
  }

  /// 選択した曲を最近使った曲リストに追加します（最大10件）
  Future<void> addRecentSong(MusicItem item) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> recentList = prefs.getStringList(_recentSongsKey) ?? [];
      
      final currentItems = recentList.map((str) => MusicItem.fromJsonString(str)).toList();
      
      // すでに同じ曲があれば削除（順番を上にするため）
      currentItems.removeWhere((existing) => existing.previewUrl == item.previewUrl);
      
      // 先頭に追加
      currentItems.insert(0, item);
      
      // 10件を超えたら古いものを削除
      if (currentItems.length > 10) {
        currentItems.removeRange(10, currentItems.length);
      }
      
      // 保存
      final updatedList = currentItems.map((i) => i.toJson()).toList();
      await prefs.setStringList(_recentSongsKey, updatedList);
    } catch (e) {
      debugPrint('Error adding recent song: $e');
    }
  }
}
