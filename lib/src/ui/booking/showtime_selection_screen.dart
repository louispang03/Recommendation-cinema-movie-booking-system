import 'package:flutter/material.dart';
import 'package:fyp_cinema_app/res/color_app.dart';
import 'package:fyp_cinema_app/src/ui/booking/seat_selection_screen.dart';
import 'package:fyp_cinema_app/src/data/cinema_data.dart';

class ShowtimeSelectionScreen extends StatefulWidget {
  final Map<String, dynamic> movie;

  const ShowtimeSelectionScreen({
    super.key,
    required this.movie,
  });

  @override
  State<ShowtimeSelectionScreen> createState() => _ShowtimeSelectionScreenState();
}

class _ShowtimeSelectionScreenState extends State<ShowtimeSelectionScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedCinema;
  String? _selectedCinemaBrand;
  String? _selectedBrandFilter;
  String _selectedStateFilter = 'All';
  bool _showFilters = false;
  
  List<CinemaLocation> _filteredCinemas = [];
  List<CinemaLocation> _allCinemas = [];
  List<String> _availableCinemaBrands = [];
  Map<String, List<String>> _movieShowtimes = {};

  @override
  void initState() {
    super.initState();
    _loadMovieData();
    _loadAllCinemas();
  }

  void _loadMovieData() {
    // Extract cinema brands and showtimes from movie data
    if (widget.movie['cinemaBrands'] != null) {
      _availableCinemaBrands = List<String>.from(widget.movie['cinemaBrands']);
      if (_availableCinemaBrands.isNotEmpty) {
        _selectedCinemaBrand = _availableCinemaBrands.first;
      }
    }
    
    if (widget.movie['showtimes'] != null) {
      _movieShowtimes = Map<String, List<String>>.from(widget.movie['showtimes']);
    }
  }

  void _loadAllCinemas() {
    _allCinemas = [];
    // Only load cinemas for brands that show this movie
    for (var brand in _availableCinemaBrands) {
      if (CinemaData.allCinemas.containsKey(brand)) {
        for (var region in CinemaData.allCinemas[brand]!.keys) {
          _allCinemas.addAll(CinemaData.allCinemas[brand]![region]!);
        }
      }
    }
    _filteredCinemas = List.from(_allCinemas);
  }

  void _applyFilters() {
    setState(() {
      _filteredCinemas = _allCinemas.where((cinema) {
        bool brandMatch = _selectedBrandFilter == null || cinema.brand == _selectedBrandFilter;
        bool stateMatch = _selectedStateFilter == 'All' || cinema.region == _selectedStateFilter;
        return brandMatch && stateMatch;
      }).toList();
      
      // Reset selected cinema if it's not in filtered results
      if (_selectedCinema != null && !_filteredCinemas.any((c) => c.name == _selectedCinema)) {
        _selectedCinema = null;
      }
    });
  }

  List<String> _getAvailableStates() {
    Set<String> states = {'All'};
    for (var cinema in _allCinemas) {
      states.add(cinema.region);
    }
    return states.toList();
  }

  Color _getBrandColor(String brand) {
    switch (brand) {
      case 'LFS':
        return Colors.purple;
      case 'GSC':
        return Colors.red;
      case 'mmCineplexes':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  void _showFilterDialog() {
    String tempStateFilter = _selectedStateFilter;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text(
            'Filter by State/Region',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // State Selection
              const Text(
                'State/Region:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: tempStateFilter,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: _getAvailableStates().map((state) {
                  return DropdownMenuItem(
                    value: state,
                    child: Text(state),
                  );
                }).toList(),
                onChanged: (value) {
                  setDialogState(() {
                    tempStateFilter = value!;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setDialogState(() {
                  tempStateFilter = 'All';
                });
              },
              child: const Text('Clear'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedStateFilter = tempStateFilter;
                });
                _applyFilters();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorApp.primaryDarkColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<DateTime> dates = List.generate(7, (index) {
      return DateTime.now().add(Duration(days: index));
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Date & Time'),
        backgroundColor: ColorApp.primaryDarkColor,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Movie Info
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.movie['title'],
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getGenresString(),
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // Date Selection
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Date:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: dates.length,
                    itemBuilder: (context, index) {
                      final date = dates[index];
                      final isSelected = date.year == _selectedDate.year &&
                          date.month == _selectedDate.month &&
                          date.day == _selectedDate.day;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDate = date;
                            _selectedCinema = null;
                          });
                        },
                        child: Container(
                          width: 80,
                          margin: const EdgeInsets.only(right: 16),
                          decoration: BoxDecoration(
                            color: isSelected ? ColorApp.primaryDarkColor : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? ColorApp.primaryDarkColor : Colors.grey[300]!,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _getDayName(date.weekday),
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${date.day}',
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _getMonthName(date.month),
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Cinema Brand Filter
          if (_availableCinemaBrands.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filter by Cinema Brand:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: _availableCinemaBrands.map((brand) {
                      final isSelected = _selectedBrandFilter == brand;
                      return FilterChip(
                        label: Text(brand),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedBrandFilter = brand;
                            } else {
                              _selectedBrandFilter = null; // Deselect to show all
                            }
                            _selectedCinema = null;
                          });
                          _applyFilters();
                        },
                        selectedColor: ColorApp.primaryDarkColor,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],

          // Filter Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Cinemas (${_filteredCinemas.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _showFilterDialog,
                  icon: const Icon(Icons.filter_list, size: 20),
                  label: const Text('Filter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorApp.primaryDarkColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Cinema List
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: _filteredCinemas.length,
            itemBuilder: (context, index) {
                final cinema = _filteredCinemas[index];
                final isSelected = _selectedCinema == cinema.name;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? ColorApp.primaryDarkColor.withOpacity(0.1) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? ColorApp.primaryDarkColor : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedCinema = cinema.name;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
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
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  cinema.region,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'RM ${cinema.basePrice.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: ColorApp.primaryDarkColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            cinema.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 8),
                          if (isSelected) ...[
                            const Divider(),
                            const Text(
                              'Available Showtimes:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _getAvailableShowtimes(cinema.brand).map((time) {
                                return ChoiceChip(
                                  label: Text(time),
                                  selected: false,
                                  onSelected: (selected) {
                                    if (selected) {
                                      // Directly proceed to seat selection when time is selected
                                      final cinema = _filteredCinemas.firstWhere((c) => c.name == _selectedCinema);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => SeatSelectionScreen(
                                            movie: widget.movie,
                                            selectedDate: '${_getDayName(_selectedDate.weekday)}, ${_selectedDate.day} ${_getMonthName(_selectedDate.month)}',
                                            selectedTime: time,
                                            selectedCinema: _selectedCinema!,
                                            basePrice: cinema.basePrice,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  selectedColor: ColorApp.primaryDarkColor,
                                  labelStyle: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 12,
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

          ],
        ),
      ),
    );
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '';
    }
  }

  String _getMonthName(int month) {
    switch (month) {
      case 1:
        return 'Jan';
      case 2:
        return 'Feb';
      case 3:
        return 'Mar';
      case 4:
        return 'Apr';
      case 5:
        return 'May';
      case 6:
        return 'Jun';
      case 7:
        return 'Jul';
      case 8:
        return 'Aug';
      case 9:
        return 'Sep';
      case 10:
        return 'Oct';
      case 11:
        return 'Nov';
      case 12:
        return 'Dec';
      default:
        return '';
    }
  }

  List<String> _getAvailableShowtimes(String cinemaBrand) {
    // Return movie-specific showtimes if available, otherwise fallback to cinema default
    if (_movieShowtimes.containsKey(cinemaBrand)) {
      return _movieShowtimes[cinemaBrand]!;
    }
    
    // Fallback to cinema default showtimes
    final cinema = _allCinemas.firstWhere(
      (c) => c.brand == cinemaBrand,
      orElse: () => _allCinemas.first,
    );
    return cinema.showtimes;
  }

  String _getGenresString() {
    if (widget.movie['genres'] != null) {
      final genres = widget.movie['genres'] as List;
      
      // Handle different genre data formats
      List<String> genreStrings = genres.map((g) {
        if (g is String) {
          // Direct string format (from recommendation engine)
          return g;
        } else if (g is Map && g['name'] != null) {
          // Object format with 'name' property (from TMDB API)
          return g['name'].toString();
        } else {
          // Fallback for unexpected formats
          return g.toString();
        }
      }).toList();
      
      return genreStrings.join(', ');
    } else if (widget.movie['genre_ids'] != null) {
      final Map<int, String> genreMap = {
        28: 'Action',
        12: 'Adventure',
        16: 'Animation',
        35: 'Comedy',
        80: 'Crime',
        99: 'Documentary',
        18: 'Drama',
        10751: 'Family',
        14: 'Fantasy',
        36: 'History',
        27: 'Horror',
        10402: 'Music',
        9648: 'Mystery',
        10749: 'Romance',
        878: 'Science Fiction',
        10770: 'TV Movie',
        53: 'Thriller',
        10752: 'War',
        37: 'Western',
      };
      
      final List<String> genreNames = (widget.movie['genre_ids'] as List)
          .map((id) => genreMap[id] ?? 'Unknown')
          .toList();
      return genreNames.join(', ');
    }
    return 'Unknown';
  }
} 