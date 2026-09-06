import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kelimo/repositories/ad_removal_repository.dart';
import 'package:kelimo/services/ad_removal_service.dart';

class _MemoryEntitlementStore implements AdRemovalStore {
  _MemoryEntitlementStore();
  bool value = false;
  int writes = 0;
  @override
  Future<bool> loadAdsRemoved() async => value;
  @override
  Future<void> saveAdsRemoved(bool value) async {
    this.value = value;
    writes++;
  }
}

class _FakeStoreGateway implements StorePurchaseGateway {
  final controller = StreamController<List<StorePurchase>>.broadcast();
  bool available = true;
  List<StoreProduct> products = const [];
  bool buyResult = true;
  int buyCalls = 0;
  int restoreCalls = 0;
  int completeCalls = 0;
  @override
  Stream<List<StorePurchase>> get purchaseStream => controller.stream;
  @override
  Future<bool> isAvailable() async => available;
  @override
  Future<List<StoreProduct>> queryProducts(Set<String> ids) async => products;
  @override
  Future<bool> buyNonConsumable(StoreProduct product) async {
    buyCalls++;
    return buyResult;
  }

  @override
  Future<void> completePurchase(StorePurchase purchase) async =>
      completeCalls++;
  @override
  Future<void> restorePurchases() async => restoreCalls++;
  Future<void> close() => controller.close();
}

StoreProduct get _product => const StoreProduct(
  id: removeAdsProductId,
  price: '₺49,99',
  rawProduct: 'product',
);

StorePurchase _purchase(
  StorePurchaseStatus status, {
  String? id,
  bool complete = false,
}) => StorePurchase(
  productId: removeAdsProductId,
  status: status,
  pendingCompletePurchase: complete,
  rawPurchase: 'purchase',
  purchaseId: id,
);

void main() {
  group('AdRemovalService', () {
    late _MemoryEntitlementStore store;
    late _FakeStoreGateway gateway;
    late AdRemovalService service;

    setUp(() async {
      store = _MemoryEntitlementStore();
      gateway = _FakeStoreGateway()..products = [_product];
      service = AdRemovalService(repository: store, gateway: gateway);
      await service.initialize();
    });

    tearDown(() async {
      service.dispose();
      await gateway.close();
    });

    test(
      'ürün sorgusu mağaza kullanılamadığında güvenli durum verir',
      () async {
        gateway.available = false;
        await service.refreshProducts();
        expect(service.canPurchase, isFalse);
        expect(service.message, contains('Mağaza'));
      },
    );

    test('satın alma ve restore reklamsız hakkı etkinleştirir', () async {
      gateway.controller.add([
        _purchase(StorePurchaseStatus.purchased, id: 'one', complete: true),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(service.isAdsRemoved, isTrue);
      expect(store.value, isTrue);
      expect(gateway.completeCalls, 1);

      final restoreStore = _MemoryEntitlementStore();
      final restoreGateway = _FakeStoreGateway()..products = [_product];
      final restored = AdRemovalService(
        repository: restoreStore,
        gateway: restoreGateway,
      );
      await restored.initialize();
      restoreGateway.controller.add([
        _purchase(StorePurchaseStatus.restored, id: 'restore'),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(restored.isAdsRemoved, isTrue);
      restored.dispose();
      await restoreGateway.close();
    });

    test(
      'pending, iptal ve hata hak vermez; ikinci satın alma başlamaz',
      () async {
        gateway.controller.add([
          _purchase(StorePurchaseStatus.pending, id: 'pending'),
        ]);
        await Future<void>.delayed(Duration.zero);
        expect(service.isPurchasePending, isTrue);
        expect(await service.purchase(), isFalse);
        expect(gateway.buyCalls, 0);
        gateway.controller.add([
          _purchase(StorePurchaseStatus.canceled, id: 'cancel'),
        ]);
        await Future<void>.delayed(Duration.zero);
        gateway.controller.add([
          _purchase(StorePurchaseStatus.error, id: 'error'),
        ]);
        await Future<void>.delayed(Duration.zero);
        expect(service.isAdsRemoved, isFalse);
      },
    );

    test('aynı satın alma olayı yalnız bir kez işlenir', () async {
      final event = _purchase(StorePurchaseStatus.purchased, id: 'duplicate');
      gateway.controller.add([event]);
      gateway.controller.add([event]);
      await Future<void>.delayed(const Duration(milliseconds: 1));
      expect(store.writes, 1);
    });
  });
}
