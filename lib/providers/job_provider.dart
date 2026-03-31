import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/types.dart';

class JobProvider with ChangeNotifier {
  List<Job> _jobs = [];
  bool _isLoading = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Job> get jobs => _jobs;
  bool get isLoading => _isLoading;

  JobProvider() {
    _listenToJobs();
  }

  Future<void> fetchJobs() async {
    // Since we are using a listener, this is just to satisfy RefreshIndicator
    // or to force a manual refresh if the listener misses something.
    notifyListeners();
  }

  void _listenToJobs() {
    // For the marketplace, we listen to all jobs globally
    _isLoading = true;
    notifyListeners();

    _firestore
        .collection('jobs')
        .orderBy('startTime', descending: true)
        .snapshots()
        .listen((snapshot) {
      _jobs = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Job(
          id: doc.id,
          requesterUserId: data['requesterUserId'] ?? '',
          assignedUserId: data['assignedUserId'],
          type: data['type'] ?? 'worker',
          serviceType: data['serviceType'] ?? '',
          location: data['location'] != null 
              ? Map<String, double>.from(data['location']) 
              : {'lat': 0.0, 'lng': 0.0},
          startTime: (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
          endTime: (data['endTime'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(hours: 1)),
          status: JobStatus.values.firstWhere(
              (e) => e.toString() == data['status'],
              orElse: () => JobStatus.requested),
          price: data['price'] != null ? (data['price'] as num).toDouble() : null,
          notes: data['notes'] ?? '',
          address: data['address'],
          workerRating: data['workerRating'] != null ? (data['workerRating'] as num).toDouble() : null,
        );
      }).toList();
      debugPrint('JOB_PROVIDER: Received ${_jobs.length} jobs from Firestore');
      _isLoading = false;
      notifyListeners();
    }, onError: (error) {
      debugPrint('JOB_PROVIDER: Firestore Error: $error');
      _isLoading = false;
      notifyListeners();
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
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error adding job: $e');
      rethrow;
    }
  }

  Future<void> updateJobStatus(String jobId, JobStatus status,
      {String? workerId}) async {
    try {
      final updates = <String, dynamic>{
        'status': status.toString(),
      };

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
        final userDoc = await _firestore.collection('users').doc(workerId).get();
        if (userDoc.exists) {
          final extraData = Map<String, dynamic>.from(userDoc.data()?['extraData'] ?? {});
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

  void seedMockJobs() {
    // Deprecated: No longer using mock data in JobProvider
  }
}
