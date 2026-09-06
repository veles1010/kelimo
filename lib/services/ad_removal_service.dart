import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:kelimo/repositories/ad_removal_repository.dart';

const removeAdsProductId = 'com.veles.kelimo.remove_ads';

enum StorePurchaseStatus { pending, purchased, restored, canceled, error }

class StoreProduct {
  const StoreProduct({
    required this.id,
    required this.price,
    required this.rawProduct,
  });
  final String id;
  final String price;
  final Object rawProduct;
}

class StorePurchase {
  const StorePurchase({
    required this.productId,
    required this.status,
    required this.pendingCompletePurchase,
    required this.rawPurchase,
    this.purchaseId,
    this.errorMessage,
  });
  final String productId;
  final StorePurchaseStatus status;
  final bool pendingCompletePurchase;
  final Object rawPurchase;
  final String? purchaseId;
  final String? errorMessage;
}

abstract interface class StorePurchaseGateway {
  Stream<List<StorePurchase>> get purchaseStream;
  Future<bool> isAvailable();
  Future<List<StoreProduct>> queryProducts(Set<String> ids);
  Future<bool> buyNonConsumable(StoreProduct product);
  Future<void> restorePurchases();
  Future<void> completePurchase(StorePurchase purchase);
}

abstract interface class PurchaseVerifier {
  Future<bool> verify(StorePurchase purchase);
}

/// Until a server verifier is added, only the platform store's successful
/// purchased/restored event can grant the locally cached entitlement.
class ClientStorePurchaseVerifier implements PurchaseVerifier {
  const ClientStorePurchaseVerifier();

  @override
  Future<bool> verify(StorePurchase purchase) async =>
      purchase.status == StorePurchaseStatus.purchased ||
      purchase.status == StorePurchaseStatus.restored;
}

class AdRemovalService extends ChangeNotifier {
  AdRemovalService({
    required this.repository,
    required this.gateway,
    this.verifier = const ClientStorePurchaseVerifier(),
  });

  final AdRemovalStore repository;
  final StorePurchaseGateway gateway;
  final PurchaseVerifier verifier;
  StreamSubscription<List<StorePurchase>>? _subscription;
  final Set<String> _handledPurchaseIds = <String>{};
  bool _isAdsRemoved = false;
  bool _isStoreAvailable = false;
  bool _isLoadingProducts = false;
  bool _isPurchasePending = false;
  bool _disposed = false;
  StoreProduct? _product;
  String? _message;

  bool get isAdsRemoved => _isAdsRemoved;
  bool get isStoreAvailable => _isStoreAvailable;
  bool get isLoadingProducts => _isLoadingProducts;
  bool get isPurchasePending => _isPurchasePending;
  bool get canPurchase =>
      !_isAdsRemoved &&
      !_isPurchasePending &&
      _isStoreAvailable &&
      _product != null;
  StoreProduct? get product => _product;
  String? get price => _product?.price;
  String? get message => _message;

