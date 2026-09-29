/// Compile-time switches for features that are intentionally staged.
const removeAdsFeatureEnabled = bool.fromEnvironment(
  'ENABLE_REMOVE_ADS',
  defaultValue: false,
);

/// Allows app composition tests to exercise both supported flag states.
class FeatureFlags {
  const FeatureFlags({this.removeAdsEnabled = removeAdsFeatureEnabled});

  final bool removeAdsEnabled;
}
