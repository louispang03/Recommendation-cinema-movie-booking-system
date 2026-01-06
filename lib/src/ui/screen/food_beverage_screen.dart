import 'package:flutter/material.dart';
import 'package:fyp_cinema_app/res/color_app.dart';
import 'package:fyp_cinema_app/src/ui/screen/cart_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_cinema_app/src/data/cinema_data.dart';

class FoodBeverageScreen extends StatefulWidget {
  const FoodBeverageScreen({super.key});

  @override
  State<FoodBeverageScreen> createState() => _FoodBeverageScreenState();
}

class _FoodBeverageScreenState extends State<FoodBeverageScreen> {
  String _selectedCategory = 'Promotion';
  String _selectedCinemaBrand = '';
  List<Map<String, dynamic>> _cartItems = [];

  final List<String> _categories = ['Promotion', 'Drinks', 'Fast food'];
  final List<String> _cinemaBrands = CinemaData.getCinemaBrands();

  @override
  void initState() {
    super.initState();
    if (_cinemaBrands.isNotEmpty) {
      _selectedCinemaBrand = _cinemaBrands.first;
    }
  }

  int get _cartItemCount {
    return _cartItems.fold(0, (sum, item) => sum + (item['quantity'] as int));
  }

  void _addToCart(Map<String, dynamic> item, {List<String>? selectedOptions, int quantity = 1}) {
    final existingItemIndex = _cartItems.indexWhere((cartItem) =>
        cartItem['id'] == item['id'] &&
        _optionsMatch(cartItem['selectedOptions'], selectedOptions));

    if (existingItemIndex >= 0) {
      setState(() {
        _cartItems[existingItemIndex]['quantity'] += quantity;
      });
    } else {
      setState(() {
        _cartItems.add({
          ...item,
          'quantity': quantity,
          'selectedOptions': selectedOptions ?? [],
          'cartId': DateTime.now().millisecondsSinceEpoch.toString(),
        });
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item['title']} added to cart'),
        duration: const Duration(seconds: 1),
        backgroundColor: ColorApp.primaryDarkColor,
      ),
    );
  }

  bool _optionsMatch(List<String>? options1, List<String>? options2) {
    if (options1 == null && options2 == null) return true;
    if (options1 == null || options2 == null) return false;
    if (options1.length != options2.length) return false;
    
    final sorted1 = List<String>.from(options1)..sort();
    final sorted2 = List<String>.from(options2)..sort();
    
    for (int i = 0; i < sorted1.length; i++) {
      if (sorted1[i] != sorted2[i]) return false;
    }
    return true;
  }

  void _showItemDetails(Map<String, dynamic> item) {
    if (!item['customizable']) {
      _addToCart(item);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildItemCustomizationSheet(item),
    );
  }

