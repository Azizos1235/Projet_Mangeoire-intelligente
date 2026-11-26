import '../models/models.dart';

bool matchesCowSearch(
  Cow cow,
  String query, {
  Appetite? appetite,
  Appetite? appetiteFilter,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  final matchesText = normalizedQuery.isEmpty ||
      [
        cow.id,
        cow.internalId,
        cow.nfcUid ?? '',
        cow.breed,
        cow.type.name,
      ].any((value) => value.toLowerCase().contains(normalizedQuery));
  return matchesText && (appetiteFilter == null || appetite == appetiteFilter);
}
