import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fyp_cinema_app/src/services/cinema_location_service.dart';
import 'package:fyp_cinema_app/res/color_app.dart';

class CinemaLocatorScreen extends StatefulWidget {
  const CinemaLocatorScreen({super.key});

  @override
  State<CinemaLocatorScreen> createState() => _CinemaLocatorScreenState();
}

class _CinemaLocatorScreenState extends State<CinemaLocatorScreen> {
  final CinemaLocationService _locationService = CinemaLocationService();
  GoogleMapController? _mapController;
  Position? _currentPosition;
  List<CinemaWithDistance> _allCinemas = [];
  List<CinemaWithDistance> _filteredCinemas = [];
  Set<Marker> _markers = {};
  bool _isLoading = true;
  String _selectedBrand = 'All';
  bool _showMapView = true;
  List<String> _availableBrands = ['All'];

  @override
  void initState() {
    super.initState();
    _getCurrentLocationAndLoadCinemas();
  }

  Future<void> _getCurrentLocationAndLoadCinemas() async {
    try {
      setState(() {
        _isLoading = true;
      });

      print('🔄 Starting location request...');
      
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      print('📍 Location services enabled: $serviceEnabled');
      
      if (!serviceEnabled) {
        throw Exception('Location services are disabled. Please enable location services in your device settings.');
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      print('🔐 Current permission: $permission');
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        print('🔐 Permission after request: $permission');
        
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied. Please grant location permission to find nearby cinemas.');
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied. Please enable location permission in app settings.');
      }

      print('🎯 Getting current position...');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      
      print('✅ Got position: ${position.latitude}, ${position.longitude}');
      
      if (position != null) {
        setState(() {
          _currentPosition = position;
        });
        await _loadNearestCinemas();
        _updateMapMarkers();
        print('🎪 Loaded ${_filteredCinemas.length} cinemas');
      }
    } catch (e) {
      print('❌ Location error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _getCurrentLocationAndLoadCinemas,
            ),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadNearestCinemas() async {
    if (_currentPosition == null) return;

    try {
      print('🔍 Searching for nearby cinemas...');
      
      // Use Google Places API to find real cinemas
      final cinemas = await _locationService.findNearbyCinemas(_currentPosition!);
      
      setState(() {
        _allCinemas = cinemas;
        _availableBrands = _locationService.getAvailableBrands(cinemas);
        _filteredCinemas = _locationService.filterCinemasByBrand(cinemas, _selectedBrand);
      });
      
      print('🎯 Found ${cinemas.length} total cinemas, ${_filteredCinemas.length} after filtering');
      
    } catch (e) {
      print('❌ Error loading cinemas: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error finding cinemas: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _updateMapMarkers() {
    if (_currentPosition == null) return;

    Set<Marker> markers = {};

    // Add user location marker
    markers.add(
      Marker(
        markerId: const MarkerId('user_location'),
        position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(
          title: 'Your Location',
          snippet: 'You are here',
        ),
      ),
    );

    // Add cinema markers
    for (int i = 0; i < _filteredCinemas.length; i++) {
      final cinemaWithDistance = _filteredCinemas[i];
      final cinema = cinemaWithDistance.cinema;
      
      double markerHue;
      switch (cinema.brand.toLowerCase()) {
        case 'gsc':
          markerHue = BitmapDescriptor.hueRed;
          break;
        case 'lfs':
          markerHue = BitmapDescriptor.hueGreen;
          break;
        case 'mmcineplexes':
          markerHue = BitmapDescriptor.hueOrange;
          break;
        default:
          markerHue = BitmapDescriptor.hueRed;
      }

      markers.add(
        Marker(
          markerId: MarkerId('cinema_$i'),
          position: LatLng(cinema.latitude, cinema.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(markerHue),
          infoWindow: InfoWindow(
            title: cinema.name,
            snippet: '${cinemaWithDistance.formattedDistance} • ${cinema.brand}',
          ),
          onTap: () => _showCinemaDetails(cinemaWithDistance),
        ),
      );
    }

    setState(() {
      _markers = markers;
    });
  }

  void _showCinemaDetails(CinemaWithDistance cinemaWithDistance) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getBrandColor(cinemaWithDistance.cinema.brand),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    cinemaWithDistance.cinema.brand,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  cinemaWithDistance.formattedDistance,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              cinemaWithDistance.cinema.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.grey, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    cinemaWithDistance.cinema.address,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.phone, color: Colors.grey, size: 20),
                const SizedBox(width: 8),
                Text(
                  cinemaWithDistance.cinema.phone,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _launchDirections(cinemaWithDistance.cinema),
                    icon: const Icon(Icons.directions),
                    label: const Text('Directions'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorApp.primaryDarkColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _launchPhone(cinemaWithDistance.cinema.phone),
                    icon: const Icon(Icons.phone),
                    label: const Text('Call'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getBrandColor(String brand) {
    switch (brand.toLowerCase()) {
      case 'gsc':
        return Colors.red;
      case 'lfs':
        return Colors.green;
      case 'mmcineplexes':
        return Colors.orange;
      default:
        return ColorApp.primaryDarkColor;
    }
  }

  Future<void> _launchDirections(Cinema cinema) async {
    final url = 'https://www.google.com/maps/dir/?api=1&destination=${cinema.latitude},${cinema.longitude}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  Future<void> _launchPhone(String phoneNumber) async {
    final url = 'tel:$phoneNumber';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  void _onBrandChanged(String? brand) {
    if (brand != null && brand != _selectedBrand) {
      setState(() {
        _selectedBrand = brand;
        _filteredCinemas = _locationService.filterCinemasByBrand(_allCinemas, brand);
      });
      _updateMapMarkers();
      print('🏷️ Filtered to ${_filteredCinemas.length} cinemas for brand: $brand');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cinema Locator'),
        backgroundColor: ColorApp.primaryDarkColor,
        actions: [
          IconButton(
            icon: Icon(_showMapView ? Icons.list : Icons.map),
            onPressed: () {
              setState(() {
                _showMapView = !_showMapView;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _getCurrentLocationAndLoadCinemas,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Finding GSC, LFS & mmCineplexes near you...'),
                ],
              ),
            )
          : Column(
              children: [
                // Brand filter with enhanced description
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[200]!),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.local_movies, color: ColorApp.primaryDarkColor),
                          const SizedBox(width: 8),
                          const Text(
                            'Malaysian Cinema Chains',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: ColorApp.primaryDarkColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text(
                            'Filter by brand:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButton<String>(
                              value: _selectedBrand,
                              isExpanded: true,
                              items: _availableBrands.map((brand) {
                                Color? brandColor;
                                if (brand != 'All') {
                                  brandColor = _getBrandColor(brand);
                                }
                                
                                return DropdownMenuItem(
                                  value: brand,
                                  child: Row(
                                    children: [
                                      if (brandColor != null) ...[
                                        Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: brandColor,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      Text(brand),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: _onBrandChanged,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Content
                Expanded(
                  child: _showMapView ? _buildMapView() : _buildListView(),
                ),
              ],
            ),
    );
  }

  Widget _buildMapView() {
    if (_currentPosition == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.location_off,
                size: 80,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              const Text(
                'Location Not Available',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Unable to get your current location.\nYou can still view all cinema locations in list view.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _showMapView = false;
                  });
                },
                icon: const Icon(Icons.list),
                label: const Text('View Cinema List'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorApp.primaryDarkColor,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _getCurrentLocationAndLoadCinemas,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return GoogleMap(
      onMapCreated: (GoogleMapController controller) {
        _mapController = controller;
      },
      initialCameraPosition: CameraPosition(
        target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        zoom: 12.0,
      ),
      markers: _markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
    );
  }

  Widget _buildListView() {
    if (_filteredCinemas.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.local_movies,
                size: 80,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              const Text(
                'No Cinemas Found',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _selectedBrand == 'All' 
                  ? 'No GSC, LFS, or mmCineplexes cinemas found in your area.\nTry expanding the search radius or check your location.'
                  : 'No $_selectedBrand cinemas found nearby.\nTry selecting "All" to see other cinema chains.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _getCurrentLocationAndLoadCinemas,
                icon: const Icon(Icons.refresh),
                label: const Text('Search Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorApp.primaryDarkColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredCinemas.length,
      itemBuilder: (context, index) {
        final cinemaWithDistance = _filteredCinemas[index];
        final cinema = cinemaWithDistance.cinema;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => _showCinemaDetails(cinemaWithDistance),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getBrandColor(cinema.brand),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          cinema.brand,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          cinemaWithDistance.formattedDistance,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    cinema.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.grey, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          cinema.address,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.phone, color: Colors.grey, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        cinema.phone,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _launchDirections(cinema),
                          icon: const Icon(Icons.directions, size: 16),
                          label: const Text('Directions'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ColorApp.primaryDarkColor,
                            side: const BorderSide(color: ColorApp.primaryDarkColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _launchPhone(cinema.phone),
                          icon: const Icon(Icons.phone, size: 16),
                          label: const Text('Call'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green,
                            side: const BorderSide(color: Colors.green),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
} 