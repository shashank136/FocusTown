import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_town/domain/district.dart';

/// The side of the island the session sheet is looking at for a district, or
/// null when it is not: the island lights up the row that would be built next.
class DistrictPreview extends Notifier<DistrictSide?> {
  @override
  DistrictSide? build() => null;

  /// Previews [side] (null turns the preview off).
  void set(DistrictSide? side) {
    // The sheet clears it as it closes, which may be after the app is gone.
    if (ref.mounted) state = side;
  }
}

/// See [DistrictPreview].
final districtPreviewProvider =
    NotifierProvider<DistrictPreview, DistrictSide?>(DistrictPreview.new);
