import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/types.dart';

class JobProvider with ChangeNotifier {
  List<Job> _jobs = [];
  bool _isLoading = false;
  bool _disposed = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription? _jobsSub;
  StreamSubscription? _authSub;

  List<Job> get jobs => _jobs;
  bool get isLoading => _isLoading;

  JobProvider() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!_disposed) {
        _listenToJobs();
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _jobsSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> fetchJobs() async {
    notifyListeners();
  }

  void _listenToJobs() {
    _jobsSub?.cancel();
    _jobsSub = null;
    _isLoading = true;
    if (!_disposed) notifyListeners();

    _jobsSub = _firestore
        .collection('jobs')
        .snapshots()
        .listen((snapshot) {
      List<Job> parsed = [];
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          parsed.add(Job(
            id: doc.id,
            requesterUserId: data['requesterUserId'] ?? '',
            assignedUserId: data['assignedUserId'],
            type: data['type'] ?? 'worker',
            serviceType: data['serviceType'] ?? '',
            location: data['location'] != null
                ? Map<String, double>.from((data['location'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toDouble())))
                : {'lat': 0.0, 'lng': 0.0},
            startTime:
                (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
            endTime: (data['endTime'] as Timestamp?)?.toDate() ??
                DateTime.now().add(const Duration(hours: 1)),
            status: JobStatus.values.firstWhere(
                (e) => e.toString() == data['status'] || e.toString().split('.').last == (data['status'] ?? ''),
                orElse: () => JobStatus.requested),
            price:
                data['price'] != null ? (data['price'] as num).toDouble() : null,
            notes: data['notes'] ?? '',
            address: data['address'],
            workerRating: data['workerRating'] != null
                ? (data['workerRating'] as num).toDouble()
                : null,
            disputeNote: data['disputeNote'],
            paymentRequestDetails: data['paymentRequestDetails'],
          ));
        } catch (e) {
          debugPrint('JOB_PROVIDER: Error parsing job ${doc.id}: $e');
        }
      }
      // Sort in memory instead of Firestore orderBy (avoids index requirement)
      parsed.sort((a, b) => b.startTime.compareTo(a.startTime));
      _jobs = parsed;
      debugPrint('JOB_PROVIDER: Received ${_jobs.length} jobs from Firestore');
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }, onError: (error) {
      debugPrint('JOB_PROVIDER: Firestore Error: $error');
      _isLoading = false;
      if (!_disposed) notifyListeners();
    });
  }

  Future<void> addJob(Job job) async {
    try {
      await _firestore.collection('jobs').add({
        'requesterUserId': job.requesterUserId,
        'assignedUserId': job.assignedUserId,
        'type': job.type,
        'serviceType': job.serviceType,
        'location': job.location,
        'startTime': Timestamp.fromDate(job.startTime),
        'endTime': Timestamp.fromDate(job.endTime),
        'status': job.status.toString(),
        'price': job.price,
        'notes': job.notes,
        'address': job.address,
        'disputeNote': job.disputeNote,
        'paymentRequestDetails': job.paymentRequestDetails,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error adding job: $e');
      rethrow;
    }
  }

  Future<void> updateJobStatus(String jobId, JobStatus status,
      {String? workerId, String? paymentRequestDetails}) async {
    try {
      final updates = <String, dynamic>{
        'status': status.toString(),
      };

      if (paymentRequestDetails != null) {
        updates['paymentRequestDetails'] = paymentRequestDetails;
      }

      if (workerId != null) {
        updates['assignedUserId'] = workerId;
        updates['acceptedAt'] = FieldValue.serverTimestamp();
      }

      if (status == JobStatus.inProgress) {
        updates['startedAt'] = FieldValue.serverTimestamp();
      } else if (status == JobStatus.completed) {
        updates['completedAt'] = FieldValue.serverTimestamp();
      } else if (status == JobStatus.paid) {
        updates['paidAt'] = FieldValue.serverTimestamp();
      }

      await _firestore.collection('jobs').doc(jobId).update(updates);
    } catch (e) {
      debugPrint('Error updating job status: $e');
      rethrow;
    }
  }

  Future<void> reportDispute(String jobId, String disputeText) async {
    try {
      await _firestore.collection('jobs').doc(jobId).update({
        'status': JobStatus.disputed.toString(),
        'disputeNote': disputeText,
        'disputedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error reporting dispute: $e');
      rethrow;
    }
  }

  Future<void> deleteJob(String jobId) async {
    try {
      await _firestore.collection('jobs').doc(jobId).delete();
    } catch (e) {
      debugPrint('Error deleting job: $e');
      rethrow;
    }
  }

  Future<void> submitJobReview(
      String jobId, String workerId, int stars, String comment) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 1. Add review
      await _firestore.collection('reviews').add({
        'reviewerUserId': user.uid,
        'reviewedUserId': workerId,
        'stars': stars,
        'comment': comment,
        'relatedType': 'job',
        'relatedId': jobId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Mark this job as reviewed (optional but good practice)
      await updateJobStatus(jobId, JobStatus.reviewed);

      // 3. Update worker's average rating
      final reviewsSnapshot = await _firestore
          .collection('reviews')
          .where('reviewedUserId', isEqualTo: workerId)
          .get();

      if (reviewsSnapshot.docs.isNotEmpty) {
        double totalStars = 0;
        for (var doc in reviewsSnapshot.docs) {
          totalStars += (doc.data()['stars'] as num).toDouble();
        }
        double newAvg = totalStars / reviewsSnapshot.docs.length;

        // Fetch user data to update extraData
        final userDoc =
            await _firestore.collection('users').doc(workerId).get();
        if (userDoc.exists) {
          final extraData =
              Map<String, dynamic>.from(userDoc.data()?['extraData'] ?? {});
          extraData['rating'] = newAvg;
          extraData['reviewCount'] = reviewsSnapshot.docs.length;

          await _firestore.collection('users').doc(workerId).update({
            'extraData': extraData,
          });
        }
      }
    } catch (e) {
      debugPrint('Error submitting review: $e');
      rethrow;
    }
  }

  Future<void> confirmPaymentAndTransfer(Job job) async {
    try {
      if (job.assignedUserId == null || job.price == null) return;

      final batch = _firestore.batch();

      // 1. Update Job Status
      final jobRef = _firestore.collection('jobs').doc(job.id);
      batch.update(jobRef, {
        'status': JobStatus.paid.toString(),
        'paidAt': FieldValue.serverTimestamp(),
      });

      // 2. Update Provider Wallet
      final walletRef =
          _firestore.collection('wallets').doc(job.assignedUserId);
      final walletDoc = await walletRef.get();

      if (walletDoc.exists) {
        batch.update(walletRef, {
          'balance': FieldValue.increment(job.price!),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        batch.set(walletRef, {
          'userId': job.assignedUserId,
          'balance': job.price!,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // 3. Record Transaction
      final transRef = _firestore.collection('transactions').doc();
      batch.set(transRef, {
        'userId': job.assignedUserId,
        'amount': job.price!,
        'type': 'incoming',
        'note': 'مقابل خدمة: ${job.serviceType}',
        'relatedId': job.id,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      debugPrint('Error in confirmPaymentAndTransfer: $e');
      rethrow;
    }
  }

  void seedMockJobs() {
    // Deprecated: No longer using mock data in JobProvider
  }
}
