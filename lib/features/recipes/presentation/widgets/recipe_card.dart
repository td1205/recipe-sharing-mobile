import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/recipe.dart';
import 'app_network_image.dart';

/// Card variants used across Home, Explore, Saved and profile screens.
/// All variants show rating + total time and support an optional save
/// (favourite) toggle.
class FeaturedRecipeCard extends StatelessWidget {
  const FeaturedRecipeCard({
    super.key,
    required this.recipe,
    required this.onTap,
    this.onToggleFavourite,
    this.isFavourite = false,
    this.favouriteBusy = false,
    this.showRecommendationReason = false,
  });

  final Recipe recipe;
  final VoidCallback onTap;
  final ValueChanged<Recipe>? onToggleFavourite;
  final bool isFavourite;
  final bool favouriteBusy;
  final bool showRecommendationReason;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 264,
    child: Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppNetworkImage(
                    url: recipe.imageUrl,
                    semanticLabel: 'Ảnh món ${recipe.title}',
                  ),
                  if (onToggleFavourite != null)
                    Positioned.directional(
                      textDirection: Directionality.of(context),
                      end: 8,
                      top: 8,
                      child: _SaveButton(
                        isFavourite: isFavourite,
                        busy: favouriteBusy,
                        dense: true,
                        onTap: () => onToggleFavourite!(recipe),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: _RecipeText(
                recipe: recipe,
                maxTitleLines: 2,
                showRecommendationReason: showRecommendationReason,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class LatestRecipeCard extends StatelessWidget {
  const LatestRecipeCard({
    super.key,
    required this.recipe,
    required this.onTap,
    this.onToggleFavourite,
    this.isFavourite = false,
    this.favouriteBusy = false,
  });

  final Recipe recipe;
  final VoidCallback onTap;
  final ValueChanged<Recipe>? onToggleFavourite;
  final bool isFavourite;
  final bool favouriteBusy;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppRadii.medium),
      boxShadow: AppShadows.soft,
    ),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadii.medium),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 112),
          child: Row(
            children: [
              SizedBox(
                width: 112,
                height: 112,
                child: AppNetworkImage(
                  url: recipe.imageUrl,
                  semanticLabel: 'Ảnh món ${recipe.title}',
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.smMd),
                  child: _RecipeText(recipe: recipe, maxTitleLines: 2),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 6),
                child: onToggleFavourite == null
                    ? const Icon(Icons.chevron_right_rounded)
                    : _SaveButton(
                        isFavourite: isFavourite,
                        busy: favouriteBusy,
                        onTap: () => onToggleFavourite!(recipe),
                      ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Square grid card for Explore / Saved / profile recipe grids.
class GridRecipeCard extends StatelessWidget {
  const GridRecipeCard({
    super.key,
    required this.recipe,
    required this.onTap,
    this.onToggleFavourite,
    this.isFavourite = false,
    this.favouriteBusy = false,
    this.trailing,
  });

  final Recipe recipe;
  final VoidCallback onTap;
  final ValueChanged<Recipe>? onToggleFavourite;
  final bool isFavourite;
  final bool favouriteBusy;

  /// Custom top-right action (e.g. delete menu on "my recipes").
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1.15,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppNetworkImage(
                    url: recipe.imageUrl,
                    semanticLabel: 'Ảnh món ${recipe.title}',
                  ),
                  Positioned.directional(
                    textDirection: Directionality.of(context),
                    end: 6,
                    top: 6,
                    child:
                        trailing ??
                        (onToggleFavourite == null
                            ? const SizedBox.shrink()
                            : _SaveButton(
                                isFavourite: isFavourite,
                                busy: favouriteBusy,
                                dense: true,
                                onTap: () => onToggleFavourite!(recipe),
                              )),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: _RecipeText(recipe: recipe, maxTitleLines: 2),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.isFavourite,
    required this.busy,
    required this.onTap,
    this.dense = false,
  });

  final bool isFavourite;
  final bool busy;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final shape = CircleBorder(
      side: BorderSide(
        color: isFavourite ? AppColors.lime : const Color(0x33000000),
      ),
    );
    return Material(
      color: isFavourite
          ? AppColors.olive
          : AppColors.white.withValues(alpha: 0.92),
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: busy ? null : onTap,
        child: SizedBox.square(
          dimension: 48,
          child: Center(
            child: busy
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.olive,
                    ),
                  )
                : Icon(
                    isFavourite
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    size: dense ? 17 : 20,
                    color: isFavourite ? AppColors.lime : AppColors.olive,
                  ),
          ),
        ),
      ),
    );
  }
}

class _RecipeText extends StatelessWidget {
  const _RecipeText({
    required this.recipe,
    required this.maxTitleLines,
    this.showRecommendationReason = false,
  });
  final Recipe recipe;
  final int maxTitleLines;
  final bool showRecommendationReason;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        recipe.title,
        maxLines: maxTitleLines,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: AppSpacing.xs),
      if (showRecommendationReason &&
          recipe.recommendationReason?.trim().isNotEmpty == true) ...[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              size: 15,
              color: AppColors.oliveSoft,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                recipe.recommendationReason!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.oliveSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
      ],
      Row(
        children: [
          const Icon(
            Icons.schedule_rounded,
            size: 15,
            color: AppColors.oliveSoft,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              _metaLabel(recipe),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const Icon(Icons.star_rounded, size: 16, color: Color(0xffe2b348)),
          const SizedBox(width: 2),
          Text(
            recipe.averageRating > 0
                ? recipe.averageRating.toStringAsFixed(1)
                : '—',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ],
  );

  String _metaLabel(Recipe recipe) {
    final total = recipe.totalMinutes;
    if (total != null) return '$total phút · ${recipe.authorName ?? 'Ẩn danh'}';
    return recipe.categoryName ?? recipe.authorName ?? 'Công thức';
  }
}