  Widget _buildItemCustomizationSheet(Map<String, dynamic> item) {
    List<String> selectedOptions = [];
    int quantity = 1;

    return StatefulBuilder(
      builder: (context, setSheetState) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Item image and basic info
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: item['image'].startsWith('http')
                                ? Image.network(
                                    item['image'],
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Image.asset(
                                        'assets/images/food.png',
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                      );
                                    },
                                  )
                                : Image.asset(
                                    item['image'],
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['title'],
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'RM${item['price'].toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: ColorApp.primaryDarkColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item['description'],
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 3,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Customization options
                      if (item['options'] != null && (item['options'] as List).isNotEmpty) ...[
                        const Text(
                          'Customize your order (select multiple):',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...List.generate(
                          (item['options'] as List).length,
                          (index) {
                            final option = (item['options'] as List)[index];
                            final isSelected = selectedOptions.contains(option);
                            return CheckboxListTile(
                              title: Text(option),
                              value: isSelected,
                              onChanged: (value) {
                                setSheetState(() {
                                  if (value == true) {
                                    selectedOptions.add(option);
                                  } else {
                                    selectedOptions.remove(option);
                                  }
                                });
                              },
                              activeColor: ColorApp.primaryDarkColor,
                              contentPadding: EdgeInsets.zero,
                            );
                          },
                        ),
                      ],
                      
                      const SizedBox(height: 24),
                      
                      // Quantity selector
                      Row(
                        children: [
                          const Text(
                            'Quantity:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              IconButton(
                                onPressed: quantity > 1 ? () {
                                  setSheetState(() {
                                    quantity--;
                                  });
                                } : null,
                                icon: const Icon(Icons.remove),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.grey[200],
                                ),
                              ),
                              Container(
                                width: 50,
                                height: 40,
                                alignment: Alignment.center,
                                child: Text(
                                  quantity.toString(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  setSheetState(() {
                                    quantity++;
                                  });
                                },
                                icon: const Icon(Icons.add),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.grey[200],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      
                      const Spacer(),
                      
                      // Add to cart button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _addToCart(item, selectedOptions: selectedOptions, quantity: quantity);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ColorApp.primaryDarkColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Add ${quantity > 1 ? '$quantity items' : 'item'} to cart - RM${(item['price'] * quantity).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Menu',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          )
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart, color: Colors.black),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CartScreen(
                        cartItems: _cartItems,
                        onUpdateCart: (updatedItems) {
                          setState(() {
                            _cartItems = updatedItems;
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
              if (_cartItemCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _cartItemCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Cinema Brand Selection Section
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Cinema Brand Selection Row
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedCinemaBrand.isNotEmpty ? _selectedCinemaBrand : null,
                        decoration: const InputDecoration(
                          labelText: 'Select Cinema Brand',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.business),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: _cinemaBrands.map((brand) {
                          return DropdownMenuItem(
                            value: brand,
                            child: Text(
                              brand,
                              style: const TextStyle(fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCinemaBrand = value ?? '';
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
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
          // Food Items List with Real-time Updates
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('food_items')
                  .where('category', isEqualTo: _selectedCategory)
                  .where('cinemaBrand', isEqualTo: _selectedCinemaBrand)
                  .where('available', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading menu',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.red[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please try again later',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
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
                          'No $_selectedCategory items available for $_selectedCinemaBrand',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try selecting a different cinema brand or category!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
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
                    final item = {
                      'id': doc.id,
                      'title': data['title'] ?? '',
                      'price': (data['price'] ?? 0.0).toDouble(),
                      'image': data['image'] ?? 'assets/images/food.png',
                      'category': data['category'] ?? 'Fast food',
                      'description': data['description'] ?? '',
                      'customizable': data['customizable'] ?? false,
                      'options': data['options'] ?? [],
                      'badge': data['badge'],
                    };

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GestureDetector(
                        onTap: () => _showItemDetails(item),
                        child: Container(
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Food Image with potential badge
                              SizedBox(
                                width: 100,
                                height: 100,
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(12),
                                        bottomLeft: Radius.circular(12),
                                      ),
                                      child: item['image'].startsWith('http')
                                          ? Image.network(
                                              item['image'],
                                              fit: BoxFit.cover,
                                              width: 100,
                                              height: 100,
                                              errorBuilder: (context, error, stackTrace) {
                                                return Image.asset(
                                                  'assets/images/food.png',
                                                  fit: BoxFit.cover,
                                                  width: 100,
                                                  height: 100,
                                                );
                                              },
                                            )
                                          : Image.asset(
                                              item['image'],
                                              fit: BoxFit.cover,
                                              width: 100,
                                              height: 100,
                                            ),
                                    ),
                                    if (item['badge'] != null)
                                      Positioned(
                                        top: 8,
                                        left: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            item['badge'],
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
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
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              item['title'],
                                              style: const TextStyle(
                                                color: Colors.black,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'RM${item['price'].toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                color: ColorApp.primaryDarkColor,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (item['description'] != null && item['description'].isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                item['description'],
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 12,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      // Add Button
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: ColorApp.primaryDarkColor,
                                          shape: BoxShape.circle,
                                        ),
                                        child: IconButton(
                                          padding: EdgeInsets.zero,
                                          icon: const Icon(Icons.add),
                                          iconSize: 20,
                                          color: Colors.white,
                                          onPressed: () => _showItemDetails(item),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 
