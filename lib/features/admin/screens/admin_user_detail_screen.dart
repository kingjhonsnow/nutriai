import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nutri_ai/core/constants/app_colors.dart';
import 'package:nutri_ai/core/constants/app_text_styles.dart';
import 'package:nutri_ai/core/services/app_exception.dart';
import 'package:nutri_ai/data/models/account_info.dart';
import 'package:nutri_ai/features/admin/data/admin_activity_repository.dart';

final NumberFormat _n0 = NumberFormat('#,##0');
final NumberFormat _n1 = NumberFormat('#,##0.#');
final DateFormat _dayFormat = DateFormat('EEE d MMM');
final DateFormat _dayYearFormat = DateFormat('d MMM yyyy');
final DateFormat _timeFormat = DateFormat('HH:mm');

String _dayLabel(DateTime day) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(day.year, day.month, day.day);
  final diff = today.difference(d).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return _dayFormat.format(d);
}

String _pretty(String? value) {
  if (value == null || value.trim().isEmpty) return '--';
  final s = value.replaceAll('_', ' ').trim();
  return s[0].toUpperCase() + s.substring(1);
}

String _sourceLabel(String? source) {
  switch (source) {
    case null:
    case '':
      return '';
    case 'food_list':
      return 'Food list';
    case 'manual':
      return 'Scan, corrected';
    case 'usda':
    case 'tunisian_table':
    case 'ai_estimate':
      return 'AI scan';
    case 'package_label':
      return 'AI scan, pack label';
    default:
      return _pretty(source);
  }
}

/// Read-only view of one person's app use and data, for the admin.
class AdminUserDetailScreen extends StatelessWidget {
  final AccountInfo account;

  const AdminUserDetailScreen({super.key, required this.account});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(account.fullName, overflow: TextOverflow.ellipsis),
              Text(
                account.email,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          bottom: const TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            labelPadding: EdgeInsets.symmetric(horizontal: 4),
            tabs: [
              Tab(icon: Icon(Icons.timeline_rounded), text: 'Activity'),
              Tab(icon: Icon(Icons.restaurant_rounded), text: 'Food'),
              Tab(icon: Icon(Icons.monitor_weight_rounded), text: 'Progress'),
              Tab(icon: Icon(Icons.document_scanner_rounded), text: 'Scans'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ActivityTab(userId: account.id),
            _FoodTab(userId: account.id),
            _ProgressTab(userId: account.id),
            _ScansTab(userId: account.id),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Shared building blocks
// -----------------------------------------------------------------------------
class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: child,
    );
  }
}

class _Title extends StatelessWidget {
  final String text;

  const _Title(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: AppTextStyles.titleSmall.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;

  const _Stat(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.titleMedium.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Muted extends StatelessWidget {
  final String text;

  const _Muted(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary));
  }
}

/// Shows a spinner while loading, an error with "Try again", or the content.
class _FutureView<T> extends StatelessWidget {
  final Future<T> future;
  final VoidCallback onRetry;
  final Widget Function(T data) builder;

  const _FutureView({required this.future, required this.onRetry, required this.builder});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    friendlyError(snap.error!),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
                ],
              ),
            ),
          );
        }
        return builder(snap.data as T);
      },
    );
  }
}

/// Pull to refresh around a list, ignoring load errors (they are shown inside).
Widget _refreshable(Future<void> Function() reload, Widget child) {
  return RefreshIndicator(
    color: AppColors.primary,
    onRefresh: () async {
      try {
        await reload();
      } catch (_) {}
    },
    child: child,
  );
}

// -----------------------------------------------------------------------------
// ACTIVITY: app opens and time spent per day, recent visits
// -----------------------------------------------------------------------------
class _ActivityData {
  final List<DailyActivity> days;
  final List<AppSession> sessions;

  const _ActivityData(this.days, this.sessions);
}

class _ActivityTab extends ConsumerStatefulWidget {
  final String userId;

  const _ActivityTab({required this.userId});

