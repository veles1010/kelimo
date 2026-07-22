import 'package:flutter/material.dart';
import 'package:kelimo/data/category_catalog.dart';
import 'package:kelimo/models/category_hub_snapshot.dart';
import 'package:kelimo/models/learning_category.dart';
import 'package:kelimo/theme/app_theme.dart';
import 'package:kelimo/widgets/glass_surface.dart';

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
    final recentCategories = widget.snapshot.recentCategories.take(2).toList();
    final textTheme = Theme.of(context).textTheme;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final gridExtent =
        150.0 + ((textScale - 1).clamp(0.0, 1.0).toDouble() * 36);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackground(
        child: SafeArea(
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 10, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: GlassSurface(
                    key: const ValueKey('category-glass-header'),
                    borderRadius: BorderRadius.circular(22),
                    blurSigma: 12,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 58),
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
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                sliver: SliverToBoxAdapter(
                  child: GlassSurface(
                    key: const ValueKey('category-glass-search'),
                    borderRadius: BorderRadius.circular(24),
                    blurSigma: 12,
                    padding: EdgeInsets.zero,
                    child: SearchBar(
                      backgroundColor: const WidgetStatePropertyAll(
                        Colors.transparent,
                      ),
                      elevation: const WidgetStatePropertyAll(0),
                      hintText: 'Kategori ara',
                      leading: const Icon(Icons.search_rounded),
                      onChanged: (value) => setState(() => _query = value),
                    ),
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
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        const spacing = 12.0;
                        final cardWidth = (constraints.maxWidth - spacing) / 2;
                        final cardHeight =
                            86.0 +
                            ((textScale - 1).clamp(0.0, 1.0).toDouble() * 6);
                        return Wrap(
                          key: const ValueKey('recent-categories-layout'),
                          spacing: spacing,
                          runSpacing: spacing,
                          children: [
                            for (final category in recentCategories)
                              SizedBox(
                                width: cardWidth,
                                height: cardHeight,
                                child: _RecentCategoryCard(
                                  category: category,
                                  onTap: () =>
                                      Navigator.of(context).pop(category),
                                ),
                              ),
                          ],
                        );
                      },
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
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisExtent: gridExtent,
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
      ),
    );
  }
}

class _RecentCategoryCard extends StatelessWidget {
  const _RecentCategoryCard({required this.category, required this.onTap});

  final LearningCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      enableBlur: false,
      showShadow: false,
      padding: EdgeInsets.zero,
      child: Card(
        key: ValueKey('recent-category-${category.id}'),
        color: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
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
                      height: 1.15,
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

    return GlassSurface(
      enableBlur: false,
      showShadow: false,
      padding: EdgeInsets.zero,
      child: Card(
        key: ValueKey('category-grid-${category.id}'),
        color: Colors.transparent,
        surfaceTintColor: Colors.transparent,
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
