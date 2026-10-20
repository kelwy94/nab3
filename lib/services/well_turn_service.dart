import 'package:cloud_firestore/cloud_firestore.dart';

/// Irrigation rotation ("الدور") for a shared well.
///
/// One document per well at `well_turns/{wellId}` holds the member order,
/// each member's allotted hours, and the live state. Members advance it
/// themselves ("بدأت" / "خلصت" / "البئر واقف"), so expected times always
/// follow what actually happened rather than a fixed calendar.
///
/// Actual irrigation is logged in `well_turns/{wellId}/log`, and the well
/// manager can split bills (electricity, diesel...) by those actual hours in
/// `well_turns/{wellId}/bills`.
class WellTurn {
  final String wellId;
  final String wellName;
  final String managerId;
  final List<String> memberIds;
  final Map<String, String> names;
  final Map<String, double> hours;
  final int currentIndex;
  final String state; // waiting | running | paused
  final DateTime? startedAt;
  final DateTime? pausedAt;
  final int pausedMinutes;
  final String? pauseReason;
  final int cycle;

  const WellTurn({
    required this.wellId,
    required this.wellName,
    required this.managerId,
    required this.memberIds,
    required this.names,
    required this.hours,
    required this.currentIndex,
    required this.state,
    this.startedAt,
    this.pausedAt,
    this.pausedMinutes = 0,
    this.pauseReason,
    this.cycle = 0,
  });

  static const waiting = 'waiting';
  static const running = 'running';
  static const paused = 'paused';

  factory WellTurn.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return WellTurn(
      wellId: doc.id,
      wellName: d['wellName'] ?? '',
      managerId: d['managerId'] ?? '',
      memberIds: List<String>.from(d['memberIds'] ?? const []),
      names: Map<String, String>.from(d['names'] ?? const {}),
      hours: (d['hours'] as Map<String, dynamic>? ?? const {})
          .map((k, v) => MapEntry(k, (v as num).toDouble())),
      currentIndex: (d['currentIndex'] as num?)?.toInt() ?? 0,
      state: d['state'] ?? waiting,
      startedAt: (d['startedAt'] as Timestamp?)?.toDate(),
      pausedAt: (d['pausedAt'] as Timestamp?)?.toDate(),
      pausedMinutes: (d['pausedMinutes'] as num?)?.toInt() ?? 0,
      pauseReason: d['pauseReason'],
      cycle: (d['cycle'] as num?)?.toInt() ?? 0,
    );
  }

  bool get isEmpty => memberIds.isEmpty;
  String get currentUserId =>
      memberIds.isEmpty ? '' : memberIds[currentIndex % memberIds.length];
  String nameOf(String uid) => names[uid] ?? 'شريك';
  double hoursOf(String uid) => hours[uid] ?? 1;
  int get nextIndex => memberIds.isEmpty ? 0 : (currentIndex + 1) % memberIds.length;

  /// Minutes the current member has actually irrigated so far.
  int elapsedMinutes([DateTime? now]) {
    if (startedAt == null) return 0;
    final end = state == paused ? (pausedAt ?? DateTime.now()) : (now ?? DateTime.now());
    final m = end.difference(startedAt!).inMinutes - pausedMinutes;
    return m < 0 ? 0 : m;
  }

  /// Minutes left in the current turn (allotted minus irrigated).
  int remainingMinutes([DateTime? now]) {
    final allotted = (hoursOf(currentUserId) * 60).round();
    final left = allotted - elapsedMinutes(now);
    return left < 0 ? 0 : left;
  }

  /// Members in upcoming order (after the current one) with the expected
  /// minutes from now until each one's turn starts, assuming no stops.
  List<({String uid, int startsInMinutes})> upcoming([DateTime? now]) {
    final out = <({String uid, int startsInMinutes})>[];
    if (memberIds.length < 2) return out;
    var acc = remainingMinutes(now);
    for (var k = 1; k < memberIds.length; k++) {
      final uid = memberIds[(currentIndex + k) % memberIds.length];
      out.add((uid: uid, startsInMinutes: acc));
      acc += (hoursOf(uid) * 60).round();
    }
    return out;
  }
}

class TurnLogEntry {
  final String id;
  final String userId;
  final String name;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int minutes;
  final int allottedMinutes;
  final bool skipped;

  const TurnLogEntry({
    required this.id,
    required this.userId,
    required this.name,
    this.startedAt,
    this.endedAt,
    required this.minutes,
    required this.allottedMinutes,
    this.skipped = false,
  });