  @override
  ConsumerState<_ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends ConsumerState<_ActivityTab> with AutomaticKeepAliveClientMixin {
  late Future<_ActivityData> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ActivityData> _load() async {
    final repo = ref.read(adminActivityRepositoryProvider);
    final days = await repo.dailyActivity(widget.userId, days: 14);
    final sessions = await repo.recentSessions(widget.userId, limit: 30);
    return _ActivityData(days, sessions);
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _FutureView<_ActivityData>(
      future: _future,
      onRetry: _reload,
      builder: (data) {
        final today = data.days.isNotEmpty ? data.days.first : null;
        final activeDays = data.days.where((d) => d.opens > 0).length;
        final totalMinutes = data.days.fold<int>(0, (sum, d) => sum + d.minutes);
        final avgMinutes = activeDays == 0 ? 0 : (totalMinutes / activeDays).round();

        return _refreshable(
          _reload,
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Title('Today'),
                    Row(
                      children: [
                        _Stat('${today?.opens ?? 0}', 'app opens'),
                        _Stat('${today?.minutes ?? 0} min', 'time in app'),
                        _Stat('${today?.meals ?? 0}', 'foods logged'),
                        _Stat('${today?.scans ?? 0}', 'AI scans'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: AppColors.surfaceBorder),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _Stat('$activeDays/${data.days.length}', 'active days'),
                        _Stat('${data.days.fold<int>(0, (sum, d) => sum + d.opens)}', 'opens in 14 days'),
                        _Stat('$avgMinutes min', 'per active day'),
                      ],
                    ),
                  ],
                ),
              ),
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Title('Last 14 days'),
                    ...data.days.map((d) => _DayRow(day: d)),
                  ],
                ),
              ),
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Title('Recent visits'),
                    if (data.sessions.isEmpty)
                      const _Muted('No visits recorded yet. Visits are counted from this update on.')
                    else
                      ...data.sessions.map((s) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                const Icon(Icons.login_rounded, size: 16, color: AppColors.primary),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '${_dayLabel(s.startedAt)}, ${_timeFormat.format(s.startedAt)} to '
                                    '${_timeFormat.format(s.lastSeenAt)} (${s.minutes} min)',
                                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _Muted(s.deviceLabel),
                              ],
                            ),
                          )),
                  ],
                ),
              ),
              const _Muted('A visit is one continuous use of the app. A break of more than 15 minutes '
                  'starts a new visit. Time in app is measured while the app is on screen.'),
            ],
          ),
        );
      },
    );
  }
}

class _DayRow extends StatelessWidget {
  final DailyActivity day;

  const _DayRow({required this.day});

  @override
  Widget build(BuildContext context) {
    final used = day.opens > 0;
    final details = <String>[
      if (used) '${day.opens} ${day.opens == 1 ? 'open' : 'opens'}, ${day.minutes} min',
      if (day.meals > 0) '${day.meals} foods, ${_n0.format(day.calories)} kcal',
      if (day.waterMl > 0) '${_n0.format(day.waterMl)} ml water',
      if (day.scans > 0) '${day.scans} ${day.scans == 1 ? 'scan' : 'scans'}',
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Icon(Icons.circle, size: 8, color: used ? AppColors.success : AppColors.textDisabled),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: Text(
              _dayLabel(day.day),
              style: AppTextStyles.bodySmall.copyWith(
                color: used ? AppColors.textPrimary : AppColors.textTertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              details.isEmpty ? 'Not used' : details.join(' · '),
              style: AppTextStyles.bodySmall.copyWith(
                color: details.isEmpty ? AppColors.textTertiary : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// FOOD: what the person logged on a chosen day
// -----------------------------------------------------------------------------
class _FoodData {
  final List<AdminFoodLog> logs;
  final int waterMl;
  final Map<String, dynamic>? targets;

  const _FoodData(this.logs, this.waterMl, this.targets);
}

class _FoodTab extends ConsumerStatefulWidget {
  final String userId;

  const _FoodTab({required this.userId});

  @override
  ConsumerState<_FoodTab> createState() => _FoodTabState();
}

class _FoodTabState extends ConsumerState<_FoodTab> with AutomaticKeepAliveClientMixin {
  late DateTime _day;
  late Future<_FoodData> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _day = DateTime(now.year, now.month, now.day);
    _future = _load();
  }

  Future<_FoodData> _load() async {
    final repo = ref.read(adminActivityRepositoryProvider);
    final logs = await repo.foodLogs(widget.userId, _day);
    final water = await repo.waterMl(widget.userId, _day);
    final targets = await repo.activeTargets(widget.userId);
    return _FoodData(logs, water, targets);
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  bool get _isToday {
    final now = DateTime.now();
    return _day.year == now.year && _day.month == now.month && _day.day == now.day;
  }

  void _shiftDay(int days) {
    if (days > 0 && _isToday) return;
    setState(() {
      _day = DateTime(_day.year, _day.month, _day.day + days);
      _future = _load();
    });
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _day = DateTime(picked.year, picked.month, picked.day);
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                tooltip: 'Previous day',
                onPressed: () => _shiftDay(-1),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: _pickDay,
                  icon: const Icon(Icons.calendar_today_rounded, size: 18),
                  label: Text('${_dayLabel(_day)}, ${_dayYearFormat.format(_day)}'),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                tooltip: 'Next day',
                onPressed: _isToday ? null : () => _shiftDay(1),
              ),
            ],
          ),
        ),
        Expanded(
          child: _FutureView<_FoodData>(
            future: _future,
            onRetry: _reload,
            builder: (data) => _refreshable(_reload, _foodList(data)),
          ),
        ),
      ],
    );
  }

