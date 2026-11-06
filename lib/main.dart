import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'auth_screens.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const CampusSupplyApp());
}

class CampusSupplyApp extends StatelessWidget {
  const CampusSupplyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Campus Supply Desk',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo)),
      home: const AuthGate(),
    );
  }
}

class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final CollectionReference<Map<String, dynamic>> _products =
      FirebaseFirestore.instance.collection('campus_products');
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _productStream =
      _products.snapshots();

  final _search = TextEditingController();
  final _minPrice = TextEditingController();
  final _maxPrice = TextEditingController();
  String? _filterError;

  @override
  void initState() {
    super.initState();
    _search.addListener(_onFiltersChanged);
    _minPrice.addListener(_onFiltersChanged);
    _maxPrice.addListener(_onFiltersChanged);
  }

  void _onFiltersChanged() {
    if (mounted) setState(() => _filterError = _validateBounds());
  }

  String? _validateBounds() {
    final minText = _minPrice.text.trim();
    final maxText = _maxPrice.text.trim();
    final min = minText.isEmpty ? null : double.tryParse(minText);
    final max = maxText.isEmpty ? null : double.tryParse(maxText);
    if (minText.isNotEmpty && (min == null || !min.isFinite || min < 0)) {
      return 'Minimum price must be a nonnegative number.';
    }
    if (maxText.isNotEmpty && (max == null || !max.isFinite || max < 0)) {
      return 'Maximum price must be a nonnegative number.';
    }
    if (min != null && max != null && min > max) {
      return 'Minimum price cannot exceed maximum price.';
    }
    return null;
  }

  void _reset() {
    _search.clear();
    _minPrice.clear();
    _maxPrice.clear();
    FocusScope.of(context).unfocus();
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editProduct({String? id, Map<String, dynamic>? data}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProductEditor(products: _products, id: id, initial: data),
    );
    if (result == true) _message(id == null ? 'Product created.' : 'Product updated.');
  }

  Future<void> _deleteProduct(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text('Delete "$name"?\nDocument ID: $id'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _products.doc(id).delete();
      if (!mounted) return;
      _message('Deleted "$name".');
    } on FirebaseException catch (error) {
      if (!mounted) return;
      _message('Delete failed: ${error.message ?? error.code}');
    } catch (error) {
      if (!mounted) return;
      _message('Delete failed: $error');
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _minPrice.dispose();
    _maxPrice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Campus Supply Desk')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editProduct(),
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _search,
              decoration: const InputDecoration(
                labelText: 'Search product names',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minPrice,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Minimum price',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _maxPrice,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Maximum price',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset filters'),
              ),
            ),
            if (_filterError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _filterError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _productStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Firestore error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final documents = snapshot.data!.docs;
                  if (documents.isEmpty) {
                    return const Center(child: Text('Collection is empty. Add a product.'));
                  }
                  if (_filterError != null) {
                    return const Center(child: Text('Correct the price filters above.'));
                  }
                  final query = _search.text.trim().toLowerCase();
                  final min = _minPrice.text.trim().isEmpty
                      ? null
                      : double.parse(_minPrice.text.trim());
                  final max = _maxPrice.text.trim().isEmpty
                      ? null
                      : double.parse(_maxPrice.text.trim());
                  final filtered = documents.where((doc) {
                    final data = doc.data();
                    final name = data['name'];
                    final price = data['price'];
                    if (name is! String || price is! num || !price.toDouble().isFinite) {
                      return false;
                    }
                    if (!name.trim().toLowerCase().contains(query)) return false;
                    if (min != null && price < min) return false;
                    if (max != null && price > max) return false;
                    return true;
                  }).toList();
                  if (filtered.isEmpty) {
                    return const Center(child: Text('No products found.'));
                  }
                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final doc = filtered[index];
                      final data = doc.data();
                      final name = (data['name'] as String).trim();
                      final price = (data['price'] as num).toDouble();
                      return Card(
                        child: ListTile(
                          title: Text(name),
                          subtitle: Text('\$${price.toStringAsFixed(2)}\nID: ${doc.id}'),
                          isThreeLine: true,
                          trailing: Wrap(
                            spacing: 0,
                            children: [
                              IconButton(
                                tooltip: 'Edit product',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _editProduct(id: doc.id, data: data),
                              ),
                              IconButton(
                                tooltip: 'Delete product',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _deleteProduct(doc.id, name),
                              ),
                            ],
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
      ),
    );
  }
}

class ProductEditor extends StatefulWidget {
  const ProductEditor({super.key, required this.products, this.id, this.initial});

  final CollectionReference<Map<String, dynamic>> products;
  final String? id;
  final Map<String, dynamic>? initial;

  @override
  State<ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<ProductEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _price;
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial?['name']?.toString() ?? '');
    _price = TextEditingController(
      text: widget.initial?['price']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final payload = <String, dynamic>{
        'name': _name.text.trim(),
        'price': double.parse(_price.text.trim()),
      };
      if (widget.id == null) {
        await widget.products.add(payload);
      } else {
        await widget.products.doc(widget.id).update(payload);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = 'Save failed: ${error.message ?? error.code}';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = 'Save failed: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.id == null ? 'Add Product' : 'Edit Product'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                enabled: !_saving,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (text) => text == null || text.trim().isEmpty
                    ? 'Name cannot be blank.'
                    : null,
              ),
              TextFormField(
                controller: _price,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Price'),
                validator: (text) {
                  final value = double.tryParse(text?.trim() ?? '');
                  if (value == null || !value.isFinite || value < 0) {
                    return 'Enter a nonnegative finite number.';
                  }
                  return null;
                },
              ),
              if (_saveError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _saveError!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }
}