  Future<void> initialize() async {
    try {
      _isAdsRemoved = await repository.loadAdsRemoved();
    } catch (error, stackTrace) {
      // A local entitlement read must never stop the rest of the app.
      debugPrint('Reklamsız kullanım hakkı yüklenemedi: $error\n$stackTrace');
      _isAdsRemoved = false;
    }
    _subscription ??= gateway.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Satın alma akışı okunamadı: $error\n$stackTrace');
        _message = 'Satın alma durumu alınamadı. Daha sonra tekrar dene.';
        _isPurchasePending = false;
        _notify();
      },
    );
    await refreshProducts();
    _notify();
  }

  Future<void> refreshProducts() async {
    if (_disposed || _isLoadingProducts) return;
    _isLoadingProducts = true;
    _message = null;
    _notify();
    try {
      _isStoreAvailable = await gateway.isAvailable();
      if (!_isStoreAvailable) {
        _product = null;
        _message = 'Mağaza şu anda kullanılamıyor.';
        return;
      }
      final products = await gateway.queryProducts({removeAdsProductId});
      for (final item in products) {
        if (item.id == removeAdsProductId) {
          _product = item;
          break;
        }
      }
      if (_product == null) {
        _message = 'Reklamları kaldırma ürünü henüz mağazada kullanılamıyor.';
      }
    } catch (error, stackTrace) {
      debugPrint('Satın alma ürünleri yüklenemedi: $error\n$stackTrace');
      _product = null;
      _message = 'Mağaza ürünleri yüklenemedi. Daha sonra tekrar dene.';
    } finally {
      _isLoadingProducts = false;
      _notify();
    }
  }

  Future<bool> purchase() async {
    final product = _product;
    if (!canPurchase || product == null) return false;
    _isPurchasePending = true;
    _message = null;
    _notify();
    try {
      final started = await gateway.buyNonConsumable(product);
      if (!started) {
        _isPurchasePending = false;
        _message = 'Satın alma başlatılamadı. Daha sonra tekrar dene.';
        _notify();
      }
      return started;
    } catch (error, stackTrace) {
      debugPrint('Satın alma başlatılamadı: $error\n$stackTrace');
      _isPurchasePending = false;
      _message = 'Satın alma başlatılamadı. Daha sonra tekrar dene.';
      _notify();
      return false;
    }
  }

  Future<void> restorePurchases() async {
    if (_disposed || _isPurchasePending) return;
    _isPurchasePending = true;
    _message = null;
    _notify();
    try {
      await gateway.restorePurchases();
      // A store with nothing to restore may emit no event at all.
      _isPurchasePending = false;
      _notify();
    } catch (error, stackTrace) {
      debugPrint('Satın alımlar geri yüklenemedi: $error\n$stackTrace');
      _isPurchasePending = false;
      _message = 'Satın alımlar geri yüklenemedi. Daha sonra tekrar dene.';
      _notify();
    }
  }

  Future<void> _handlePurchaseUpdates(List<StorePurchase> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productId != removeAdsProductId) continue;
      final uniqueId =
          '${purchase.purchaseId ?? purchase.productId}:${purchase.status.name}';
      if (!_handledPurchaseIds.add(uniqueId)) continue;
      try {
        if (purchase.status == StorePurchaseStatus.pending) {
          _isPurchasePending = true;
        } else if (purchase.status == StorePurchaseStatus.purchased ||
            purchase.status == StorePurchaseStatus.restored) {
          if (await verifier.verify(purchase)) await _grantEntitlement();
        } else if (purchase.status == StorePurchaseStatus.error) {
          _message = purchase.errorMessage ?? 'Satın alma tamamlanamadı.';
        } else if (purchase.status == StorePurchaseStatus.canceled) {
          _message = null;
        }
      } catch (error, stackTrace) {
        debugPrint('Satın alma güncellemesi işlenemedi: $error\n$stackTrace');
        _message = 'Satın alma doğrulanamadı. Daha sonra tekrar dene.';
      } finally {
        if (purchase.pendingCompletePurchase) {
          try {
            await gateway.completePurchase(purchase);
          } catch (error, stackTrace) {
            debugPrint('Satın alma tamamlanamadı: $error\n$stackTrace');
          }
        }
        if (purchase.status != StorePurchaseStatus.pending) {
          _isPurchasePending = false;
        }
        _notify();
      }
    }
  }

  Future<void> _grantEntitlement() async {
    if (_isAdsRemoved) return;
    await repository.saveAdsRemoved(true);
    _isAdsRemoved = true;
    _message = null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel() ?? Future<void>.value());
    super.dispose();
  }
}

class GoogleStorePurchaseGateway implements StorePurchaseGateway {
  GoogleStorePurchaseGateway({InAppPurchase? store})
    : _store = store ?? InAppPurchase.instance;
  final InAppPurchase _store;

  @override
  Stream<List<StorePurchase>> get purchaseStream => _store.purchaseStream.map(
    (purchases) => purchases.map(_toStorePurchase).toList(growable: false),
  );
  @override
  Future<bool> isAvailable() => _store.isAvailable();
  @override
  Future<List<StoreProduct>> queryProducts(Set<String> ids) async {
    final response = await _store.queryProductDetails(ids);
    if (response.error != null) throw StateError(response.error!.message);
    return response.productDetails
        .map(
          (product) => StoreProduct(
            id: product.id,
            price: product.price,
            rawProduct: product,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<bool> buyNonConsumable(StoreProduct product) =>
      _store.buyNonConsumable(
        purchaseParam: PurchaseParam(
          productDetails: product.rawProduct as ProductDetails,
        ),
      );
  @override
  Future<void> restorePurchases() => _store.restorePurchases();
  @override
  Future<void> completePurchase(StorePurchase purchase) =>
      _store.completePurchase(purchase.rawPurchase as PurchaseDetails);

  static StorePurchase _toStorePurchase(PurchaseDetails purchase) =>
      StorePurchase(
        productId: purchase.productID,
        status: switch (purchase.status) {
          PurchaseStatus.pending => StorePurchaseStatus.pending,
          PurchaseStatus.purchased => StorePurchaseStatus.purchased,
          PurchaseStatus.restored => StorePurchaseStatus.restored,
          PurchaseStatus.canceled => StorePurchaseStatus.canceled,
          PurchaseStatus.error => StorePurchaseStatus.error,
        },
        pendingCompletePurchase: purchase.pendingCompletePurchase,
        rawPurchase: purchase,
        purchaseId: purchase.purchaseID,
        errorMessage: purchase.error?.message,
      );
}
