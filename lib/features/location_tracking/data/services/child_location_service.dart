import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/location_model.dart';
import '../datasources/location_remote_datasource.dart';

class ChildLocationService {
  final LocationRemoteDataSource _locationDataSource;
  final FirebaseFirestore _firestore;
  
  StreamSubscription<Position>? _positionStream;
  Timer? _locationTimer;
  String? _parentId;
  String? _childId;
  bool _isTracking = false;

  ChildLocationService({
    required LocationRemoteDataSource locationDataSource,
    FirebaseFirestore? firestore,
  }) : _locationDataSource = locationDataSource,
       _firestore = firestore ?? FirebaseFirestore.instance;

  /// Initialize location tracking for child
  Future<void> initializeLocationTracking() async {
    try {
      // Get parent and child IDs from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      _parentId = prefs.getString('parent_uid');
      _childId = prefs.getString('child_uid');

      if (_parentId == null || _childId == null) {
        print('Parent or child ID not found in SharedPreferences');
        return;
      }

      print('Initialized location tracking for child: $_childId');
    } catch (e) {
      print('Error initializing location tracking: $e');
    }
  }

  /// Start location tracking
  Future<void> startLocationTracking() async {
    if (_parentId == null || _childId == null) {
      await initializeLocationTracking();
      if (_parentId == null || _childId == null) {
        throw Exception('Parent or child ID not found');
      }
    }

    // Check if already tracking
    if (_isTracking) {
      print('Location tracking already active');
      return;
    }

    try {
      print('Starting location tracking...');
      _isTracking = true;

      // Request location permission
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final newPermission = await Geolocator.requestPermission();
        if (newPermission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      // Enable location services
      await _locationDataSource.enableLocationTracking(
        parentId: _parentId!,
        childId: _childId!,
        enabled: true,
      );

      // Start listening to location updates
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters
        ),
      ).listen(
        (Position position) => _onLocationUpdate(position),
        onError: (error) => print('Location stream error: $error'),
      );

      print('Location tracking started for child: $_childId');
    } catch (e) {
      print('Error starting location tracking: $e');
      _isTracking = false;
      rethrow;
    }
  }

  /// Stop location tracking
  Future<void> stopLocationTracking() async {
    try {
      print('Stopping location tracking...');
      _isTracking = false;
      
      // Cancel position stream
      await _positionStream?.cancel();
      _positionStream = null;
      
      // Cancel timer
      _locationTimer?.cancel();
      _locationTimer = null;
      
      // Update Firebase that tracking is disabled
      if (_parentId != null && _childId != null) {
        await _locationDataSource.enableLocationTracking(
          parentId: _parentId!,
          childId: _childId!,
          enabled: false,
        );
      }

      print('Location tracking stopped successfully');
    } catch (e) {
      print('Error stopping location tracking: $e');
    }
  }

  /// Handle location updates
  Future<void> _onLocationUpdate(Position position) async {
    if (!_isTracking || _parentId == null || _childId == null) {
      return;
    }

    try {
      // Get address from coordinates
      String address = 'Location not available';
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks[0];
          address = '${place.street ?? ''}, ${place.locality ?? ''}, ${place.administrativeArea ?? ''}';
          address = address.replaceAll(RegExp(r',\s*,'), ',').trim();
        }
      } catch (e) {
        print('Error getting address: $e');
      }

      // Create location model
      final location = LocationModel(
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
        accuracy: position.accuracy,
        timestamp: DateTime.now(),
        isTrackingEnabled: true,
        status: 'online',
      );

      // Update location in Firebase
      await _locationDataSource.updateChildLocation(
        parentId: _parentId!,
        childId: _childId!,
        location: location,
      );

      print('Location updated: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      print('Error updating location: $e');
    }
  }

  /// Check if location tracking is active
  bool get isTrackingActive => _isTracking;

  /// Dispose resources
  void dispose() {
    print('Disposing ChildLocationService...');
    _isTracking = false;
    _positionStream?.cancel();
    _positionStream = null;
    _locationTimer?.cancel();
    _locationTimer = null;
    
    
    print('ChildLocationService disposed');
  }
}
