import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class RewardService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Triggered after the referred user successfully completes their first interaction.
  static Future<void> triggerReferralReward(String inviteeUserId) async {
    try {
      final querySnapshot = await _firestore
          .collection('referrals')
          .where('inviteeId', isEqualTo: inviteeUserId)
          .where('status', isEqualTo: 'pendingActivity')
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        // Promote reward to underReview so the Admin can manually check and pay it.
        await doc.reference.update({
          'status': 'underReview',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint(
            'Referral reward promoted to under review for invitee $inviteeUserId');
      }
    } catch (e) {
      debugPrint('Error triggering referral reward: $e');
    }
  }
}
