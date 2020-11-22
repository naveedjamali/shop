import 'package:flutter/material.dart';
import 'package:shop/models/http_exception.dart';
import 'dart:convert';
import 'product.dart';
import 'package:http/http.dart' as http;

class Products with ChangeNotifier {
  final String authToken;
  final String userId;
  Products(this.authToken, this._items, this.userId);
  List<Product> _items = [];

  List<Product> get items {
    return [
      ..._items
    ]; //return copy instead of returning returning reference of the object (List in this case)
  }

  List<Product> get favoriteItems {
    return _items.where((element) => element.isFavorite).toList();
  }

  Product findById(String id) {
    return _items.firstWhere((prod) => prod.id == id);
  }

  Future<void> fetchAndSetProducts([bool filterByUser = false]) async {
    String filterString = filterByUser ? 'orderBy="creatorId"&equalTo="$userId"' : '';
    var url =
        'https://flutter-update-ffad4.firebaseio.com/products.json?auth=$authToken&$filterString';
    try {
      final response = await http.get(url);

      final extractedData = json.decode(response.body) as Map<String, dynamic>;
      final List<Product> loadedItems = [];
      if (extractedData == null) {
        return;
      }

      url =
          "https://flutter-update-ffad4.firebaseio.com/userFavorites/$userId.json?auth=$authToken";

      final favoriteResponse = await http.get(url);
      final favoriteData = json.decode(favoriteResponse.body);

      extractedData.forEach((prodId, prodData) {
        loadedItems.add(Product(
          id: prodId,
          description: prodData['description'],
          imageUrl: prodData['imageUrl'],
          price: prodData['price'],
          title: prodData['title'],
          isFavorite:
              favoriteData == null ? false : favoriteData[prodId] ?? false,
        ));

        _items = loadedItems;
        notifyListeners();
      });
    } catch (error) {
      print(error);
    } finally {}
  }

  Future<void> addProduct(Product product) async {
    final url =
        "https://flutter-update-ffad4.firebaseio.com/products.json?auth=$authToken";
    try {
      final response = await http.post(url,
          body: json.encode({
            'title': product.title,
            'description': product.description,
            'imageUrl': product.imageUrl,
            'price': product.price,
            'creatorId': userId,
          }));
      print(json.decode(response.body));
      final newProduct = Product(
          id: json.decode(response.body)['name'],
          description: product.description,
          imageUrl: product.imageUrl,
          price: product.price,
          title: product.title,
          isFavorite: false);
      _items.add(newProduct);
      notifyListeners();
    } catch (error) {
      print(error);
      throw error;
    }
  }

  Future<void> updateProduct(String id, Product newProduct) async {
    final prodIndex = _items.indexWhere((prod) => prod.id == id);
    if (prodIndex >= 0) {
      final url =
          "https://flutter-update-ffad4.firebaseio.com/products/$id.json?auth=$authToken";
      http.patch(url,
          body: json.encode({
            'description': newProduct.description,
            'title': newProduct.title,
            'price': newProduct.price,
            'isFavorite': newProduct.isFavorite,
            'imageUrl': newProduct.imageUrl,
          }));
      _items[prodIndex] = newProduct;
      notifyListeners();
    }
  }

  Future<void> deleteProduct(String id) async {
    final url =
        "https://flutter-update-ffad4.firebaseio.com/products/$id.json?auth=$authToken";

    final existingProductIndex = _items.indexWhere((prod) {
      return prod.id == id;
    });
    var existingProduct = _items[existingProductIndex];
    _items.removeAt(existingProductIndex);
    notifyListeners();

    final response = await http.delete(url);
    if (response.statusCode >= 400) {
      _items.insert(existingProductIndex, existingProduct);
      notifyListeners();
      throw HttpException('Could not delete the product.');
    }

    existingProduct = null;
  }
}
