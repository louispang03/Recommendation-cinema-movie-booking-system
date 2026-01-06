import 'package:flutter/material.dart';
import 'package:fyp_cinema_app/src/model/banner/banner_movie.dart';
import 'package:fyp_cinema_app/src/services/admin_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class MovieFormScreen extends StatefulWidget {
  final BannerMovie? movie;

  const MovieFormScreen({super.key, this.movie});

  @override
  State<MovieFormScreen> createState() => _MovieFormScreenState();
}

class _MovieFormScreenState extends State<MovieFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _adminService = AdminService();
  final _imagePicker = ImagePicker();
  final _storage = FirebaseStorage.instance;
  bool _isLoading = false;

  late TextEditingController _titleController;
  late TextEditingController _overviewController;
  late TextEditingController _releaseDateController;
  
  File? _posterImage;
  File? _backdropImage;
  List<String> _selectedCategories = [];
  List<String> _selectedCinemaBrands = [];
  Map<String, List<String>> _showtimes = {};
  
  final List<String> _categories = ['banner', 'coming_soon', 'popular', 'now_playing'];
  final List<String> _cinemaBrands = ['LFS', 'GSC', 'mmCineplexes'];
  final List<String> _timeSlots = ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM'];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.movie?.title);
    _overviewController = TextEditingController(text: widget.movie?.overview);
    _releaseDateController = TextEditingController(text: widget.movie?.releaseDate);
    _selectedCategories = widget.movie?.categories ?? ['coming_soon'];
    _selectedCinemaBrands = widget.movie?.cinemaBrands ?? [];
    _showtimes = widget.movie?.showtimes ?? {};
  }

  @override
  void dispose() {
    _titleController.dispose();
    _overviewController.dispose();
    _releaseDateController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source, bool isPoster) async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      final XFile? image = await _imagePicker.pickImage(source: source);
      if (image != null) {
        setState(() {
          if (isPoster) {
            _posterImage = File(image.path);
          } else {
            _backdropImage = File(image.path);
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _selectReleaseDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _releaseDateController.text.isNotEmpty 
          ? DateTime.tryParse(_releaseDateController.text) ?? DateTime.now()
          : DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF047857),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _releaseDateController.text = picked.toIso8601String().split('T')[0];
      });
    }
  }

  Future<String?> _uploadImage(File image, String path) async {
    try {
      final ref = _storage.ref().child(path);
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'max-age=31536000',
      );
      final uploadTask = ref.putFile(image, metadata);
      
      // Add timeout to prevent hanging
      final snapshot = await uploadTask.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Upload timeout - please try again');
        },
      );
      
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _saveMovie() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one category')),
      );
      return;
    }
    
    // Check if coming soon is selected and release date is required
    final isComingSoonSelected = _selectedCategories.contains('coming_soon');
    if (isComingSoonSelected && (_releaseDateController.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Release date is required for Coming Soon movies'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Check if cinema selection is required (not for coming soon only)
    final isComingSoonOnly = _selectedCategories.length == 1 && _selectedCategories.contains('coming_soon');
    if (!isComingSoonOnly && _selectedCinemaBrands.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one cinema brand for bookable movies')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? posterUrl;
      String? backdropUrl;

      // Upload images if selected
      if (_posterImage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Uploading image...'),
            duration: Duration(seconds: 2),
          ),
        );
        
        posterUrl = await _uploadImage(_posterImage!, 'movies/posters/${DateTime.now().millisecondsSinceEpoch}_poster.jpg');
        if (posterUrl == null) {
          // Show dialog to ask if user wants to continue without image
          final shouldContinue = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Upload Failed'),
              content: const Text('Failed to upload image. Would you like to save the movie without the image?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Continue'),
                ),
              ],
            ),
          );
          
          if (shouldContinue != true) {
            return;
          }
          posterUrl = null; // Continue without image
        }
      }

      if (_backdropImage != null) {
        backdropUrl = await _uploadImage(_backdropImage!, 'movies/backdrops/${DateTime.now().millisecondsSinceEpoch}_backdrop.jpg');
        if (backdropUrl == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error uploading backdrop image')),
          );
          return;
        }
      }

      final movie = BannerMovie(
        id: widget.movie?.id ?? DateTime.now().millisecondsSinceEpoch,
        title: _titleController.text,
        overview: _overviewController.text,
        posterPath: posterUrl ?? widget.movie?.posterPath,
        backdropPath: backdropUrl ?? widget.movie?.backdropPath,
        releaseDate: _releaseDateController.text,
        isComingSoon: _selectedCategories.contains('coming_soon'),
        categories: _selectedCategories,
        cinemaBrands: isComingSoonOnly ? [] : _selectedCinemaBrands,
        showtimes: isComingSoonOnly ? {} : _showtimes,
        imageUrl: posterUrl,
        // Preserve existing data or set defaults for new fields
        genres: widget.movie?.genres,
        runtime: widget.movie?.runtime,
        originalLanguage: widget.movie?.originalLanguage,
        cast: widget.movie?.cast,
      );

      if (widget.movie != null) {
        await _adminService.updateMovie(movie);
      } else {
        await _adminService.addMovie(movie);
      }

      if (!mounted) return;
      
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.movie != null ? 'Movie updated' : 'Movie added'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(widget.movie != null ? 'Edit Movie' : 'Add Movie',style: const TextStyle(
            color: Color(0xFF047857),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          )),
        backgroundColor: const Color(0xFFF9FAFB),
        iconTheme: const IconThemeData(color: Color(0xFF047857)),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 16.0),
              // Title Field
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              
              // Overview Field
              TextFormField(
                controller: _overviewController,
                decoration: const InputDecoration(
                  labelText: 'Overview',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an overview';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              
              // Release Date Field
              GestureDetector(
                onTap: _selectReleaseDate,
                child: AbsorbPointer(
                  child: TextFormField(
                    controller: _releaseDateController,
                    decoration: InputDecoration(
                      labelText: 'Release Date',
                      border: const OutlineInputBorder(),
                      hintText: 'Tap to select date',
                      suffixIcon: _selectedCategories.contains('coming_soon') 
                          ? const Icon(Icons.calendar_today, color: Colors.orange)
                          : const Icon(Icons.calendar_today),
                      helperText: _selectedCategories.contains('coming_soon') 
                          ? 'Required for Coming Soon movies'
                          : 'Tap to select date',
                    ),
                    readOnly: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select a release date';
                      }
                      return null;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16.0),
              
              // Category Selection
              const Text(
                'Movie Categories:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _categories.map((category) {
                  final isSelected = _selectedCategories.contains(category);
                  final isComingSoon = category == 'coming_soon';
                  final isDisabled = isComingSoon && _selectedCategories.isNotEmpty && !_selectedCategories.contains('coming_soon') ||
                                   !isComingSoon && _selectedCategories.contains('coming_soon');
                  
                  return FilterChip(
                    label: Text(category.replaceAll('_', ' ').toUpperCase()),
                    selected: isSelected,
                    onSelected: isDisabled ? null : (selected) {
                      setState(() {
                        if (selected) {
                          if (isComingSoon) {
                            // If selecting coming soon, clear all other categories
                            _selectedCategories = ['coming_soon'];
                          } else {
                            // If selecting other category, remove coming soon if it exists
                            _selectedCategories.remove('coming_soon');
                            _selectedCategories.add(category);
                          }
                        } else {
                          _selectedCategories.remove(category);
                        }
                      });
                    },
                    backgroundColor: isDisabled ? Colors.grey[300] : null,
                    selectedColor: isComingSoon ? Colors.orange[600] : null,
                    checkmarkColor: isComingSoon ? Colors.white : null,
                  );
                }).toList(),
              ),
              if (_selectedCategories.contains('coming_soon'))
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Note: Coming Soon movies cannot be assigned to other categories',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[700],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              const SizedBox(height: 16.0),
              
              // Cinema Brands Selection (only if not coming soon only)
              if (!(_selectedCategories.length == 1 && _selectedCategories.contains('coming_soon'))) ...[
                const Text(
                  'Cinema Brands:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _cinemaBrands.map((brand) {
                    final isSelected = _selectedCinemaBrands.contains(brand);
                    return FilterChip(
                      label: Text(brand),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedCinemaBrands.add(brand);
                          } else {
                            _selectedCinemaBrands.remove(brand);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16.0),
              ],
              
              // Showtimes Management (only if not coming soon only and cinema brands selected)
              if (!(_selectedCategories.length == 1 && _selectedCategories.contains('coming_soon')) && _selectedCinemaBrands.isNotEmpty) ...[
                const Text(
                  'Showtimes:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ..._selectedCinemaBrands.map((brand) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            brand,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: _timeSlots.map((time) {
                              final isSelected = _showtimes[brand]?.contains(time) ?? false;
                              return FilterChip(
                                label: Text(time),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    _showtimes[brand] ??= [];
                                    if (selected) {
                                      _showtimes[brand]!.add(time);
                                    } else {
                                      _showtimes[brand]!.remove(time);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                const SizedBox(height: 16.0),
              ],
              
              // Image Upload Section
              const Text(
                'Movie Poster:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              
              // Poster Image Upload
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _pickImage(ImageSource.gallery, true),
                  icon: _isLoading 
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.image),
                  label: Text(_isLoading 
                      ? 'Uploading...' 
                      : _posterImage != null ? 'Change Poster' : 'Upload Poster'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF047857),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (_posterImage != null) ...[
                const SizedBox(height: 8),
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(_posterImage!, fit: BoxFit.cover),
                  ),
                ),
              ],
              const SizedBox(height: 24.0),
              
              // Save Button
              SizedBox(
                height: 50.0,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveMovie,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF047857),
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          widget.movie != null ? 'Update Movie' : 'Add Movie',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 