  Widget _foodList(_FoodData data) {
    final logs = data.logs;
    final kcal = logs.fold<double>(0, (s, l) => s + l.calories);
    final protein = logs.fold<double>(0, (s, l) => s + l.protein);
    final carbs = logs.fold<double>(0, (s, l) => s + l.carbs);
    final fat = logs.fold<double>(0, (s, l) => s + l.fat);
    final t = data.targets;

    String ofTarget(double value, String key, String unit) {
      final target = t == null ? null : t[key];
      final v = _n0.format(value);
      if (target == null) return '$v $unit';
      return '$v / ${_n0.format(target is num ? target : num.tryParse(target.toString()) ?? 0)} $unit';
    }

    const mealOrder = ['breakfast', 'lunch', 'dinner', 'snack'];
    final byMeal = <String, List<AdminFoodLog>>{};
    for (final l in logs) {
      byMeal.putIfAbsent(l.mealType, () => []).add(l);
    }
    final mealKeys = [
      ...mealOrder.where(byMeal.containsKey),
      ...byMeal.keys.where((k) => !mealOrder.contains(k)),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Title('Day total (eaten / target)'),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _chip(Icons.local_fire_department_rounded, AppColors.accent, ofTarget(kcal, 'daily_calories', 'kcal')),
                  _chip(Icons.fitness_center_rounded, AppColors.protein, 'P ${ofTarget(protein, 'protein_grams', 'g')}'),
                  _chip(Icons.grain_rounded, AppColors.carbs, 'C ${ofTarget(carbs, 'carbs_grams', 'g')}'),
                  _chip(Icons.opacity_rounded, AppColors.fat, 'F ${ofTarget(fat, 'fat_grams', 'g')}'),
                  _chip(Icons.water_drop_rounded, AppColors.water, ofTarget(data.waterMl.toDouble(), 'water_ml', 'ml')),
                ],
              ),
            ],
          ),
        ),
        if (logs.isEmpty)
          const _Card(child: _Muted('Nothing was logged on this day.'))
        else
          ...mealKeys.map((meal) {
            final items = byMeal[meal]!;
            final mealKcal = items.fold<double>(0, (s, l) => s + l.calories);
            return _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _Title(_pretty(meal))),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          '${_n0.format(mealKcal)} kcal',
                          style: AppTextStyles.labelMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  ...items.map((l) {
                    final source = _sourceLabel(l.source);
                    final time = l.createdAt == null ? '' : _timeFormat.format(l.createdAt!);
                    final meta = [
                      '${_n0.format(l.grams)} g',
                      'P ${_n1.format(l.protein)} · C ${_n1.format(l.carbs)} · F ${_n1.format(l.fat)}',
                      if (source.isNotEmpty) source,
                      if (time.isNotEmpty) time,
                    ].join(' · ');
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l.name, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary)),
                                const SizedBox(height: 2),
                                _Muted(meta),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_n0.format(l.calories)} kcal',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _chip(IconData icon, Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(text, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary)),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// PROGRESS: profile, goal, targets, weight and measurements
// -----------------------------------------------------------------------------
class _ProgressTab extends ConsumerStatefulWidget {
  final String userId;

  const _ProgressTab({required this.userId});

  @override
  ConsumerState<_ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends ConsumerState<_ProgressTab> with AutomaticKeepAliveClientMixin {
  late Future<AdminUserProgress> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = ref.read(adminActivityRepositoryProvider).progress(widget.userId);
  }

