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

  void _listenToJobs() async {
    _jobsSub?.cancel();
    _jobsSub = null;
    _isLoading = true;
    if (!_disposed) notifyListeners();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _jobs = [];
      _isLoading = false;
      if (!_disposed) notifyListeners();
      return;
    }

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) {
      _isLoading = false;
      if (!_disposed) notifyListeners();
      return;
    }

    final role = userDoc.data()?['role'];
    Query<Map<String, dynamic>> query;
    if (role == 'UserRole.farmer' || role == 'farmer') {
      query = _firestore
          .collection('jobs')
          .where('requesterUserId', isEqualTo: user.uid);
    } else if (role == 'UserRole.worker' ||
        role == 'worker' ||
        role == 'UserRole.equipmentOwner' ||
        role == 'equipmentOwner') {
      query = _firestore.collection('jobs').where(Filter.or(
          Filter('assignedUserId', isEqualTo: user.uid),
          Filter('status', isEqualTo: JobStatus.requested.toString())));
    } else {
      query = _firestore.collection('jobs');
    }

    _jobsSub = query.snapshots().listen((snapshot) {
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
                ? Map<String, double>.from((data['location'] as Map).map(
                    (k, v) => MapEntry(k.toString(), (v as num).toDouble())))
                : {'lat': 0.0, 'lng': 0.0},
            startTime:
                (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
            endTime: (data['endTime'] as Timestamp?)?.toDate() ??
                DateTime.now().add(const Duration(hours: 1)),
            status: JobStatus.values.firstWhere(
                (e) =>
                    e.toString() == data['status'] ||
                    e.toString().split('.').last == (data['status'] ?? ''),
                orElse: () => JobStatus.requested),
            price: data['price'] != null
                ? (data['price'] as num).toDouble()
                : null,
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
      // The worker's average rating is recomputed by the onReviewCreated
      // Cloud Function, since clients can't write other users' profiles.
      await updateJobStatus(jobId, JobStatus.reviewed);
    } catch (e) {
      debugPrint('Error submitting review: $e');
      rethrow;
    }
  }

  Future<void> confirmPaymentAndTransfer(Job job) async {
    try {
      if (job.assignedUserId == null || job.price == null) return;

      // The wallet credit and transaction record are written server-side by
      // the onJobPaid Cloud Function when the status flips to paid.
      await _firestore.collection('jobs').doc(job.id).update({
        'status': JobStatus.paid.toString(),
        'paidAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error in confirmPaymentAndTransfer: $e');
      rethrow;
    }
  }

  Stream<List<JobBid>> getJobBidsStream(String jobId) {
    return _firestore
        .collection('jobs')
        .doc(jobId)
        .collection('bids')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return JobBid(
          id: doc.id,
          jobId: jobId,
          workerUserId: data['workerUserId'] ?? '',
          workerName: data['workerName'] ?? '',
          currentPrice: (data['currentPrice'] as num?)?.toDouble() ?? 0.0,
          status: BidStatus.values.firstWhere((e) => e.name == data['status'],
              orElse: () => BidStatus.pending),
          lastProposedByUserId: data['lastProposedByUserId'] ?? '',
          createdAt:
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();
    });
  }

  Future<void> submitBid({
    required String jobId,
    required String workerUserId,
    required String workerName,
    required double price,
  }) async {
    final batch = _firestore.batch();
    // Using workerUserId as doc ID limits 1 bid per worker per job, which is correct
    final bidRef = _firestore
        .collection('jobs')
        .doc(jobId)
        .collection('bids')
        .doc(workerUserId);

    batch.set(bidRef, {
      'workerUserId': workerUserId,
      'workerName': workerName,
      'currentPrice': price,
      'status': BidStatus.pending.name,
      'lastProposedByUserId': workerUserId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> updateBidPrice(
      String jobId, String bidId, double newPrice, String authorId) async {
    await _firestore
        .collection('jobs')
        .doc(jobId)
        .collection('bids')
        .doc(bidId)
        .update({
      'currentPrice': newPrice,
      'status': BidStatus.counterOffered.name,
      'lastProposedByUserId': authorId,
    });
  }

  Future<void> acceptBid(
      String jobId, String bidId, String workerId, double finalPrice) async {
    final batch = _firestore.batch();

    final bidRef =
        _firestore.collection('jobs').doc(jobId).collection('bids').doc(bidId);
    batch.update(bidRef, {
      'status': BidStatus.accepted.name,
      'currentPrice': finalPrice,
    });

    final jobRef = _firestore.collection('jobs').doc(jobId);
    batch.update(jobRef, {
      'status': JobStatus.accepted.toString(),
      'assignedUserId': workerId,
      'price': finalPrice,
      'acceptedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  void seedMockJobs() {
    // Deprecated: No longer using mock data in JobProvider
  }
}