  factory TurnLogEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return TurnLogEntry(
      id: doc.id,
      userId: d['userId'] ?? '',
      name: d['name'] ?? '',
      startedAt: (d['startedAt'] as Timestamp?)?.toDate(),
      endedAt: (d['endedAt'] as Timestamp?)?.toDate(),
      minutes: (d['minutes'] as num?)?.toInt() ?? 0,
      allottedMinutes: (d['allottedMinutes'] as num?)?.toInt() ?? 0,
      skipped: d['skipped'] ?? false,
    );
  }
}

class TurnBill {
  final String id;
  final String title;
  final double amount;
  final Map<String, double> shares;
  final Map<String, int> minutes;
  final DateTime? createdAt;

  const TurnBill({
    required this.id,
    required this.title,
    required this.amount,
    required this.shares,
    required this.minutes,
    this.createdAt,
  });

  factory TurnBill.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return TurnBill(
      id: doc.id,
      title: d['title'] ?? '',
      amount: (d['amount'] as num?)?.toDouble() ?? 0,
      shares: (d['shares'] as Map<String, dynamic>? ?? const {})
          .map((k, v) => MapEntry(k, (v as num).toDouble())),
      minutes: (d['minutes'] as Map<String, dynamic>? ?? const {})
          .map((k, v) => MapEntry(k, (v as num).toInt())),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// A well participant offered in the manager's setup screen.
class TurnCandidate {
  final String uid;
  final String name;
  final double areaFeddan;
  const TurnCandidate(this.uid, this.name, this.areaFeddan);
}

class WellTurnService {
  WellTurnService._();

  static final _db = FirebaseFirestore.instance;
  static DocumentReference<Map<String, dynamic>> _ref(String wellId) =>
      _db.collection('well_turns').doc(wellId);

  static Stream<WellTurn?> watch(String wellId) => _ref(wellId)
      .snapshots()
      .map((d) => d.exists ? WellTurn.fromDoc(d) : null);

  static Stream<List<TurnLogEntry>> log(String wellId, {int limit = 30}) =>
      _ref(wellId)
          .collection('log')
          .orderBy('endedAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((s) => s.docs.map(TurnLogEntry.fromDoc).toList());

  static Stream<List<TurnBill>> bills(String wellId) => _ref(wellId)
      .collection('bills')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(TurnBill.fromDoc).toList());

  /// Owner plus approved members of the well, with names and land area.
  static Future<List<TurnCandidate>> candidates(
      String wellId, String ownerId) async {
    final members = await _db
        .collection('well_members')
        .where('wellId', isEqualTo: wellId)
        .where('status', isEqualTo: 'approved')
        .get();
    final areas = <String, double>{ownerId: 0};
    for (final m in members.docs) {
      final uid = m.data()['userId'] as String?;
      if (uid == null) continue;
      areas[uid] = (m.data()['landAreaFeddan'] as num?)?.toDouble() ?? 0;
    }
    final out = <TurnCandidate>[];
    for (final e in areas.entries) {
      final u = await _db.collection('users').doc(e.key).get();
      out.add(TurnCandidate(
          e.key, (u.data()?['fullName'] as String?) ?? 'شريك', e.value));
    }
    return out;
  }

  /// Manager saves the order and hours. Keeps whoever is currently up.
  static Future<void> saveSetup({
    required String wellId,
    required String wellName,
    required String managerId,
    required List<String> order,
    required Map<String, String> names,
    required Map<String, double> hours,
  }) async {
    await _db.runTransaction((t) async {
      final snap = await t.get(_ref(wellId));
      if (!snap.exists) {
        t.set(_ref(wellId), {
          'wellId': wellId,
          'wellName': wellName,
          'managerId': managerId,
          'memberIds': order,
          'names': names,
          'hours': hours,
          'currentIndex': 0,
          'state': WellTurn.waiting,
          'startedAt': null,
          'pausedAt': null,
          'pausedMinutes': 0,
          'pauseReason': null,
          'cycle': 0,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return;
      }
      final current = WellTurn.fromDoc(snap);
      final keep = order.indexOf(current.currentUserId);
      final resetTurn = keep < 0;
      t.update(_ref(wellId), {
        'wellName': wellName,
        'memberIds': order,
        'names': names,
        'hours': hours,
        'currentIndex': resetTurn ? 0 : keep,
        if (resetTurn) ...{
          'state': WellTurn.waiting,
          'startedAt': null,
          'pausedAt': null,
          'pausedMinutes': 0,
          'pauseReason': null,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static Future<void> start(WellTurn turn) => _ref(turn.wellId).update({
        'state': WellTurn.running,
        'startedAt': FieldValue.serverTimestamp(),
        'pausedAt': null,
        'pausedMinutes': 0,
        'pauseReason': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  static Future<void> pause(WellTurn turn, String reason) =>
      _ref(turn.wellId).update({
        'state': WellTurn.paused,
        'pausedAt': FieldValue.serverTimestamp(),
        'pauseReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  static Future<void> resume(WellTurn turn) {
    final stopped = turn.pausedAt == null
        ? 0
        : DateTime.now().difference(turn.pausedAt!).inMinutes;
    return _ref(turn.wellId).update({
      'state': WellTurn.running,
      'pausedAt': null,
      'pauseReason': null,
      'pausedMinutes': turn.pausedMinutes + (stopped < 0 ? 0 : stopped),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Ends the current turn: logs actual minutes and hands over to the next.
  /// [skipped] is used by the manager when a member doesn't take their turn.
  static Future<void> finish(WellTurn turn, {bool skipped = false}) async {
    final uid = turn.currentUserId;
    final batch = _db.batch();
    batch.set(_ref(turn.wellId).collection('log').doc(), {
      'userId': uid,
      'name': turn.nameOf(uid),
      'startedAt': turn.startedAt != null
          ? Timestamp.fromDate(turn.startedAt!)
          : null,
      'endedAt': FieldValue.serverTimestamp(),
      'minutes': skipped ? 0 : turn.elapsedMinutes(),
      'allottedMinutes': (turn.hoursOf(uid) * 60).round(),
      'skipped': skipped,
      'cycle': turn.cycle,
    });
    final wraps = turn.nextIndex == 0;
    batch.update(_ref(turn.wellId), {
      'currentIndex': turn.nextIndex,
      if (wraps) 'cycle': turn.cycle + 1,
      'state': WellTurn.waiting,
      'startedAt': null,
      'pausedAt': null,
      'pausedMinutes': 0,
      'pauseReason': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  /// Splits a bill by actual minutes irrigated since the previous bill
  /// (or the last [fallbackDays] days for the first bill). Falls back to an
  /// equal split when nobody has logged any minutes yet.
  static Future<void> addBill(WellTurn turn,
      {required String title, required double amount, int fallbackDays = 30}) async {
    final ref = _ref(turn.wellId);
    final last = await ref
        .collection('bills')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    final from = last.docs.isNotEmpty
        ? ((last.docs.first.data()['createdAt'] as Timestamp?)?.toDate() ??
            DateTime.now().subtract(Duration(days: fallbackDays)))
        : DateTime.now().subtract(Duration(days: fallbackDays));
    final logs = await ref
        .collection('log')
        .where('endedAt', isGreaterThan: Timestamp.fromDate(from))
        .get();

    final minutes = <String, int>{for (final uid in turn.memberIds) uid: 0};
    for (final d in logs.docs) {
      final uid = d.data()['userId'] as String? ?? '';
      if (!minutes.containsKey(uid)) continue;
      minutes[uid] = minutes[uid]! + ((d.data()['minutes'] as num?)?.toInt() ?? 0);
    }
    final total = minutes.values.fold<int>(0, (a, b) => a + b);
    final shares = <String, double>{
      for (final uid in turn.memberIds)
        uid: total > 0
            ? double.parse((amount * minutes[uid]! / total).toStringAsFixed(2))
            : double.parse((amount / turn.memberIds.length).toStringAsFixed(2)),
    };
    await ref.collection('bills').add({
      'title': title,
      'amount': amount,
      'shares': shares,
      'minutes': minutes,
      'from': Timestamp.fromDate(from),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteBill(String wellId, String billId) =>
      _ref(wellId).collection('bills').doc(billId).delete();
}

/// "3 ساعات و 20 دقيقة" style durations.
String formatTurnDuration(int minutes) {
  if (minutes <= 0) return 'دلوقتي';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  final hs = h == 0
      ? ''
      : h == 1
          ? 'ساعة'
          : h == 2
              ? 'ساعتين'
              : '$h ساعات';
  final ms = m == 0 ? '' : '$m دقيقة';
  if (hs.isEmpty) return ms;
  if (ms.isEmpty) return hs;
  return '$hs و $ms';
}

String formatTurnHours(double h) {
  if (h == h.roundToDouble()) {
    final n = h.toInt();
    return n == 1 ? 'ساعة' : n == 2 ? 'ساعتين' : '$n ساعات';
  }
  return '${h.toStringAsFixed(1)} ساعة';
}
