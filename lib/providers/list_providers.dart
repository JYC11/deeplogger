import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_helper.dart';
import '../database/sort_fields.dart';
import '../models/certification.dart';
import '../models/dive_log.dart';
import '../models/gear_item.dart';
import 'dive_providers.dart';

/// Paginated, searchable, sortable list state for dive logs (C3).
class DiveListState {
  const DiveListState({
    this.logs = const [],
    this.page = 0,
    this.hasMore = true,
    this.search,
    this.sortField = DiveLogSortField.startTime,
    this.sortDesc = true,
    this.includeDrafts = true,
    this.isLoadingMore = false,
  });

  final List<DiveLog> logs;
  final int page;
  final bool hasMore;
  final String? search;
  final DiveLogSortField sortField;
  final bool sortDesc;
  final bool includeDrafts;
  final bool isLoadingMore;

  DiveListState copyWith({
    List<DiveLog>? logs,
    int? page,
    bool? hasMore,
    String? search,
    DiveLogSortField? sortField,
    bool? sortDesc,
    bool? includeDrafts,
    bool? isLoadingMore,
  }) {
    return DiveListState(
      logs: logs ?? this.logs,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      search: search ?? this.search,
      sortField: sortField ?? this.sortField,
      sortDesc: sortDesc ?? this.sortDesc,
      includeDrafts: includeDrafts ?? this.includeDrafts,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

/// Manages paginated dive-log list state. Initial load on [build]; [loadMore]
/// appends the next page; [setSearch]/[setSort] reset to page 0 with new
/// filters; [refresh] reloads keeping the current search/sort.
class DiveListNotifier extends AsyncNotifier<DiveListState> {
  static const int _pageSize = 20;

  DatabaseHelper get _db => ref.read(databaseProvider);

  @override
  Future<DiveListState> build() async {
    final result = await _db.getDiveLogs(
      limit: _pageSize,
      offset: 0,
      sortField: DiveListState().sortField,
      sortDesc: true,
    );
    return DiveListState(logs: result.logs, hasMore: result.hasMore);
  }

  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || s.isLoadingMore || !s.hasMore) return;
    _update(s.copyWith(isLoadingMore: true));
    final next = s.page + 1;
    final result = await _db.getDiveLogs(
      limit: _pageSize,
      offset: next * _pageSize,
      search: s.search,
      sortField: s.sortField,
      sortDesc: s.sortDesc,
      includeDrafts: s.includeDrafts,
    );
    _update(
      s.copyWith(
        logs: [...s.logs, ...result.logs],
        page: next,
        hasMore: result.hasMore,
        isLoadingMore: false,
      ),
    );
  }

  Future<void> setSearch(String? query) async {
    _update(state.value!.copyWith(search: query, logs: const [], page: 0));
    final result = await _db.getDiveLogs(
      limit: _pageSize,
      offset: 0,
      search: query,
      sortField: state.value!.sortField,
      sortDesc: state.value!.sortDesc,
      includeDrafts: state.value!.includeDrafts,
    );
    _update(state.value!.copyWith(logs: result.logs, hasMore: result.hasMore));
  }

  Future<void> setSort(DiveLogSortField field, bool desc) async {
    _update(
      state.value!.copyWith(
        sortField: field,
        sortDesc: desc,
        logs: const [],
        page: 0,
      ),
    );
    final result = await _db.getDiveLogs(
      limit: _pageSize,
      offset: 0,
      search: state.value!.search,
      sortField: field,
      sortDesc: desc,
      includeDrafts: state.value!.includeDrafts,
    );
    _update(state.value!.copyWith(logs: result.logs, hasMore: result.hasMore));
  }

  /// Reloads page 0 keeping the current search/sort (replaces
  /// `ref.invalidate(diveListProvider)` which lost that state).
  Future<void> refresh() async {
    final s = state.value!;
    final result = await _db.getDiveLogs(
      limit: _pageSize,
      offset: 0,
      search: s.search,
      sortField: s.sortField,
      sortDesc: s.sortDesc,
      includeDrafts: s.includeDrafts,
    );
    _update(
      s.copyWith(
        logs: result.logs,
        page: 0,
        hasMore: result.hasMore,
        isLoadingMore: false,
      ),
    );
  }

  void _update(DiveListState s) {
    state = AsyncData(s);
  }
}

final diveListNotifierProvider =
    AsyncNotifierProvider<DiveListNotifier, DiveListState>(
      DiveListNotifier.new,
    );

/// Paginated gear list state.
class GearListState {
  const GearListState({
    this.items = const [],
    this.page = 0,
    this.hasMore = true,
    this.search,
    this.category,
    this.sortField = GearSortField.name,
    this.sortDesc = false,
    this.isLoadingMore = false,
  });

  final List<GearItem> items;
  final int page;
  final bool hasMore;
  final String? search;
  final String? category;
  final GearSortField sortField;
  final bool sortDesc;
  final bool isLoadingMore;

