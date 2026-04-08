// lib/services/location_service.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'api_service.dart';

class LocationService {
  // 👇 MAKE IT A SINGLETON: These 3 lines keep the service alive globally! 👇
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();
  // 👆 ------------------------------------------------------------------- 👆

  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isTracking = false;
  String? _currentPartnerId;

  bool get isTracking => _isTracking;

  /// Start tracking live location via Stream
  Future<void> startLocationTracking(
      String partnerId, {
        Function(String)? onError,
      }) async {
    if (_isTracking && _currentPartnerId == partnerId) {
      debugPrint('⚠️ Location tracking already active for: $partnerId');
      return;
    }

    // Check permissions first
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('⚠️ Location permission denied');
        onError?.call('Location permission denied');
        return;
      }
    }

    _currentPartnerId = partnerId;
    _isTracking = true;

    debugPrint('🌍 Starting LIVE location tracking for partner: $partnerId');

    // Configure the stream to trigger every time the driver moves 5 meters
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // ✨ UPDATE EVERY 5 METERS MOVED
    );

    // Listen to continuous location changes
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      _sendLocationToBackend(position, partnerId, onError);
    }, onError: (error) {
      debugPrint('❌ Location Stream Error: $error');
      onError?.call('Location Stream Error: $error');
    });
  }

  /// Stop location tracking
  void stopLocationTracking() {
    if (_positionStreamSubscription != null) {
      _positionStreamSubscription!.cancel();
      _positionStreamSubscription = null;
      _isTracking = false;
      _currentPartnerId = null;
      debugPrint('🛑 LIVE Location tracking stopped');
    }
  }

  /// Send location to backend
  Future<void> _sendLocationToBackend(
      Position position,
      String partnerId,
      Function(String)? onError,
      ) async {
    try {
      debugPrint('📍 Live Update... Lat: ${position.latitude}, Lng: ${position.longitude}');

      // Send to backend (Which will trigger Pusher!)
      final result = await ApiService.updateLocation(
        partnerId: partnerId,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (result['status'] == 200 || result['success'] == true) {
        debugPrint('✅ Live location pushed successfully');
      } else {
        debugPrint('⚠️ Location update failed: ${result['message']}');
      }
    } catch (e) {
      debugPrint('❌ Error updating location: $e');
    }
  }

  /// Dispose and cleanup
  void dispose() {
    // Note: Since this is a global singleton now, you generally don't want to call dispose
    // unless the user is completely logging out of the app.
    stopLocationTracking();
  }
}