  Future<void> _reload() async {
    setState(() => _future = ref.read(adminActivityRepositoryProvider).progress(widget.userId));
    await _future;
  }

  String _v(Object? value, String unit) {
    if (value == null) return '--';
    final n = value is num ? value : num.tryParse(value.toString());
    if (n == null) return '--';
    return '${_n1.format(n)} $unit'.trim();
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary))),
          Text(value, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _FutureView<AdminUserProgress>(
      future: _future,
      onRetry: _reload,
      builder: (data) {
        final p = data.profile ?? const <String, dynamic>{};
        final t = data.targets;
        return _refreshable(
          _reload,
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Title('Profile and goal'),
                    _line('Goal', _pretty(data.goalType)),
                    _line('Age', _v(p['age'], 'years')),
                    _line('Gender', _pretty(p['gender'] as String?)),
                    _line('Height', _v(p['height_cm'], 'cm')),
                    _line('Current weight', _v(p['current_weight_kg'], 'kg')),
                    _line('Target weight', _v(p['target_weight_kg'], 'kg')),
                    _line('Activity level', _pretty(p['activity_level'] as String?)),
                  ],
                ),
              ),
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Title('Daily targets'),
                    if (t == null)
                      const _Muted('No targets set yet.')
                    else ...[
                      _line('Calories', _v(t['daily_calories'], 'kcal')),
                      _line('Protein', _v(t['protein_grams'], 'g')),
                      _line('Carbs', _v(t['carbs_grams'], 'g')),
                      _line('Fat', _v(t['fat_grams'], 'g')),
                      _line('Water', _v(t['water_ml'], 'ml')),
                    ],
                  ],
                ),
              ),
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Title('Weight history'),
                    if (data.weights.isEmpty)
                      const _Muted('No weight entries yet.')
                    else
                      ...List.generate(data.weights.length, (i) {
                        final w = data.weights[i];
                        final older = i + 1 < data.weights.length ? data.weights[i + 1] : null;
                        final change = older == null ? null : w.kg - older.kg;
                        final changeText = change == null || change.abs() < 0.05
                            ? ''
                            : '  (${change > 0 ? '+' : ''}${_n1.format(change)})';
                        final fat = w.bodyFat == null ? '' : ' · ${_n1.format(w.bodyFat)} % fat';
                        return _line(_dayYearFormat.format(w.date), '${_n1.format(w.kg)} kg$changeText$fat');
                      }),
                  ],
                ),
              ),
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Title('Body measurements'),
                    if (data.measurements.isEmpty)
                      const _Muted('No measurements yet.')
                    else
                      ...data.measurements.map((m) {
                        final parts = m.values.entries
                            .where((e) => e.value != null)
                            .map((e) => '${e.key} ${_n1.format(e.value)}')
                            .join(' · ');
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _dayYearFormat.format(m.date),
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              _Muted(parts.isEmpty ? '--' : '$parts (cm)'),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// SCANS: AI photo scans and what was found
// -----------------------------------------------------------------------------
class _ScansTab extends ConsumerStatefulWidget {
  final String userId;

  const _ScansTab({required this.userId});

  @override
  ConsumerState<_ScansTab> createState() => _ScansTabState();
}

class _ScansTabState extends ConsumerState<_ScansTab> with AutomaticKeepAliveClientMixin {
  late Future<List<AdminScan>> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = ref.read(adminActivityRepositoryProvider).scans(widget.userId);
  }

  Future<void> _reload() async {
    setState(() => _future = ref.read(adminActivityRepositoryProvider).scans(widget.userId));
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _FutureView<List<AdminScan>>(
      future: _future,
      onRetry: _reload,
      builder: (scans) => _refreshable(
        _reload,
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (scans.isEmpty)
              const _Card(child: _Muted('No AI scans saved yet. A scan is saved when the person adds it to their diary.'))
            else
              ...scans.map((s) => _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${_dayLabel(s.scannedAt)}, ${_timeFormat.format(s.scannedAt)}',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '${_n0.format(s.calories)} kcal',
                              style: AppTextStyles.labelMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        _Muted('P ${_n1.format(s.protein)} g · C ${_n1.format(s.carbs)} g · F ${_n1.format(s.fat)} g'),
                        const SizedBox(height: 8),
                        Text(
                          s.items.isEmpty ? 'No items' : s.items.join(', '),
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
