import 'gear_item.dart';

/// A gear entry attached to a dive. Sealed so the read path can distinguish
/// master-list items from ad-hoc free-text entries via switch/patterns.
///
/// - [GearRef.item]: references a [GearItem] in the master list (row has a
///   non-null `gear_item_id`).
/// - [GearRef.adHoc]: a free-text name entered on the dive form (row has a
///   null `gear_item_id` and a non-null `gear_text`).
///
/// Use [GearRef.item] / [GearRef.adHoc] factories to construct, then pattern
/// match on the subtypes ([GearRefItem] / [GearRefAdHoc]).
sealed class GearRef {
  const GearRef();

  factory GearRef.item(GearItem item) = GearRefItem;

  factory GearRef.adHoc(String text) = GearRefAdHoc;
}

final class GearRefItem extends GearRef {
  final GearItem item;
  const GearRefItem(this.item);
}

final class GearRefAdHoc extends GearRef {
  final String text;
  const GearRefAdHoc(this.text);
}
