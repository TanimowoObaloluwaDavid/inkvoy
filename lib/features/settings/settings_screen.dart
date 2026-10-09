import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/brand.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/app_logo.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final sessions = ref.watch(sessionsRepoProvider);
    final saved = ref.watch(savedRepoProvider);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          10,
          AppSpacing.page,
          96,
        ),
        children: [
          Text(
            'Settings',
            style: AppTheme.serif(size: 32, weight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.espresso,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: const Center(child: InkvoyMark(size: 34)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        Brand.name,
                        style: AppTheme.serif(
                          size: 22,
                          weight: FontWeight.w700,
                        ),
                      ),
                      Text(Brand.tagline, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                Text('v${Brand.version}', style: theme.textTheme.labelMedium),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Appearance',
            style: AppTheme.serif(size: 18, weight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _card(
            theme,
            children: [
              _tile(
                theme,
                icon: PhosphorIconsFill.moonStars,
                title: 'Dark mode',
                subtitle: settings.themeMode == ThemeMode.dark
                    ? 'Always on'
                    : settings.themeMode == ThemeMode.light
                    ? 'Always off'
                    : 'Follows your device',
                trailing: Switch(
                  value: settings.themeMode == ThemeMode.dark,
                  onChanged: (v) => ref
                      .read(settingsProvider.notifier)
                      .setThemeMode(v ? ThemeMode.dark : ThemeMode.light),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Reading pacing',
            style: AppTheme.serif(size: 18, weight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _card(
            theme,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily goal',
                      style: theme.textTheme.titleSmall!.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'A quiet rhythm you can change anytime',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          const [
                                (5, 'Light'),
                                (10, 'Balanced'),
                                (15, 'Consistent'),
                                (20, 'Deep'),
                              ]
                              .map(
                                (t) => ChoiceChip(
                                  label: Text('${t.$1} min · ${t.$2}'),
                                  selected: settings.dailyGoal == t.$1,
                                  onSelected: (_) => ref
                                      .read(settingsProvider.notifier)
                                      .setDailyGoal(t.$1),
                                ),
                              )
                              .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Library',
            style: AppTheme.serif(size: 18, weight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _card(
            theme,
            children: [
              _tile(
                theme,
                icon: PhosphorIconsFill.bookmark,
                title: 'Saved books',
                subtitle: '${saved.length} in your library',
              ),
              _divider(theme),
              _tile(
                theme,
                icon: PhosphorIconsFill.clock,
                title: 'Reading sessions',
                subtitle: '${sessions.length} logged',
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Data',
            style: AppTheme.serif(size: 18, weight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _card(
            theme,
            children: [
              _tile(
                theme,
                icon: PhosphorIconsFill.trash,
                title: 'Erase reading history',
                subtitle: 'Removes all sessions from Insights',
                onTap: sessions.isEmpty
                    ? null
                    : () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Clear reading history?'),
                            content: Text(
                              '${sessions.length} sessions will be deleted.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Clear'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true)
                          ref.read(sessionsRepoProvider.notifier).clearAll();
                      },
                iconColor: theme.colorScheme.onSurfaceVariant,
              ),
              _divider(theme),
              _tile(
                theme,
                icon: PhosphorIconsFill.package,
                title: 'Reset library',
                subtitle: 'Removes every saved book (keeps reader cache)',
                onTap: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Reset library?'),
                      content: const Text(
                        'All saved books and shelves will be removed.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    for (final e in ref.read(savedRepoProvider)) {
                      ref.read(savedRepoProvider.notifier).remove(e.book.key);
                    }
                  }
                },
                iconColor: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'Books & covers: Open Library · Text: Project Gutenberg\nMade with warmth for digital readers.',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium!.copyWith(height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(ThemeData theme, {required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(children: children),
    );
  }

  Widget _divider(ThemeData theme) => Divider(
    height: 1,
    thickness: 1,
    color: theme.colorScheme.outlineVariant,
    indent: 58,
    endIndent: 16,
  );

  Widget _tile(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Color? iconColor,
    Widget? trailing,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: (iconColor ?? theme.colorScheme.primary).withValues(
            alpha: 0.12,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 19,
          color: iconColor ?? theme.colorScheme.primary,
        ),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleSmall!.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
      trailing:
          trailing ??
          (onTap == null
              ? null
              : Icon(
                  PhosphorIconsRegular.caretRight,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                )),
      onTap: onTap,
    );
  }
}
