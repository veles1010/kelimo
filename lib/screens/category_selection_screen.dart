import 'package:flutter/material.dart';
import 'package:kelimo/data/category_catalog.dart';
import 'package:kelimo/models/category_hub_snapshot.dart';
import 'package:kelimo/models/learning_category.dart';
import 'package:kelimo/theme/app_theme.dart';

class CategorySelectionScreen extends StatefulWidget {
  const CategorySelectionScreen({required this.snapshot, super.key});

  final CategoryHubSnapshot snapshot;

  @override
  State<CategorySelectionScreen> createState() =>
      _CategorySelectionScreenState();
}

class _CategorySelectionScreenState extends State<CategorySelectionScreen> {
  String _query = '';

  List<LearningCategory> get _filteredCategories {
    final normalizedQuery = _query.trim().toLowerCase();
    return CategoryCatalog.categories
        .where((category) => category.isAvailable)
        .where(
          (category) =>
              normalizedQuery.isEmpty ||
              category.title.toLowerCase().contains(normalizedQuery),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final categories = _filteredCategories;
    final recentCategories = widget.snapshot.recentCategories.take(3).toList();
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Geri',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Kategori Seç',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              sliver: SliverToBoxAdapter(
                child: SearchBar(
                  hintText: 'Kategori ara',
                  leading: const Icon(Icons.search_rounded),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
            ),
            if (_query.isEmpty && recentCategories.isNotEmpty) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Son Çalışılanlar',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                sliver: SliverToBoxAdapter(
                  child: SizedBox(
                    height: 86,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final cardWidth = switch (recentCategories.length) {
                          1 => constraints.maxWidth,
                          2 => (constraints.maxWidth - 10) / 2,
                          _ => 190.0,
                        };
                        return ListView.separated(
                          padding: EdgeInsets.zero,
                          scrollDirection: Axis.horizontal,
                          itemCount: recentCategories.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final category = recentCategories[index];
                            return _RecentCategoryCard(
                              width: cardWidth,
                              category: category,
                              onTap: () => Navigator.of(context).pop(category),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
            if (categories.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptySearchResult(),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    _query.isEmpty ? 'Tüm Kategoriler' : 'Arama Sonuçları',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisExtent: 150,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final progress = widget.snapshot.progressFor(category.id);
                    final learned = progress?.learnedWordCount ?? 0;
                    final total =
                        progress?.totalWordCount ?? category.words.length;
                    return _CompactCategoryCard(
                      category: category,
                      learnedCount: learned,
                      totalCount: total,
                      onTap: () => Navigator.of(context).pop(category),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecentCategoryCard extends StatelessWidget {
  const _RecentCategoryCard({
    required this.width,
    required this.category,
    required this.onTap,
  });

  final double width;
  final LearningCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        key: ValueKey('recent-category-${category.id}'),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  height: 30,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      category.emoji,
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    category.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactCategoryCard extends StatelessWidget {
  const _CompactCategoryCard({
    required this.category,
    required this.learnedCount,
    required this.totalCount,
    required this.onTap,
  });

  final LearningCategory category;
  final int learnedCount;
  final int totalCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final progress = totalCount == 0 ? 0.0 : learnedCount / totalCount;
    final percentage = (progress * 100).round();

    return Card(
      key: ValueKey('category-grid-${category.id}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        category.emoji,
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '%$percentage',
                    style: textTheme.labelMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Text(
                  category.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
              ),
              Text('$totalCount kelime', style: textTheme.bodySmall),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress, minHeight: 5),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySearchResult extends StatelessWidget {
  const _EmptySearchResult();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppDimensions.cardPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Aramana uygun kategori bulunamadı.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
