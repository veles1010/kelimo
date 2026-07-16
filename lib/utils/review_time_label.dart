String reviewTimeLabel(DateTime nextReviewAt, {DateTime? now}) {
  final localReview = nextReviewAt.toLocal();
  final localNow = (now ?? DateTime.now()).toLocal();
  if (!localReview.isAfter(localNow)) return 'Şimdi';

  final today = DateTime(localNow.year, localNow.month, localNow.day);
  final reviewDay = DateTime(
    localReview.year,
    localReview.month,
    localReview.day,
  );
  final dayDifference = reviewDay.difference(today).inDays;
  if (dayDifference == 0) return 'Bugün';
  if (dayDifference == 1) return 'Yarın';
  return '$dayDifference gün sonra';
}
