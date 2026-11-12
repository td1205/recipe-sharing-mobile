/// Server-side listing filters for `GET /api/recipes?page=&limit=` —
/// mirrors the `listingQuery` validation parameters of the backend.
class RecipeFilter {
  const RecipeFilter({
    this.search = '',
    this.categoryId,
    this.mealTimeId,
    this.duration,
    this.minRating,
    this.tag,
    this.sort = RecipeSort.newest,
  });

  final String search;
  final int? categoryId;
  final int? mealTimeId;
  final RecipeDuration? duration;
  final int? minRating;
  final String? tag;
  final RecipeSort sort;

  bool get isDefault {
    final tagValue = tag;
    return search.isEmpty &&
        categoryId == null &&
        mealTimeId == null &&
        duration == null &&
        minRating == null &&
        (tagValue == null || tagValue.isEmpty) &&
        sort == RecipeSort.newest;
  }

  int get activeFilterCount {
    var count = 0;
    if (search.isNotEmpty) count++;
    if (categoryId != null) count++;
    if (mealTimeId != null) count++;
    if (duration != null) count++;
    if (minRating != null) count++;
    final tagValue = tag;
    if (tagValue != null && tagValue.isNotEmpty) count++;
    return count;
  }

  RecipeFilter copyWith({
    String? search,
    bool clearSearch = false,
    int? categoryId,
    bool clearCategory = false,
    int? mealTimeId,
    bool clearMealTime = false,
    RecipeDuration? duration,
    bool clearDuration = false,
    int? minRating,
    bool clearMinRating = false,
    String? tag,
    bool clearTag = false,
    RecipeSort? sort,
  }) => RecipeFilter(
    search: clearSearch ? '' : (search ?? this.search),
    categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
    mealTimeId: clearMealTime ? null : (mealTimeId ?? this.mealTimeId),
    duration: clearDuration ? null : (duration ?? this.duration),
    minRating: clearMinRating ? null : (minRating ?? this.minRating),
    tag: clearTag ? '' : (tag ?? this.tag ?? ''),
    sort: sort ?? this.sort,
  );

  Map<String, Object?> toQuery({required int page, required int limit}) =>
      <String, Object?>{
        'page': page,
        'limit': limit,
        'sort': sort.apiValue,
        if (search.isNotEmpty) 'search': search,
        if (categoryId != null) 'category': categoryId,
        if (mealTimeId != null) 'meal_time': mealTimeId,
        if (duration != null) 'duration': duration!.apiValue,
        if (minRating != null) 'min_rating': minRating,
        if (tag != null) 'tag': tag,
      };
}

enum RecipeSort {
  newest('newest', 'Mới nhất'),
  oldest('oldest', 'Cũ nhất'),
  popular('popular', 'Phổ biến'),
  ratingDesc('rating_desc', 'Đánh giá cao'),
  timeAsc('time_asc', 'Nhanh nhất'),
  titleAsc('title_asc', 'Tên A–Z');

  const RecipeSort(this.apiValue, this.label);
  final String apiValue;
  final String label;
}

enum RecipeDuration {
  under30('under_30', 'Dưới 30 phút'),
  from30To60('30_60', '30 – 60 phút'),
  over60('over_60', 'Trên 60 phút');

  const RecipeDuration(this.apiValue, this.label);
  final String apiValue;
  final String label;
}
