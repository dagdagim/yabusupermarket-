// models/user_model.dart
class UserModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? phone;
  final ShopModel? shop;
  final bool isActive;
  final DateTime? lastLogin;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.shop,
    required this.isActive,
    this.lastLogin,
  });

  bool get isAdmin => role == 'admin';
  bool get isShopkeeper => role == 'shopkeeper';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'shopkeeper',
      phone: json['phone'],
      shop: json['shop'] is Map ? ShopModel.fromJson(Map<String, dynamic>.from(json['shop'])) : null,
      isActive: json['isActive'] ?? true,
      lastLogin: json['lastLogin'] != null ? DateTime.parse(json['lastLogin']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'name': name,
        'email': email,
        'role': role,
        'phone': phone,
        'shop': shop?.toJson(),
        'isActive': isActive,
      };
}

class ShopModel {
  final String id;
  final String name;
  final String location;
  final String? phone;
  final bool isActive;

  ShopModel({
    required this.id,
    required this.name,
    required this.location,
    this.phone,
    required this.isActive,
  });

  factory ShopModel.fromJson(Map<String, dynamic> json) {
    return ShopModel(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      location: json['location'] ?? '',
      phone: json['phone'],
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'name': name,
        'location': location,
        'phone': phone,
        'isActive': isActive,
      };
}

class ProductModel {
  final String id;
  final String name;
  final String sku;
  final String? barcode;
  final String category;
  final String? brand;
  final String vehicleType;
  final String? description;
  final double purchasePrice;
  final double sellingPrice;
  final int quantity;
  final int lowStockThreshold;
  final ShopModel? shop;
  final String? qrCode;
  final String? qrCodeData;
  final String? image;
  final bool isActive;
  final DateTime createdAt;

  ProductModel({
    required this.id,
    required this.name,
    required this.sku,
    this.barcode,
    required this.category,
    this.brand,
    required this.vehicleType,
    this.description,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.quantity,
    required this.lowStockThreshold,
    this.shop,
    this.qrCode,
    this.qrCodeData,
    this.image,
    required this.isActive,
    required this.createdAt,
  });

  bool get isLowStock => quantity <= lowStockThreshold;
  double get profitMargin =>
      purchasePrice > 0 ? ((sellingPrice - purchasePrice) / purchasePrice) * 100 : 0;

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      sku: json['sku'] ?? '',
      barcode: json['barcode'] ?? json['qrCodeData'],
      category: json['category'] ?? '',
      brand: json['brand'],
      vehicleType: json['vehicleType'] ?? '',
      description: json['description'],
      purchasePrice: (json['purchasePrice'] ?? 0).toDouble(),
      sellingPrice: (json['sellingPrice'] ?? 0).toDouble(),
      quantity: json['quantity'] ?? 0,
      lowStockThreshold: json['lowStockThreshold'] ?? 5,
      shop: json['shop'] is Map ? ShopModel.fromJson(Map<String, dynamic>.from(json['shop'])) : null,
      qrCode: json['qrCode'],
      qrCodeData: json['qrCodeData'],
      image: json['image'],
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }
}

class SaleItemModel {
  final String productId;
  final String productName;
  final String? productSku;
  int quantitySold;
  final double unitPrice;
  final double totalPrice;

  SaleItemModel({
    required this.productId,
    required this.productName,
    this.productSku,
    required this.quantitySold,
    required this.unitPrice,
    required this.totalPrice,
  });

  double get computedTotal => unitPrice * quantitySold;

  factory SaleItemModel.fromProduct(ProductModel product, int qty) {
    return SaleItemModel(
      productId: product.id,
      productName: product.name,
      productSku: product.sku,
      quantitySold: qty,
      unitPrice: product.sellingPrice,
      totalPrice: product.sellingPrice * qty,
    );
  }

