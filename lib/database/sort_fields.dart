/// Sortable fields for [DiveLog] list queries.
///
/// Acts as a whitelist for ORDER BY clauses to prevent SQL injection — the
/// query layer maps each value to a literal column name rather than
/// interpolating a raw string.
enum DiveLogSortField {
  startTime('start_time'),
  location('location'),
  maxDepthM('max_depth_m'),
  durationMin('duration_min');

  const DiveLogSortField(this.column);

  final String column;
}

/// Sortable fields for [Certification] list queries.
enum CertificationSortField {
  org('org'),
  issueDate('issue_date');

  const CertificationSortField(this.column);

  final String column;
}

/// Sortable fields for [GearItem] list queries.
enum GearSortField {
  name('name'),
  category('category');

  const GearSortField(this.column);

  final String column;
}
