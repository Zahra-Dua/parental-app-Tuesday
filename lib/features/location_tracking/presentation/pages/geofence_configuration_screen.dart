import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/media_query_helpers.dart';

class GeofenceConfigurationScreen extends StatefulWidget {
  final String childId;
  final String childName;

  const GeofenceConfigurationScreen({
    super.key,
    required this.childId,
    required this.childName,
  });

  @override
  State<GeofenceConfigurationScreen> createState() => _GeofenceConfigurationScreenState();
}

class _GeofenceConfigurationScreenState extends State<GeofenceConfigurationScreen> {
  GoogleMapController? _mapController;
  final TextEditingController _nameController = TextEditingController();
  double _radius = 1000.0; // in meters
  LatLng _centerLocation = const LatLng(33.6844, 73.0479); // Islamabad
  Set<Circle> _geofenceCircles = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = '${widget.childName}\'s Safe Zone';
    _updateGeofenceCircle();
  }

  void _updateGeofenceCircle() {
    setState(() {
      _geofenceCircles = {
        Circle(
          circleId: const CircleId('geofence'),
          center: _centerLocation,
          radius: _radius,
          fillColor: AppColors.darkCyan.withOpacity(0.2),
          strokeColor: AppColors.darkCyan,
          strokeWidth: 2,
        ),
      };
    });
  }

  void _onMapTap(LatLng position) {
    setState(() {
      _centerLocation = position;
    });
    _updateGeofenceCircle();
  }

  void _onRadiusChanged(double value) {
    setState(() {
      _radius = value;
    });
    _updateGeofenceCircle();
  }

  Future<void> _saveGeofence() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: Save geofence to Firebase
      await Future.delayed(const Duration(seconds: 1)); // Simulate API call
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Geofence saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving geofence: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MQ(context);

    return Scaffold(
      backgroundColor: AppColors.lightCyan,
      appBar: AppBar(
        title: Text('${widget.childName}\'s Geofence'),
        backgroundColor: AppColors.lightCyan,
        elevation: 0,
        foregroundColor: AppColors.textDark,
      ),
      body: Column(
        children: [
          // Name Input
          Container(
            margin: EdgeInsets.all(mq.w(0.04)),
            padding: EdgeInsets.all(mq.w(0.04)),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: 'Enter geofence name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.darkCyan),
                ),
              ),
            ),
          ),

          // Map
          Expanded(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: mq.w(0.04)),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: GoogleMap(
                  onMapCreated: (GoogleMapController controller) {
                    _mapController = controller;
                  },
                  onTap: _onMapTap,
                  initialCameraPosition: CameraPosition(
                    target: _centerLocation,
                    zoom: 15.0,
                  ),
                  circles: _geofenceCircles,
                  markers: {
                    Marker(
                      markerId: const MarkerId('center'),
                      position: _centerLocation,
                      infoWindow: const InfoWindow(
                        title: 'Geofence Center',
                        snippet: 'Tap to move center',
                      ),
                    ),
                  },
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: true,
                  mapType: MapType.normal,
                ),
              ),
            ),
          ),

          // Radius Slider
          Container(
            margin: EdgeInsets.all(mq.w(0.04)),
            padding: EdgeInsets.all(mq.w(0.04)),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Radius',
                      style: TextStyle(
                        fontSize: mq.sp(0.05),
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      '${_radius.toInt()} m',
                      style: TextStyle(
                        fontSize: mq.sp(0.05),
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkCyan,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: mq.h(0.02)),
                Slider(
                  value: _radius,
                  min: 0.0,
                  max: 2000.0,
                  divisions: 40,
                  activeColor: AppColors.darkCyan,
                  inactiveColor: AppColors.darkCyan.withOpacity(0.3),
                  onChanged: _onRadiusChanged,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '0m',
                      style: TextStyle(
                        fontSize: mq.sp(0.035),
                        color: AppColors.textLight,
                      ),
                    ),
                    Text(
                      '2000m',
                      style: TextStyle(
                        fontSize: mq.sp(0.035),
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Save Button
          Container(
            margin: EdgeInsets.fromLTRB(
              mq.w(0.04),
              0,
              mq.w(0.04),
              mq.h(0.02),
            ),
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveGeofence,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkCyan,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: mq.h(0.02)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      'Save',
                      style: TextStyle(
                        fontSize: mq.sp(0.05),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