  factory SaleItemModel.fromJson(Map<String, dynamic> json) {
    return SaleItemModel(
      productId: json['product'] is Map ? (json['product']['_id'] ?? '') : (json['product'] ?? ''),
      productName: json['productName'] ?? '',
      productSku: json['productSku'],
      quantitySold: json['quantitySold'] ?? 0,
      unitPrice: (json['unitPrice'] ?? 0).toDouble(),
      totalPrice: (json['totalPrice'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'quantity': quantitySold,
      };
}

class SaleModel {
  final String id;
  final String saleNumber;
  final List<SaleItemModel> items;
  final double totalAmount;
  final double totalProfit;
  final ShopModel? shop;
  final String shopName;
  final String shopkeeperName;
  final String status;
  final String paymentMethod;
  final String? transferReceiptImage;
  final DateTime createdAt;

  SaleModel({
    required this.id,
    required this.saleNumber,
    required this.items,
    required this.totalAmount,
    required this.totalProfit,
    this.shop,
    required this.shopName,
    required this.shopkeeperName,
    required this.status,
    required this.paymentMethod,
    this.transferReceiptImage,
    required this.createdAt,
  });

  factory SaleModel.fromJson(Map<String, dynamic> json) {
    return SaleModel(
      id: json['_id'] ?? json['id'] ?? '',
      saleNumber: json['saleNumber'] ?? '',
      items: (json['items'] as List<dynamic>? ?? [])
          .map((i) => SaleItemModel.fromJson(i))
          .toList(),
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      totalProfit: (json['totalProfit'] ?? 0).toDouble(),
      shop: json['shop'] is Map ? ShopModel.fromJson(Map<String, dynamic>.from(json['shop'])) : null,
      shopName: json['shopName'] ?? '',
      shopkeeperName: json['shopkeeperName'] ?? '',
      status: json['status'] ?? 'completed',
      paymentMethod: json['paymentMethod'] ?? 'cash',
      transferReceiptImage: json['transferReceiptImage'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }
}

class ShipmentModel {
  final String id;
  final ProductModel? product;
  final String productName;
  final int quantity;
  final ShopModel? shop;
  final String shopName;
  final String status;
  final DateTime shippedAt;
  final DateTime? arrivedAt;
  final String? notes;

  ShipmentModel({
    required this.id,
    this.product,
    required this.productName,
    required this.quantity,
    this.shop,
    required this.shopName,
    required this.status,
    required this.shippedAt,
    this.arrivedAt,
    this.notes,
  });

  bool get isPending => status == 'pending';

  factory ShipmentModel.fromJson(Map<String, dynamic> json) {
    return ShipmentModel(
      id: json['_id'] ?? json['id'] ?? '',
      product: json['product'] is Map
          ? ProductModel.fromJson(Map<String, dynamic>.from(json['product']))
          : null,
      productName: json['productName'] ?? '',
      quantity: json['quantity'] ?? 0,
      shop: json['shop'] is Map
          ? ShopModel.fromJson(Map<String, dynamic>.from(json['shop']))
          : null,
      shopName: json['shopName'] ?? '',
      status: json['status'] ?? 'pending',
      shippedAt: json['shippedAt'] != null
          ? DateTime.parse(json['shippedAt'])
          : DateTime.now(),
      arrivedAt:
          json['arrivedAt'] != null ? DateTime.parse(json['arrivedAt']) : null,
      notes: json['notes'],
    );
  }
}

class ReconciliationModel {
  final String id;
  final ShopModel? shop;
  final String shopName;
  final DateTime date;
  final double totalSales;
  final int totalTransactions;
  final double expectedCash;
  final double cashReceived;
  final double difference;
  final String status;
  final String? notes;

  ReconciliationModel({
    required this.id,
    this.shop,
    required this.shopName,
    required this.date,
    required this.totalSales,
    required this.totalTransactions,
    required this.expectedCash,
    required this.cashReceived,
    required this.difference,
    required this.status,
    this.notes,
  });

  factory ReconciliationModel.fromJson(Map<String, dynamic> json) {
    return ReconciliationModel(
      id: json['_id'] ?? json['id'] ?? '',
      shop: json['shop'] is Map ? ShopModel.fromJson(Map<String, dynamic>.from(json['shop'])) : null,
      shopName: json['shopName'] ?? '',
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      totalSales: (json['totalSales'] ?? 0).toDouble(),
      totalTransactions: json['totalTransactions'] ?? 0,
      expectedCash: (json['expectedCash'] ?? 0).toDouble(),
      cashReceived: (json['cashReceived'] ?? 0).toDouble(),
      difference: (json['difference'] ?? 0).toDouble(),
      status: json['status'] ?? 'pending',
      notes: json['notes'],
    );
  }
}

class DashboardSummary {
  final double totalRevenue;
  final double totalProfit;
  final int totalTransactions;
  final int totalItemsSold;
  final List<ShopSummary> shopBreakdown;

  DashboardSummary({
    required this.totalRevenue,
    required this.totalProfit,
    required this.totalTransactions,
    required this.totalItemsSold,
    required this.shopBreakdown,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      totalRevenue: (json['overall']?['totalRevenue'] ?? 0).toDouble(),
      totalProfit: (json['overall']?['totalProfit'] ?? 0).toDouble(),
      totalTransactions: json['overall']?['totalTransactions'] ?? 0,
      totalItemsSold: json['overall']?['totalItemsSold'] ?? 0,
      shopBreakdown: (json['summary'] as List<dynamic>? ?? [])
          .map((s) => ShopSummary.fromJson(s))
          .toList(),
    );
  }
}

class ShopSummary {
  final String shopId;
  final String shopName;
  final double totalRevenue;
  final double totalProfit;
  final int totalTransactions;

  ShopSummary({
    required this.shopId,
    required this.shopName,
    required this.totalRevenue,
    required this.totalProfit,
    required this.totalTransactions,
  });

  factory ShopSummary.fromJson(Map<String, dynamic> json) {
    return ShopSummary(
      shopId: json['_id'] ?? '',
      shopName: json['shopName'] ?? '',
      totalRevenue: (json['totalRevenue'] ?? 0).toDouble(),
      totalProfit: (json['totalProfit'] ?? 0).toDouble(),
      totalTransactions: json['totalTransactions'] ?? 0,
    );
  }
}
