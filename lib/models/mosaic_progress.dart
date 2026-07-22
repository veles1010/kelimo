class MosaicProgress {
  const MosaicProgress({
    required this.discoveredCellIndices,
    required this.totalCells,
  });

  final Set<int> discoveredCellIndices;
  final int totalCells;

  int get discoveredCount => discoveredCellIndices.length;
  int get remainingCount => totalCells - discoveredCount;
  double get progress => totalCells == 0 ? 0 : discoveredCount / totalCells;
  bool get isComplete => totalCells > 0 && discoveredCount == totalCells;
}
