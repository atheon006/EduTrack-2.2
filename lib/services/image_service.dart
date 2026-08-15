import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/storage_util.dart';
import '../utils/constants.dart';

class ImageService {
  static const String uploadUrl = '$baseUrl/upload';
  static const String baseUrl = Constants.apiBaseUrl;

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  /// Multiplatform upload method supporting XFile
  Future<UploadResult?> uploadImage(dynamic imageInput) async {
    try {
      final accessToken = await StorageUtil.getString('accessToken') ?? '';
      
      if (accessToken.isEmpty) {
        _debugLog('⚠️ No authentication token available for image upload');
        return null;
      }

      var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
      request.headers['Authorization'] = 'Bearer $accessToken';

      if (imageInput is XFile) {
        final bytes = await imageInput.readAsBytes();
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: imageInput.name,
        ));
      } else if (imageInput is String) {
        request.files.add(await http.MultipartFile.fromPath('file', imageInput));
      } else {
        _debugLog('⚠️ Unsupported image input format');
        return null;
      }

      var response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final jsonData = json.decode(responseData);

        return UploadResult(
          url: jsonData['url'],
          success: true,
        );
      } else {
        _debugLog('Failed to upload image. Status code: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _debugLog('Error uploading image: $e');
      return null;
    }
  }

  String _getMediaType(dynamic imageInput) {
    String filename = '';
    if (imageInput is XFile) {
      filename = imageInput.name;
    } else if (imageInput is String) {
      filename = imageInput;
    }

    final extension = filename.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return 'image';
      case 'mp4':
      case 'mov':
      case 'avi':
      case 'mkv':
      case 'webm':
        return 'video';
      default:
        return 'image';
    }
  }

  Future<StoryUploadResult?> uploadStoryWithFile({
    required dynamic file,
    required String schoolId,
  }) async {
    try {
      final uploadResult = await uploadImage(file);
      
      if (uploadResult == null || !uploadResult.success) {
        _debugLog('❌ Failed to upload file for story');
        return null;
      }
      
      final mediaType = _getMediaType(file);
      
      return await uploadStory(
        mediaUrl: uploadResult.url,
        mediaType: mediaType,
        schoolId: schoolId,
      );
    } catch (e) {
      _debugLog('💥 Error uploading story with file: $e');
      return null;
    }
  }

  Future<StoryUploadResult?> uploadStory({
    required String mediaUrl,
    required String mediaType,
    required String schoolId,
  }) async {
    try {
      final accessToken = await StorageUtil.getString('accessToken') ?? '';
      
      if (accessToken.isEmpty) {
        _debugLog('⚠️ No authentication token available');
        return null;
      }
      
      final response = await http.post(
        Uri.parse('${uploadUrl.replaceAll('/upload', '')}/story'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode({
          'mediaUrl': mediaUrl,
          'mediaType': mediaType,
          'schoolId': schoolId,
        }),
      );
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return StoryUploadResult(
          success: true,
          storyId: jsonData['storyId'] ?? '',
          mediaUrl: mediaUrl,
        );
      } else {
        return null;
      }
    } catch (e) {
      _debugLog('💥 Error uploading story: $e');
      return null;
    }
  }

  Future<List<Story>> fetchStories(String schoolId) async {
    try {
      final accessToken = await StorageUtil.getString('accessToken') ?? '';
      final schoolToken = await StorageUtil.getString('schoolToken') ?? '';
      
      if (accessToken.isEmpty && schoolToken.isEmpty) {
        return [];
      }
      
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'school-token': schoolToken,
      };
      
      final response = await http.get(
        Uri.parse('${uploadUrl.replaceAll('/upload', '')}/story?schoolId=$schoolId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        
        if (jsonData['success'] == true && jsonData['data'] != null) {
          return (jsonData['data'] as List)
              .map((storyJson) => Story.fromJson(storyJson))
              .toList();
        }
        return [];
      } else {
        return [];
      }
    } catch (e) {
      _debugLog('💥 Error fetching stories: $e');
      return [];
    }
  }

  /// Alias for fetchStories required by dashboard screens
  Future<List<Story>> getStoriesBySchool(String schoolId) async {
    return await fetchStories(schoolId);
  }

  Future<String?> updateProfileImage(dynamic imageInput) async {
    try {
      final imageUrl = await uploadImage(imageInput);
      
      if (imageUrl == null) {
        return null;
      }
      
      final accessToken = await StorageUtil.getString('accessToken') ?? '';
      
      if (accessToken.isEmpty) {
        return null;
      }
      
      final response = await http.post(
        Uri.parse('$baseUrl/users/me/image'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode({
          'urlPath': imageUrl.url,
        }),
      );
      
      if (response.statusCode == 200) {
        return imageUrl.url;
      } else {
        return null;
      }
    } catch (e) {
      _debugLog('💥 Error updating profile image: $e');
      return null;
    }
  }

  Future<String?> getProfileImage(String userId) async {
    try {
      final accessToken = await StorageUtil.getString('accessToken') ?? '';
      if (accessToken.isEmpty) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId/image'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['imageUrl'] ?? data['urlPath'];
      }
      return null;
    } catch (e) {
      _debugLog('💥 Error getting profile image: $e');
      return null;
    }
  }
}

class UploadResult {
  final String url;
  final bool success;

  UploadResult({required this.url, required this.success});
}

class StoryUploadResult {
  final bool success;
  final String storyId;
  final String mediaUrl;

  StoryUploadResult({
    required this.success,
    required this.storyId,
    required this.mediaUrl,
  });
}

class StoryUser {
  final String name;
  final String role;

  StoryUser({this.name = 'User', this.role = 'Member'});

  factory StoryUser.fromJson(Map<String, dynamic>? json) {
    if (json == null) return StoryUser();
    return StoryUser(
      name: json['name'] ?? json['firstName'] ?? 'User',
      role: json['role'] ?? 'Member',
    );
  }
}

class Story {
  final String id;
  final String mediaUrl;
  final String mediaType;
  final String schoolId;
  final DateTime createdAt;
  final StoryUser user;

  Story({
    required this.id,
    required this.mediaUrl,
    required this.mediaType,
    required this.schoolId,
    required this.createdAt,
    StoryUser? user,
  }) : user = user ?? StoryUser();

  factory Story.fromJson(Map<String, dynamic> json) {
    return Story(
      id: json['_id'] ?? json['id'] ?? '',
      mediaUrl: json['mediaUrl'] ?? '',
      mediaType: json['mediaType'] ?? 'image',
      schoolId: json['schoolId'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      user: StoryUser.fromJson(json['user'] as Map<String, dynamic>?),
    );
  }
}
