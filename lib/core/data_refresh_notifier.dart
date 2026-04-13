import 'package:flutter/foundation.dart';

/// Represents a category of data that can change.
/// Screens subscribe to the channels they care about.
enum DataChannel {
  sales,
  purchases,
  transactions,
  wallets,
  products,
  ledger,
  parties,
  activity,
  returns,
  categories,
}

/// Centralized event bus for data refresh signals.
///
/// When any screen mutates data (add/edit/delete), it calls [notify]
/// with the relevant [DataChannel]s. All listening screens that care
/// about those channels will auto-refresh their data.
///
/// Usage (mutation side):
///   context.read<DataRefreshNotifier>().notify([DataChannel.sales, DataChannel.wallets]);
///
/// Usage (listener side):
///   context.read<DataRefreshNotifier>().addListener(_onDataChanged);
///   void _onDataChanged() {
///     if (notifier.shouldRefresh(DataChannel.sales)) { _fetchSales(); }
///   }
class DataRefreshNotifier extends ChangeNotifier {
  final Set<DataChannel> _changedChannels = {};
  int _version = 0;

  int get version => _version;

  /// Returns true if the given channel was part of the last change notification.
  bool shouldRefresh(DataChannel channel) {
    return _changedChannels.contains(channel);
  }

  /// Returns true if ANY of the given channels were part of the last change.
  bool shouldRefreshAny(Set<DataChannel> channels) {
    return _changedChannels.intersection(channels).isNotEmpty;
  }

  /// Called by mutation screens after a successful data change.
  /// Pass all [DataChannel]s that were affected by this mutation.
  void notify(List<DataChannel> channels) {
    _changedChannels
      ..clear()
      ..addAll(channels);
    _version++;
    debugPrint('DataRefreshNotifier: Notifying channels: $channels (v$_version)');
    notifyListeners();
  }

  /// Convenience: notify a single channel
  void notifySingle(DataChannel channel) {
    notify([channel]);
  }

  /// Convenience: notify all channels (nuclear option for major changes)
  void notifyAll() {
    notify(DataChannel.values);
  }
}
