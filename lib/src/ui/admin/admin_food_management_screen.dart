import 'package:flutter/material.dart';
import 'package:fyp_cinema_app/res/color_app.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp_cinema_app/src/data/cinema_data.dart';

class AdminFoodManagementScreen extends StatefulWidget {
  const AdminFoodManagementScreen({super.key});

  @override
  State<AdminFoodManagementScreen> createState() => _AdminFoodManagementScreenState();
}

class _AdminFoodManagementScreenState extends State<AdminFoodManagementScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _imagePicker = ImagePicker();
  
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Promotion', 'Drinks', 'Fast food'];
  List<String> _cinemaBrands = ['LFS', 'GSC', 'mmCineplexes'];
  String _selectedCinemaBrand = 'LFS';

  @override
  void initState() {
    super.initState();
    // Cinema brands are already set to ['LFS', 'GSC', 'mmCineplexes']
  }
  
  Stream<QuerySnapshot> _buildFoodItemsStream() {
    Query query = _firestore.collection('food_items');
    
    // Always filter by cinema brand since we have specific brands
    query = query.where('cinemaBrand', isEqualTo: _selectedCinemaBrand);
    
    // Filter by category if not 'All'
    if (_selectedCategory != 'All') {
      query = query.where('category', isEqualTo: _selectedCategory);
    }
    
    return query.snapshots();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Food Management',
          style: TextStyle(fontWeight: FontWeight.bold, color:Color(0xFF047857)),
        ),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF047857)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF047857)),
            onPressed: () => _showAddEditDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Cinema Brand Filter
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _cinemaBrands.length,
              itemBuilder: (context, index) {
                final brand = _cinemaBrands[index];
                final isSelected = brand == _selectedCinemaBrand;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: isSelected,
                    label: Text(
                      brand,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onSelected: (selected) {
                      setState(() {
                        _selectedCinemaBrand = brand;
                      });
                    },
                    backgroundColor: Colors.white,
                    selectedColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                );
              },
            ),
          ),
          // Category Filter
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = category == _selectedCategory;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: isSelected,
                    label: Text(
                      category,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                    backgroundColor: Colors.white,
                    selectedColor: ColorApp.primaryDarkColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                );
              },
            ),
          ),
          // Food Items List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildFoodItemsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.restaurant_menu,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No food items found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () => _showAddEditDialog(),
                          icon: const Icon(Icons.add),
                          label: const Text('Add First Item'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ColorApp.primaryDarkColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    
                    return _buildFoodItemCard(doc.id, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodItemCard(String id, Map<String, dynamic> data) {
    final isAvailable = data['available'] != false;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isAvailable ? Colors.white : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: isAvailable ? null : Border.all(color: Colors.red[300]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Food Image
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  children: [
                    Opacity(
                      opacity: isAvailable ? 1.0 : 0.5,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                        ),
                        child: (data['image'] ?? '').startsWith('http')
                            ? Image.network(
                                data['image'],
                                fit: BoxFit.cover,
                                width: 100,
                                height: 100,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 100,
                                    height: 100,
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.image_not_supported),
                                  );
                                },
                              )
                            : Container(
                                width: 100,
                                height: 100,
                                color: Colors.grey[200],
                                child: const Icon(Icons.image),
                              ),
                      ),
                    ),
                    if (data['badge'] != null)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            data['badge'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Food Details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['title'] ?? 'No Title',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'RM${((data['price'] ?? 0.0) as num).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: ColorApp.primaryDarkColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getCategoryColor(data['category']),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                data['category'] ?? 'Unknown',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                data['cinemaBrand'] ?? 'LFS',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            data['available'] != false ? Icons.check_circle : Icons.pause_circle,
                            size: 16,
                            color: data['available'] != false ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            data['available'] != false ? 'Available' : 'Paused',
                            style: TextStyle(
                              fontSize: 12,
                              color: data['available'] != false ? Colors.green : Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if (data['description'] != null && data['description'].isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          data['description'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Action Buttons
              Column(
                children: [
                  IconButton(
                    icon: Icon(
                      data['available'] != false ? Icons.pause : Icons.play_arrow,
                      color: data['available'] != false ? Colors.orange : Colors.green,
                    ),
                    onPressed: () => _toggleAvailability(id, data['available'] != false),
                    tooltip: data['available'] != false ? 'Pause Item' : 'Resume Item',
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _showAddEditDialog(id: id, data: data),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _showDeleteConfirmation(id, data['title'] ?? 'Unknown'),
                  ),
                ],
              ),
            ],
          ),
          if (data['customizable'] == true && data['options'] != null) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Customization Options:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: (data['options'] as List).map<Widget>((option) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          option,
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getCategoryColor(String? category) {
    switch (category) {
      case 'Promotion':
        return Colors.red;
      case 'Drinks':
        return Colors.brown;
      case 'Fast food':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Future<void> _toggleAvailability(String id, bool currentAvailability) async {
    try {
      await _firestore.collection('food_items').doc(id).update({
        'available': !currentAvailability,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            currentAvailability ? 'Item paused successfully' : 'Item resumed successfully'
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating availability: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDeleteConfirmation(String id, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteItem(id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteItem(String id) async {
    try {
      await _firestore.collection('food_items').doc(id).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting item: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAddEditDialog({String? id, Map<String, dynamic>? data}) {
    showDialog(
      context: context,
      builder: (context) => _AddEditFoodDialog(
        id: id,
        initialData: data,
        onSave: () {
          Navigator.pop(context);
          setState(() {}); // Refresh the list
        },
      ),
    );
  }
}

class _AddEditFoodDialog extends StatefulWidget {
  final String? id;
  final Map<String, dynamic>? initialData;
  final VoidCallback onSave;

  const _AddEditFoodDialog({
    this.id,
    this.initialData,
    required this.onSave,
  });

  @override
  State<_AddEditFoodDialog> createState() => _AddEditFoodDialogState();
}

class _AddEditFoodDialogState extends State<_AddEditFoodDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _badgeController = TextEditingController();
  final _optionsController = TextEditingController();
  
  String _selectedCategory = 'Fast food';
  String _selectedCinemaBrand = '';
  bool _isCustomizable = false;
  bool _isAvailable = true;
  File? _selectedImage;
  String? _currentImageUrl;
  bool _isLoading = false;
  
  final List<String> _categories = ['Promotion', 'Drinks', 'Fast food'];
  final List<String> _cinemaBrands = ['LFS', 'GSC', 'mmCineplexes'];

  @override
  void initState() {
    super.initState();
    _selectedCinemaBrand = _cinemaBrands.first;
    if (widget.initialData != null) {
      _populateFields();
    }
  }

  void _populateFields() {
    final data = widget.initialData!;
    _titleController.text = data['title'] ?? '';
    _descriptionController.text = data['description'] ?? '';
    _priceController.text = ((data['price'] ?? 0.0) as num).toString();
    _badgeController.text = data['badge'] ?? '';
    _selectedCategory = data['category'] ?? 'Fast food';
    _selectedCinemaBrand = data['cinemaBrand'] ?? _cinemaBrands.first;
    _isCustomizable = data['customizable'] ?? false;
    _isAvailable = data['available'] ?? true;
    _currentImageUrl = data['image'];
    
    if (data['options'] != null) {
      _optionsController.text = (data['options'] as List).join(', ');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _badgeController.dispose();
    _optionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height * 0.9,
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.id == null ? 'Add Food Item' : 'Edit Food Item',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image Upload Section
                      _buildImageSection(),
                      const SizedBox(height: 16),
                      
                      // Title Field
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Title *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a title';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Description Field
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      
                      // Price Field
                      TextFormField(
                        controller: _priceController,
                        decoration: const InputDecoration(
                          labelText: 'Price (RM) *',
                          border: OutlineInputBorder(),
                          prefixText: 'RM ',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a price';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Category and Cinema Brand Row
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: DropdownButtonFormField<String>(
                              value: _selectedCategory,
                              decoration: const InputDecoration(
                                labelText: 'Category *',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                isDense: true,
                              ),
                              items: _categories.map((category) {
                                return DropdownMenuItem(
                                  value: category,
                                  child: Text(
                                    category,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedCategory = value!;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            flex: 1,
                            child: DropdownButtonFormField<String>(
                              value: _selectedCinemaBrand,
                              decoration: const InputDecoration(
                                labelText: 'Cinema Brand *',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal:8, vertical: 8),
                                isDense: true,
                              ),
                              items: _cinemaBrands.map((brand) {
                                return DropdownMenuItem(
                                  value: brand,
                                  child: Text(
                                    brand,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedCinemaBrand = value!;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Badge Field
                      TextFormField(
                        controller: _badgeController,
                        decoration: const InputDecoration(
                          labelText: 'Badge (optional)',
                          border: OutlineInputBorder(),
                          helperText: 'e.g., "2×1", "Hot", "New"',
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Availability Switch
                      SwitchListTile(
                        title: const Text('Available'),
                        subtitle: const Text('Item is available for customers to order'),
                        value: _isAvailable,
                        onChanged: (value) {
                          setState(() {
                            _isAvailable = value;
                          });
                        },
                        activeColor: Colors.green,
                      ),
                      
                      // Customizable Switch
                      SwitchListTile(
                        title: const Text('Customizable'),
                        subtitle: const Text('Allow customers to customize this item'),
                        value: _isCustomizable,
                        onChanged: (value) {
                          setState(() {
                            _isCustomizable = value;
                          });
                        },
                        activeColor: ColorApp.primaryDarkColor,
                      ),
                      
                      // Options Field (if customizable)
                      if (_isCustomizable) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _optionsController,
                          decoration: const InputDecoration(
                            labelText: 'Customization Options',
                            border: OutlineInputBorder(),
                            helperText: 'Separate options with commas (e.g., "Small, Medium, Large")',
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveItem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorApp.primaryDarkColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          widget.id == null ? 'Add Item' : 'Update Item',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              
              // Temporary debug button - Save without image
              if (_selectedImage != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _saveItemWithoutImage,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      side: const BorderSide(color: ColorApp.primaryDarkColor),
                    ),
                    child: const Text(
                      'Save without Image (Debug)',
                      style: TextStyle(
                        fontSize: 14,
                        color: ColorApp.primaryDarkColor,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          if (_selectedImage != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                _selectedImage!,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
              ),
            )
          else if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                _currentImageUrl!,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: double.infinity,
                    height: 200,
                    color: Colors.grey[200],
                    child: const Icon(Icons.image_not_supported, size: 50),
                  );
                },
              ),
            )
          else
            Container(
              width: double.infinity,
              height: 200,
              color: Colors.grey[200],
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image, size: 50, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('No image selected'),
                ],
              ),
            ),
          Positioned(
            bottom: 8,
            right: 8,
            child: FloatingActionButton.small(
              onPressed: _pickImage,
              backgroundColor: ColorApp.primaryDarkColor,
              child: const Icon(Icons.camera_alt, color: Colors.white),
            ),
          ),
          if (_selectedImage != null)
            Positioned(
              bottom: 8,
              right: 60,
              child: FloatingActionButton.small(
                onPressed: _testDirectUpload,
                backgroundColor: Colors.green,
                child: const Icon(Icons.cloud_upload, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _testDirectUpload() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image first')),
      );
      return;
    }

    try {
      print('=== DIRECT UPLOAD TEST ===');
      
      // Step 1: Check authentication
      final user = FirebaseAuth.instance.currentUser;
      print('✓ User: ${user?.email}');
      
      // Step 2: Initialize storage
      final storage = FirebaseStorage.instance;
      print('✓ Storage bucket: ${storage.bucket}');
      
      // Step 3: Create reference
      final fileName = 'test_direct_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = storage.ref().child('test_uploads').child(fileName);
      print('✓ Reference created: test_uploads/$fileName');
      
      // Step 4: Check file
      final fileSize = await _selectedImage!.length();
      print('✓ File size: ${fileSize} bytes');
      
      // Step 5: Start upload without timeout
      print('✓ Starting upload (no timeout)...');
      final task = ref.putFile(
        _selectedImage!,
        SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'max-age=3600',
          customMetadata: {
            'uploaded_by': user?.email ?? 'unknown',
            'upload_time': DateTime.now().toIso8601String(),
          },
        ),
      );
      
      // Step 6: Listen to progress
      task.snapshotEvents.listen((snapshot) {
        final progress = (snapshot.bytesTransferred / snapshot.totalBytes * 100).toInt();
        print('  Progress: $progress% (${snapshot.bytesTransferred}/${snapshot.totalBytes} bytes)');
        print('  State: ${snapshot.state}');
      });
      
      // Step 7: Wait for completion (no timeout)
      print('✓ Waiting for completion...');
      final snapshot = await task;
      print('✓ Upload completed!');
      print('  Final state: ${snapshot.state}');
      print('  Bytes transferred: ${snapshot.bytesTransferred}');
      
      // Step 8: Get download URL
      print('✓ Getting download URL...');
      final url = await snapshot.ref.getDownloadURL();
      
      print('✅ SUCCESS! Direct upload successful: $url');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Upload successful!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e, stackTrace) {
      print('❌ Direct upload failed: $e');
      print('❌ Error type: ${e.runtimeType}');
      print('❌ Stack trace: $stackTrace');
      
      String errorMsg = 'Upload failed: ';
      if (e.toString().contains('storage/unauthorized')) {
        errorMsg = 'Permission denied - check Storage rules';
      } else if (e.toString().contains('storage/bucket-not-found')) {
        errorMsg = 'Storage not enabled - check Firebase Console';
      } else if (e.toString().contains('network')) {
        errorMsg = 'Network error - check internet connection';
      } else {
        errorMsg += e.toString();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? imageUrl = _currentImageUrl;
      
      // Upload new image if selected
      if (_selectedImage != null) {
        print('=== STARTING IMAGE UPLOAD DEBUG ===');
        
        try {
          // Check Firebase Auth
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) {
            throw Exception('User not authenticated. Please login first.');
          }
          print('✓ User authenticated: ${user.email}');
          
          // Check storage configuration
          final storage = FirebaseStorage.instance;
          print('✓ Storage instance created');
          print('  Storage bucket: ${storage.bucket}');
          
          // Test storage connection first
          print('✓ Testing storage connection...');
          try {
            // Simple connection test - try to list files (this tests auth and connection)
            await storage.ref().listAll();
            print('✓ Storage connection successful');
          } catch (connectionError) {
            print('❌ Storage connection test details: $connectionError');
            // Check if it's just a permission issue vs storage not enabled
            if (connectionError.toString().contains('404') || 
                connectionError.toString().contains('Not Found')) {
              print('✓ Storage is enabled but empty (this is normal)');
            } else {
              print('❌ Storage connection failed: $connectionError');
              throw Exception('Cannot connect to Firebase Storage. Please ensure Storage is enabled in Firebase Console. Error: $connectionError');
            }
          }
          
          final String fileName = 'food_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final Reference ref = storage
              .ref()
              .child('food_images')
              .child(fileName);
          
          print('✓ Storage reference created: food_images/$fileName');
          
          // Check if file exists and is readable
          if (!await _selectedImage!.exists()) {
            throw Exception('Selected image file does not exist');
          }
          
          final fileSize = await _selectedImage!.length();
          print('✓ File exists, size: ${fileSize} bytes');
          
          if (fileSize == 0) {
            throw Exception('Selected image file is empty');
          }
          
          if (fileSize > 10 * 1024 * 1024) { // 10MB limit
            throw Exception('Image file too large (max 10MB)');
          }
          
          print('✓ Starting upload...');
          
          // Try upload with progress monitoring
          UploadTask uploadTask;
          
          try {
            // Method 1: Upload using putFile with metadata
            uploadTask = ref.putFile(
              _selectedImage!,
              SettableMetadata(
                contentType: 'image/jpeg',
                cacheControl: 'max-age=3600',
                customMetadata: {
                  'uploaded_by': user.email ?? 'unknown',
                  'upload_time': DateTime.now().toIso8601String(),
                  'item_type': 'food_item',
                },
              ),
            );
            print('  Using putFile method with metadata');
          } catch (putFileError) {
            print('  putFile failed, trying putData method: $putFileError');
            // Method 2: Upload using putData (alternative method)
            final fileBytes = await _selectedImage!.readAsBytes();
            uploadTask = ref.putData(
              fileBytes,
              SettableMetadata(
                contentType: 'image/jpeg',
                cacheControl: 'max-age=3600',
                customMetadata: {
                  'uploaded_by': user.email ?? 'unknown',
                  'upload_time': DateTime.now().toIso8601String(),
                  'item_type': 'food_item',
                },
              ),
            );
            print('  Using putData method with metadata');
          }
          
          // Listen to upload progress
          uploadTask.snapshotEvents.listen(
            (TaskSnapshot snapshot) {
              final progress = snapshot.bytesTransferred / snapshot.totalBytes;
              print('  Upload progress: ${(progress * 100).toInt()}%');
            },
            onError: (error) {
              print('❌ Upload stream error: $error');
            },
          );
          
          // Wait for upload completion with timeout
          final TaskSnapshot taskSnapshot = await uploadTask.timeout(
            const Duration(minutes: 2),
            onTimeout: () {
              throw Exception('Upload timeout after 2 minutes - please check your internet connection and Firebase Storage configuration');
            },
          );
          
          print('✓ Upload completed successfully');
          print('  Task state: ${taskSnapshot.state}');
          print('  Bytes transferred: ${taskSnapshot.bytesTransferred}');
          print('  Total bytes: ${taskSnapshot.totalBytes}');
          
          print('✓ Getting download URL...');
          imageUrl = await taskSnapshot.ref.getDownloadURL();
          print('✓ Download URL obtained: $imageUrl');
          
        } catch (uploadError) {
          print('❌ UPLOAD ERROR: $uploadError');
          print('❌ Upload error type: ${uploadError.runtimeType}');
          
          // Re-throw with more context
          if (uploadError.toString().contains('storage/unauthorized')) {
            throw Exception('Firebase Storage permission denied. Please check:\n1. Firebase Storage is enabled\n2. Storage security rules allow uploads\n3. User is authenticated');
          } else if (uploadError.toString().contains('storage/bucket-not-found')) {
            throw Exception('Firebase Storage bucket not found. Please enable Firebase Storage in the Firebase Console.');
          } else if (uploadError.toString().contains('channel-error')) {
            throw Exception('Firebase Storage connection error. This may be due to:\n1. Firebase Storage not properly enabled\n2. Network connectivity issues\n3. App Check configuration (warning can be ignored)\nPlease check Firebase Console > Storage');
          } else if (uploadError.toString().contains('AppCheckProvider')) {
            throw Exception('App Check warning detected (can be ignored for development). Actual error: $uploadError');
          } else {
            throw Exception('Image upload failed: $uploadError');
          }
        }
        
        print('=== IMAGE UPLOAD DEBUG COMPLETE ===');
      }

      // Prepare data
      final Map<String, dynamic> itemData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': double.parse(_priceController.text),
        'category': _selectedCategory,
        'cinemaBrand': _selectedCinemaBrand,
        'available': _isAvailable,
        'customizable': _isCustomizable,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (imageUrl != null && imageUrl.isNotEmpty) {
        itemData['image'] = imageUrl;
      }

      if (_badgeController.text.trim().isNotEmpty) {
        itemData['badge'] = _badgeController.text.trim();
      }

      if (_isCustomizable && _optionsController.text.trim().isNotEmpty) {
        itemData['options'] = _optionsController.text
            .split(',')
            .map((option) => option.trim())
            .where((option) => option.isNotEmpty)
            .toList();
      }

      print('=== STARTING FIRESTORE SAVE ===');
      print('Data to save: $itemData');
      
      // Save to Firestore
      if (widget.id == null) {
        // Add new item
        itemData['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('food_items').add(itemData);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Food item added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Update existing item
        await FirebaseFirestore.instance
            .collection('food_items')
            .doc(widget.id)
            .update(itemData);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Food item updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      print('✓ Firestore save completed successfully');
      widget.onSave();
    } catch (e, stackTrace) {
      print('=== FULL ERROR DETAILS ===');
      print('❌ Error: $e');
      print('❌ Error type: ${e.runtimeType}');
      print('❌ Stack trace: $stackTrace');
      print('=== END ERROR DETAILS ===');
      
      // Provide specific error messages
      String errorMessage = 'Error saving item: ';
      
      if (e.toString().contains('storage/unauthorized') || e.toString().contains('permission denied')) {
        errorMessage = 'Firebase Storage permission denied. Please:\n• Enable Firebase Storage in Console\n• Check storage security rules\n• Ensure you are logged in';
      } else if (e.toString().contains('storage/object-not-found')) {
        errorMessage = 'Storage bucket not found. Please enable Firebase Storage.';
      } else if (e.toString().contains('storage/bucket-not-found')) {
        errorMessage = 'Storage bucket not configured. Please set up Firebase Storage.';
      } else if (e.toString().contains('network') || e.toString().contains('connection')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'Upload timeout. Please try again or check your Firebase Storage setup.';
      } else if (e.toString().contains('not authenticated')) {
        errorMessage = 'Authentication required. Please login again.';
      } else if (e.toString().contains('file does not exist')) {
        errorMessage = 'Selected image file is invalid. Please select a different image.';
      } else if (e.toString().contains('file too large')) {
        errorMessage = 'Image file is too large. Please select a smaller image (max 10MB).';
      } else {
        errorMessage += e.toString();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 10),
          action: SnackBarAction(
            label: 'Details',
            textColor: Colors.white,
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Full Error Details'),
                  content: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Error: $e'),
                        const SizedBox(height: 8),
                        Text('Type: ${e.runtimeType}'),
                        const SizedBox(height: 8),
                        const Text('Stack Trace:'),
                        Text(stackTrace.toString(), style: const TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveItemWithoutImage() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Prepare data
      final Map<String, dynamic> itemData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': double.parse(_priceController.text),
        'category': _selectedCategory,
        'cinemaBrand': _selectedCinemaBrand,
        'available': _isAvailable,
        'customizable': _isCustomizable,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_badgeController.text.trim().isNotEmpty) {
        itemData['badge'] = _badgeController.text.trim();
      }

      if (_isCustomizable && _optionsController.text.trim().isNotEmpty) {
        itemData['options'] = _optionsController.text
            .split(',')
            .map((option) => option.trim())
            .where((option) => option.isNotEmpty)
            .toList();
      }

      print('Saving to Firestore...');
      
      // Save to Firestore
      if (widget.id == null) {
        // Add new item
        itemData['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('food_items').add(itemData);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Food item added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Update existing item
        await FirebaseFirestore.instance
            .collection('food_items')
            .doc(widget.id)
            .update(itemData);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Food item updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      print('Save completed successfully');
      widget.onSave();
    } catch (e) {
      print('Detailed error: $e');
      print('Error type: ${e.runtimeType}');
      
      // Provide specific error messages
      String errorMessage = 'Error saving item: ';
      if (e.toString().contains('storage/unauthorized')) {
        errorMessage = 'Permission denied. Please check Firebase Storage rules in the Firebase Console.';
      } else if (e.toString().contains('storage/object-not-found')) {
        errorMessage = 'Storage bucket not found. Please enable Firebase Storage.';
      } else if (e.toString().contains('storage/bucket-not-found')) {
        errorMessage = 'Storage bucket not configured. Please set up Firebase Storage.';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'Upload timeout. Please try again or check your Firebase Storage setup.';
      } else if (e.toString().contains('not authenticated')) {
        errorMessage = 'Authentication required. Please login again.';
      } else {
        errorMessage += e.toString();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'Details',
            textColor: Colors.white,
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Error Details'),
                  content: SingleChildScrollView(
                    child: Text('$e'),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
} 