  GearListState copyWith({
    List<GearItem>? items,
    int? page,
    bool? hasMore,
    String? search,
    String? category,
    GearSortField? sortField,
    bool? sortDesc,
    bool? isLoadingMore,
  }) {
    return GearListState(
      items: items ?? this.items,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      search: search ?? this.search,
      category: category ?? this.category,
      sortField: sortField ?? this.sortField,
      sortDesc: sortDesc ?? this.sortDesc,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class GearListNotifier extends AsyncNotifier<GearListState> {
  static const int _pageSize = 20;

  DatabaseHelper get _db => ref.read(databaseProvider);

  @override
  Future<GearListState> build() async {
    final r = await _db.getGearItems(limit: _pageSize, offset: 0);
    return GearListState(items: r.items, hasMore: r.hasMore);
  }

  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || s.isLoadingMore || !s.hasMore) return;
    _update(s.copyWith(isLoadingMore: true));
    final next = s.page + 1;
    final r = await _db.getGearItems(
      limit: _pageSize,
      offset: next * _pageSize,
      search: s.search,
      category: s.category,
      sortField: s.sortField,
      sortDesc: s.sortDesc,
    );
    _update(
      s.copyWith(
        items: [...s.items, ...r.items],
        page: next,
        hasMore: r.hasMore,
        isLoadingMore: false,
      ),
    );
  }

  Future<void> setSearch(String? query) async {
    _update(state.value!.copyWith(search: query, items: const [], page: 0));
    final r = await _db.getGearItems(
      limit: _pageSize,
      offset: 0,
      search: query,
      category: state.value!.category,
      sortField: state.value!.sortField,
      sortDesc: state.value!.sortDesc,
    );
    _update(state.value!.copyWith(items: r.items, hasMore: r.hasMore));
  }

  Future<void> setCategoryFilter(String? category) async {
    _update(
      state.value!.copyWith(category: category, items: const [], page: 0),
    );
    final r = await _db.getGearItems(
      limit: _pageSize,
      offset: 0,
      search: state.value!.search,
      category: category,
      sortField: state.value!.sortField,
      sortDesc: state.value!.sortDesc,
    );
    _update(state.value!.copyWith(items: r.items, hasMore: r.hasMore));
  }

  Future<void> refresh() async {
    final s = state.value!;
    final r = await _db.getGearItems(
      limit: _pageSize,
      offset: 0,
      search: s.search,
      category: s.category,
      sortField: s.sortField,
      sortDesc: s.sortDesc,
    );
    _update(s.copyWith(items: r.items, page: 0, hasMore: r.hasMore));
  }

  void _update(GearListState s) {
    state = AsyncData(s);
  }
}

final gearListNotifierProvider =
    AsyncNotifierProvider<GearListNotifier, GearListState>(
      GearListNotifier.new,
    );

/// Paginated certification list state.
class CertificationListState {
  const CertificationListState({
    this.certs = const [],
    this.page = 0,
    this.hasMore = true,
    this.search,
    this.sortField = CertificationSortField.org,
    this.sortDesc = false,
    this.isLoadingMore = false,
  });

  final List<Certification> certs;
  final int page;
  final bool hasMore;
  final String? search;
  final CertificationSortField sortField;
  final bool sortDesc;
  final bool isLoadingMore;

  CertificationListState copyWith({
    List<Certification>? certs,
    int? page,
    bool? hasMore,
    String? search,
    CertificationSortField? sortField,
    bool? sortDesc,
    bool? isLoadingMore,
  }) {
    return CertificationListState(
      certs: certs ?? this.certs,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      search: search ?? this.search,
      sortField: sortField ?? this.sortField,
      sortDesc: sortDesc ?? this.sortDesc,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class CertificationListNotifier extends AsyncNotifier<CertificationListState> {
  static const int _pageSize = 20;

  DatabaseHelper get _db => ref.read(databaseProvider);

  @override
  Future<CertificationListState> build() async {
    final r = await _db.getCertifications(limit: _pageSize, offset: 0);
    return CertificationListState(certs: r.certs, hasMore: r.hasMore);
  }

  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || s.isLoadingMore || !s.hasMore) return;
    _update(s.copyWith(isLoadingMore: true));
    final next = s.page + 1;
    final r = await _db.getCertifications(
      limit: _pageSize,
      offset: next * _pageSize,
      search: s.search,
      sortField: s.sortField,
      sortDesc: s.sortDesc,
    );
    _update(
      s.copyWith(
        certs: [...s.certs, ...r.certs],
        page: next,
        hasMore: r.hasMore,
        isLoadingMore: false,
      ),
    );
  }

  Future<void> setSearch(String? query) async {
    _update(state.value!.copyWith(search: query, certs: const [], page: 0));
    final r = await _db.getCertifications(
      limit: _pageSize,
      offset: 0,
      search: query,
      sortField: state.value!.sortField,
      sortDesc: state.value!.sortDesc,
    );
    _update(state.value!.copyWith(certs: r.certs, hasMore: r.hasMore));
  }

  Future<void> refresh() async {
    final s = state.value!;
    final r = await _db.getCertifications(
      limit: _pageSize,
      offset: 0,
      search: s.search,
      sortField: s.sortField,
      sortDesc: s.sortDesc,
    );
    _update(s.copyWith(certs: r.certs, page: 0, hasMore: r.hasMore));
  }

  void _update(CertificationListState s) {
    state = AsyncData(s);
  }
}

final certificationListNotifierProvider =
    AsyncNotifierProvider<CertificationListNotifier, CertificationListState>(
      CertificationListNotifier.new,
    );
