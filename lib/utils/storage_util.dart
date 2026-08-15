import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// A utility class for handling local storage operations
/// with proper error handling and fallback mechanisms
class StorageUtil {
  // In-memory backup cache in case SharedPreferences fails
  static final Map<String, dynamic> _memoryCache = {};
  // Always start with true to avoid unnecessary error messages
  static bool _sharedPreferencesAvailable = true;
  static bool _initialized = false;
  static SharedPreferences? _prefsInstance;

  // Initialize and check if SharedPreferences is available
  static Future<bool> init() async {
    // If already initialized and we have an instance, verify it's still valid
    if (_initialized && _prefsInstance != null) {
      try {
        // Quick test to verify the instance is still valid after hot reload
        final testKey = 'storage_util_quick_test';
        final testVal = DateTime.now().millisecondsSinceEpoch.toString();
        await _prefsInstance!.setString(testKey, testVal);
        final readVal = _prefsInstance!.getString(testKey);
        
        // Instance is still valid
        if (readVal == testVal) {
          print('✅ SharedPreferences instance still valid after hot reload');
          return _sharedPreferencesAvailable;
        } else {
          print('⚠️ SharedPreferences instance corrupted, reinitializing...');
          _initialized = false;
          _prefsInstance = null;
        }
      } catch (e) {
        print('⚠️ Error checking SharedPreferences after hot reload: $e');
        // Handle potential issues with the instance
        _initialized = false;
        _prefsInstance = null;
      }
    }

    try {
      // Get SharedPreferences instance and store it
      _prefsInstance = await SharedPreferences.getInstance();
      
      // Try to write and read a test value
      final testKey = 'storage_util_test_key';
      final testValue = 'test_value_${DateTime.now().millisecondsSinceEpoch}';
      
      await _prefsInstance!.setString(testKey, testValue);
      final readValue = _prefsInstance!.getString(testKey);
      
      _sharedPreferencesAvailable = (readValue == testValue);
      
      print('🔍 SharedPreferences test - Write: "$testValue", Read: "$readValue"');
      print('🔍 SharedPreferences working: $_sharedPreferencesAvailable');
      
      if (!_sharedPreferencesAvailable) {
        print('⚠️ WARNING: SharedPreferences integrity check failed!');
        print('⚠️ Falling back to in-memory storage only');
      } else {
        print('✅ SharedPreferences working correctly');
      }
      
      // Force commit the preferences to disk (important for some devices)
      // Only for Android platform
      try {
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          await _prefsInstance!.commit();
        }
      } catch (e) {
        print('⚠️ Platform check error (probably on web): $e');
      }
      
      _initialized = true;
      return _sharedPreferencesAvailable;
    } catch (e) {
      print('⚠️ ERROR in StorageUtil.init(): $e');
      _initialized = true;
      _sharedPreferencesAvailable = false;
      return false;
    }
  }

  /// Gets a boolean value from storage by key
  /// Falls back to in-memory cache if SharedPreferences fails
  static Future<bool?> getBool(String key) async {
    await init(); // Ensure initialized
    try {
      if (_sharedPreferencesAvailable && _prefsInstance != null) {
        final value = _prefsInstance!.getBool(key);
        _memoryCache[key] = value; // Backup to memory
        return value;
      }
    } catch (e) {
      print('⚠️ Error getting boolean ($key): $e');
    }
    return _memoryCache[key] as bool?;
  }

  /// Sets a boolean value in storage
  /// Also updates the in-memory cache as a fallback
  static Future<bool> setBool(String key, bool value) async {
    await init(); // Ensure initialized
    _memoryCache[key] = value; // Always save to memory cache
    
    if (_sharedPreferencesAvailable && _prefsInstance != null) {
      try {
        await _prefsInstance!.setBool(key, value);
        
        // Force commit for Android
        try {
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
            await _prefsInstance!.commit();
          }
        } catch (e) {
          // Ignore platform errors on web
        }
        
        return true;
      } catch (e) {
        print('⚠️ Error setting boolean ($key): $e');
        _sharedPreferencesAvailable = false;
      }
    }
    
    print('📝 Saved in memory cache only: $key: $value');
    return false;
  }

  /// Gets a string value from storage by key
  /// Falls back to in-memory cache if SharedPreferences fails
  static Future<String?> getString(String key) async {
    await init(); // Ensure initialized
    try {
      if (_sharedPreferencesAvailable && _prefsInstance != null) {
        final value = _prefsInstance!.getString(key);
        _memoryCache[key] = value; // Backup to memory
        return value;
      }
    } catch (e) {
      print('⚠️ Error getting string ($key): $e');
    }
    return _memoryCache[key] as String?;
  }

  /// Sets a string value in storage
  /// Also updates the in-memory cache as a fallback
  static Future<bool> setString(String key, String value) async {
    await init(); // Ensure initialized
    _memoryCache[key] = value; // Always save to memory cache
    
    if (_sharedPreferencesAvailable && _prefsInstance != null) {
      try {
        await _prefsInstance!.setString(key, value);
        
        // Force commit for Android
        try {
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
            await _prefsInstance!.commit();
          }
        } catch (e) {
          // Ignore platform errors on web
        }
        
        print('✓ Saved to SharedPreferences: $key: $value');
        return true;
      } catch (e) {
        print('⚠️ Error setting string ($key): $e');
        _sharedPreferencesAvailable = false;
      }
    }
    
    print('📝 Saved in memory cache only: $key: $value');
    return false;
  }

  /// Clears all storage
  static Future<bool> clear() async {
    await init(); // Ensure initialized
    _memoryCache.clear();
    
    if (_sharedPreferencesAvailable && _prefsInstance != null) {
      try {
        await _prefsInstance!.clear();
        
        // Force commit for Android
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          await _prefsInstance!.commit();
        }
        
        return true;
      } catch (e) {
        print('⚠️ Error clearing preferences: $e');
        return false;
      }
    }
    
    return true; // Memory cache was cleared
  }

  /// Dump all stored values for debugging
  static Future<void> debugDumpAll() async {
    await init(); // Ensure initialized
    
    print('🔍 ==========================================');
    print('🔍 SharedPreferences available: $_sharedPreferencesAvailable');
    
    if (_prefsInstance != null) {
      try {
        final keys = _prefsInstance!.getKeys();
        print('🔍 SharedPreferences keys count: ${keys.length}');
        
        for (var key in keys) {
          print('🔍 $key: ${_prefsInstance!.get(key)}');
        }
      } catch (e) {
        print('⚠️ Error dumping SharedPreferences: $e');
      }
    }
    
    print('🔍 Memory cache keys count: ${_memoryCache.length}');
    _memoryCache.forEach((key, value) {
      print('🔍 (Memory) $key: $value');
    });
    print('🔍 ==========================================');
  }
}
