import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'pages/search_page.dart';
import 'pages/scrap_item_details_page.dart';
import 'components/bottom_navbar.dart';

class EcommerceHomePage extends StatefulWidget {
  final bool showNavbar;
  
  const EcommerceHomePage({super.key, this.showNavbar = true});

  @override
  State<EcommerceHomePage> createState() => _EcommerceHomePageState();
}

class _EcommerceHomePageState extends State<EcommerceHomePage> with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int _selectedIndex = 0;
  int _selectedCategoryIndex = 0;
  
  late AnimationController _searchAnimationController;
  late Animation<double> _searchAnimation;
  bool _isSearchExpanded = false;
  final GlobalKey _searchBarKey = GlobalKey();

  final List<String> _categories = [
    'All Items',
    'PVC Items',
    'Metal Items',
    'Plastic Items',
    'Pipe Items',
  ];

  final List<Map<String, dynamic>> _brands = [
    {
      'name': 'Sell B2B',
      'icon': Icons.business,
      'isSelected': true,
    },
    {
      'name': 'Sell B2C',
      'icon': Icons.people,
      'isSelected': false,
    },
    {
      'name': 'Buy Scrap',
      'icon': Icons.shopping_cart,
      'isSelected': false,
    },
    {
      'name': 'Track Rates',
      'icon': Icons.trending_up,
      'isSelected': false,
    },
    {
      'name': 'My Orders',
      'icon': Icons.list_alt,
      'isSelected': false,
    },
  ];

  final List<Map<String, dynamic>> _products = [
    {
      'name': "PVC ग्रे (Gr) 31",
      'price': '₹31/kg',
      'change': '+2.4%',
      'changeColor': Colors.green,
      'chartData': [28.0, 29.5, 30.2, 30.8, 31.0],
      'isFavorite': false,
    },
    {
      'name': "U PVC पांढरा (Gr) 33",
      'price': '₹33/kg',
      'change': '-1.2%',
      'changeColor': Colors.red,
      'chartData': [34.0, 33.8, 33.5, 33.2, 33.0],
      'isFavorite': false,
    },
    {
      'name': "मोडणीब PVC (A) 18",
      'price': '₹18/kg',
      'change': '+5.7%',
      'changeColor': Colors.green,
      'chartData': [16.5, 17.0, 17.2, 17.8, 18.0],
      'isFavorite': false,
    },
    {
      'name': "सुपिंग (Gr) 25",
      'price': '₹25/kg',
      'change': '+8.1%',
      'changeColor': Colors.green,
      'chartData': [22.0, 23.0, 23.5, 24.2, 25.0],
      'isFavorite': false,
    },
    {
      'name': "निळ PVC (Gr) 23",
      'price': '₹23/kg',
      'change': '+3.2%',
      'changeColor': Colors.green,
      'chartData': [21.0, 21.5, 22.0, 22.5, 23.0],
      'isFavorite': false,
    },
    {
      'name': "PVC SWR (G) 16",
      'price': '₹16/kg',
      'change': '-2.1%',
      'changeColor': Colors.red,
      'chartData': [17.0, 16.8, 16.5, 16.2, 16.0],
      'isFavorite': false,
    },
    {
      'name': "मिक्स बुलिंग (Gr) 28",
      'price': '₹28/kg',
      'change': '+7.0%',
      'changeColor': Colors.green,
      'chartData': [25.0, 26.0, 26.5, 27.2, 28.0],
      'isFavorite': false,
    },
    {
      'name': "कलरवाईझ बुलिंग (Gr) 30",
      'price': '₹30/kg',
      'change': '+7.0%',
      'changeColor': Colors.green,
      'chartData': [27.0, 28.0, 28.5, 29.2, 30.0],
      'isFavorite': false,
    },
    {
      'name': "HD ढक्कन मिक्स (Gr) 30",
      'price': '₹30/kg',
      'change': '+4.5%',
      'changeColor': Colors.green,
      'chartData': [28.0, 28.5, 29.0, 29.5, 30.0],
      'isFavorite': false,
    },
    {
      'name': "पिवळा (Gr) 34",
      'price': '₹34/kg',
      'change': '+5.0%',
      'changeColor': Colors.green,
      'chartData': [31.0, 32.0, 32.5, 33.2, 34.0],
      'isFavorite': false,
    },
    {
      'name': "सिल्वर (Gr) 36",
      'price': '₹36/kg',
      'change': '+5.0%',
      'changeColor': Colors.green,
      'chartData': [33.0, 34.0, 34.5, 35.2, 36.0],
      'isFavorite': false,
    },
    {
      'name': "प्याराशूट (Gr) 36",
      'price': '₹36/kg',
      'change': '+5.0%',
      'changeColor': Colors.green,
      'chartData': [33.0, 34.0, 34.5, 35.2, 36.0],
      'isFavorite': false,
    },
    {
      'name': "जॉन्सन (Gr) 32",
      'price': '₹32/kg',
      'change': '+10.0%',
      'changeColor': Colors.green,
      'chartData': [28.0, 29.0, 30.0, 31.0, 32.0],
      'isFavorite': false,
    },
    {
      'name': "केरवा (Gr) 35",
      'price': '₹35/kg',
      'change': '+5.0%',
      'changeColor': Colors.green,
      'chartData': [32.0, 33.0, 33.5, 34.2, 35.0],
      'isFavorite': false,
    },
    {
      'name': "समृद्वी घड़ा (Gr) 34",
      'price': '₹34/kg',
      'change': '+3.8%',
      'changeColor': Colors.green,
      'chartData': [31.0, 32.0, 32.5, 33.2, 34.0],
      'isFavorite': false,
    },
    {
      'name': "सलाईन LD (Gr) 62",
      'price': '₹62/kg',
      'change': '+2.1%',
      'changeColor': Colors.green,
      'chartData': [58.0, 59.0, 60.0, 61.0, 62.0],
      'isFavorite': false,
    },
    {
      'name': "सलाईन नळी (A) 18",
      'price': '₹18/kg',
      'change': '-1.5%',
      'changeColor': Colors.red,
      'chartData': [19.0, 18.8, 18.5, 18.2, 18.0],
      'isFavorite': false,
    },
    {
      'name': "ब्ल्यु-ड्रम फर्स्ट (Gr) 45",
      'price': '₹45/kg',
      'change': '+4.2%',
      'changeColor': Colors.green,
      'chartData': [42.0, 43.0, 43.5, 44.2, 45.0],
      'isFavorite': false,
    },
    {
      'name': "रिलायन्स पाईप (Gr) 45",
      'price': '₹45/kg',
      'change': '+3.1%',
      'changeColor': Colors.green,
      'chartData': [42.0, 43.0, 43.5, 44.2, 45.0],
      'isFavorite': false,
    },
    {
      'name': "कोटिंग ड्रम (Gr) 25",
      'price': '₹25/kg',
      'change': '+2.8%',
      'changeColor': Colors.green,
      'chartData': [23.0, 23.5, 24.0, 24.5, 25.0],
      'isFavorite': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _searchAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _searchAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _searchAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _searchAnimationController.dispose();
    super.dispose();
  }

  void _navigateToSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SearchPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Black background for the dramatic effect
      body: Column(
        children: [
          // Upper white section with header and search
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // Header Section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Hamburger menu
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.menu,
                            color: Colors.black,
                            size: 18,
                          ),
                        ),
                            // Brand name
                            const Text(
                              'Scraply',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                                letterSpacing: 0.5,
                              ),
                            ),
                        // Shopping bag
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.shopping_bag_outlined,
                            color: Colors.black,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                    child: Hero(
                      tag: 'search_bar',
                      child: Material(
                        color: Colors.transparent,
                        child: GestureDetector(
                          onTap: _navigateToSearch,
                          child: Container(
                            key: _searchBarKey,
                            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.search,
                                  color: Colors.black,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'Search your needs',
                                    style: TextStyle(
                                      color: Color(0xFF999999),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 4),
          
          // Brand Selection Section
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4.0),
            padding: const EdgeInsets.symmetric(vertical: 8.0),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1), // Light yellow background
                borderRadius: BorderRadius.circular(20), // Slightly reduced roundness
              ),
            child: SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemCount: _brands.length,
                itemBuilder: (context, index) {
                  final brand = _brands[index];
                  final isSelected = brand['isSelected'];
                  
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          // Reset all brands
                          for (var b in _brands) {
                            b['isSelected'] = false;
                          }
                          // Select current brand
                          _brands[index]['isSelected'] = true;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.black : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Brand Icon
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : Colors.transparent,
                                shape: BoxShape.circle,
                                border: isSelected ? null : Border.all(color: Colors.black, width: 1),
                              ),
                              child: Center(
                                child: Icon(
                                  brand['icon'],
                                  color: isSelected ? Colors.black : Colors.black,
                                  size: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Brand Name
                            Text(
                              brand['name'],
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.black,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          
          const SizedBox(height: 4),
          
          // Main content area with white rounded container
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(20),
                  bottom: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  
                  // Category Filters
                  SizedBox(
                    height: 36,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final isSelected = index == _selectedCategoryIndex;
                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedCategoryIndex = index;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.black : const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Center(
                                child: Text(
                                  _categories[index],
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.black,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Crypto Cards List
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: _products.length,
                          itemBuilder: (context, index) {
                            final product = _products[index];
                            return GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => ScrapItemDetailsPage(item: product),
                                  ),
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                              children: [
                                // Crypto Details
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product['name'],
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        product['price'],
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        product['change'],
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: product['changeColor'],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Small Chart
                                Expanded(
                                  flex: 3,
                                  child: Container(
                                    height: 60,
                                    padding: const EdgeInsets.all(8),
                                    child: Stack(
                                      children: [
                                        // Chart
                                        Positioned.fill(
                                          child: _buildMiniChart(product['chartData'], product['changeColor']),
                                        ),
                                        // Favorite Button
                                        Positioned(
                                          top: 0,
                                          right: 0,
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _products[index]['isFavorite'] = !_products[index]['isFavorite'];
                                              });
                                            },
                                            child: Container(
                                              width: 24,
                                              height: 24,
                                              decoration: const BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                product['isFavorite'] ? Icons.favorite : Icons.favorite_border,
                                                color: product['isFavorite'] ? Colors.red : Colors.black,
                                                size: 14,
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
                              ),
                            );
                          },
                        ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: widget.showNavbar
          ? BottomNavbar(
              selectedIndex: _selectedIndex,
              onItemTapped: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
            )
          : null,
    );
  }

  Widget _buildMiniChart(List<double> data, Color color) {
    if (data.isEmpty) return const SizedBox();
    
    final minValue = data.reduce((a, b) => a < b ? a : b);
    final maxValue = data.reduce((a, b) => a > b ? a : b);
    final range = maxValue - minValue;
    
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: data.asMap().entries.map((e) {
              return FlSpot(e.key.toDouble(), e.value);
            }).toList(),
            isCurved: true,
            color: color,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withOpacity(0.1),
            ),
          ),
        ],
        minX: 0,
        maxX: (data.length - 1).toDouble(),
        minY: minValue - (range * 0.1),
        maxY: maxValue + (range * 0.1),
        lineTouchData: const LineTouchData(enabled: false),
      ),
    );
  }
}
