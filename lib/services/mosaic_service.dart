import 'package:kelimo/data/category_catalog.dart';
import 'package:kelimo/models/mosaic_progress.dart';
import 'package:kelimo/repositories/word_progress_repository.dart';
import 'package:kelimo/services/statistics_service.dart';

class MosaicWordMap {
  MosaicWordMap._(this.cellByWordId);

  factory MosaicWordMap.fromCatalog() {
    final wordIds = CategoryCatalog.categories
        .expand((category) => category.words)
        .map((word) => word.id)
        .toList(growable: false);
    final cells = List<int>.generate(wordIds.length, (index) => index);
    var state = 0x4b454c49;
    for (var index = cells.length - 1; index > 0; index--) {
      state = (1664525 * state + 1013904223) & 0xffffffff;
      final swapIndex = state % (index + 1);
      final value = cells[index];
      cells[index] = cells[swapIndex];
      cells[swapIndex] = value;
    }
    return MosaicWordMap._({
      for (var index = 0; index < wordIds.length; index++)
        wordIds[index]: cells[index],
    });
  }

  final Map<String, int> cellByWordId;
}

class MosaicService {
  MosaicService({required this.wordProgressStore, MosaicWordMap? wordMap})
    : wordMap = wordMap ?? MosaicWordMap.fromCatalog();

  static const columns = 36;
  static const rows = 30;
  static const totalCells = columns * rows;

  final WordProgressStore wordProgressStore;
  final MosaicWordMap wordMap;

  MosaicProgress load() {
    final discovered = <int>{};
    for (final progress in wordProgressStore.getAllProgress()) {
      if (!isLearnedProgress(progress)) continue;
      final cell = wordMap.cellByWordId[progress.wordId];
      if (cell != null) discovered.add(cell);
    }
    return MosaicProgress(
      discoveredCellIndices: Set.unmodifiable(discovered),
      totalCells: totalCells,
    );
  }
}
