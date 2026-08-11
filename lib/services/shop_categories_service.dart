import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth/auth_helpers.dart';

class ShopCategory {
  final String id;
  final String name;
  final bool isCustom;
  final String? suggestionKey;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ShopCategory({
    required this.id,
    required this.name,
    required this.isCustom,
    this.suggestionKey,
    this.createdAt,
    this.updatedAt,
  });

  factory ShopCategory.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return ShopCategory(
      id: doc.id,
      name: (d['name'] as String?)?.trim() ?? '',
      isCustom: d['isCustom'] as bool? ?? false,
      suggestionKey: d['suggestionKey'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Suggested jewellery item categories for Indian shops.
class JewelleryCategorySuggestions {
  static const List<String> all = [
    'Rings',
    'Engagement rings',
    'Wedding bands',
    'Cocktail rings',
    'Men\'s rings',
    'Kids rings',
    'Necklaces',
    'Chains',
    'Chokers',
    'Lockets',
    'Pendants',
    'Mangalsutra',
    'Haar / Long necklace',
    'Earrings',
    'Studs',
    'Hoops',
    'Jhumkas',
    'Danglers',
    'Chandbali',
    'Bangles',
    'Kadas',
    'Bracelets',
    'Cuffs',
    'Armlets',
    'Anklets',
    'Payal',
    'Toe rings',
    'Nose pins',
    'Nose rings',
    'Maang tikka',
    'Matha patti',
    'Brooches',
    'Cufflinks',
    'Kamarbandh',
    'Waist chain',
    'Hair accessories',
    'Watches',
    'Coins',
    'Bars / Bullion',
    'Bridal sets',
    'Temple jewellery',
    'Antique jewellery',
    'Fashion jewellery',
    'Silver articles',
    'Pooja items',
    'Gift items',
    'Loose stones',
    'Diamond jewellery',
    'Gold jewellery',
    'Platinum jewellery',
    'Custom orders',
    'Repair / Polish',
    'Other',
  ];

  static String keyFor(String name) =>
      name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
}

class ShopCategoriesService {
  ShopCategoriesService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>>? _userRef() {
    final email = AuthHelpers.emailDocId(_auth.currentUser?.email);
    if (email == null) return null;
    return _firestore.collection('users').doc(email);
  }

  CollectionReference<Map<String, dynamic>>? _categories() =>
      _userRef()?.collection('categories');

  Stream<List<ShopCategory>> watchCategories() {
    final col = _categories();
    if (col == null) return Stream.value(const []);
    return col.orderBy('name').snapshots().map(
          (snap) => snap.docs.map(ShopCategory.fromDoc).toList(),
        );
  }

  Future<void> addCategory({
    required String name,
    required bool isCustom,
    String? suggestionKey,
  }) async {
    final col = _categories();
    if (col == null) throw Exception('Not signed in');

    final trimmed = name.trim();
    if (trimmed.isEmpty) throw Exception('Category name required');

    final key = suggestionKey ?? JewelleryCategorySuggestions.keyFor(trimmed);

    // Avoid duplicate by suggestionKey / normalized name.
    final existing = await col.where('suggestionKey', isEqualTo: key).limit(1).get();
    if (existing.docs.isNotEmpty) {
      throw Exception('Category already added');
    }

    await col.add({
      'name': trimmed,
      'isCustom': isCustom,
      'suggestionKey': key,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteCategory(String id) async {
    final col = _categories();
    if (col == null) throw Exception('Not signed in');
    await col.doc(id).delete();
  }
}
