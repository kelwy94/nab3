import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/types.dart';
import '../providers/auth_provider.dart';
import '../providers/job_provider.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';
import '../widgets/payment_proof_dialog.dart';
import 'dart:ui' as ui;

class JobDetailsScreen extends StatefulWidget {
  final Job job;

  const JobDetailsScreen({super.key, required this.job});

  @override
  State<JobDetailsScreen> createState() => _JobDetailsScreenState();
}

class _JobDetailsScreenState extends State<JobDetailsScreen> {
  User? requester;
  User? worker;
  bool isLoadingData = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoadingData = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    // Always load requester info
    requester = await auth.fetchUser(widget.job.requesterUserId);

    // Load worker info if assigned
    if (widget.job.assignedUserId != null) {
      worker = await auth.fetchUser(widget.job.assignedUserId!);
    }

    if (mounted) setState(() => isLoadingData = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final currentUser = auth.user;
    final isRequester = currentUser?.id == widget.job.requesterUserId;
    final isWorker = currentUser?.id == widget.job.assignedUserId;
    final status = widget.job.status;

    return Scaffold(
      backgroundColor: NabaTheme.background,
      appBar: const NabaAppBar(title: 'تفاصيل الطلب'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildStepper(status),
            const SizedBox(height: 32),
            _buildStatusBadge(status),
            const SizedBox(height: 16),
            _buildInfoCard(),
            const SizedBox(height: 24),

            // If I am the worker, show requester (Farmer) info
            if (isWorker && requester != null) ...[
              const Text('بيانات المزارع',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildUserCard(requester!),
              const SizedBox(height: 24),
            ],

            // If I am the requester (Farmer), show worker info if assigned
            if (isRequester && worker != null) ...[
              const Text('بيانات العامل المناوب',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildUserCard(worker!),
              const SizedBox(height: 24),
            ],

            const Text('ملاحظات الطلب',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            NabaCard(
              padding: const EdgeInsets.all(20),
              child: Text(
                widget.job.notes.isEmpty
                    ? 'لا توجد ملاحظات إضافية'
                    : widget.job.notes,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 15, height: 1.5),
              ),
            ),
            const SizedBox(height: 48),
            _buildActionButton(context, isRequester, isWorker, currentUser),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(JobStatus status) {
    String label = 'قيد الانتظار';
    Color color = Colors.orange;
    if (status == JobStatus.accepted) {
      label = 'تم القبول';
      color = Colors.blue;
    } else if (status == JobStatus.inProgress) {
      label = 'جاري التنفيذ';
      color = NabaTheme.primary;
    } else if (status == JobStatus.completed) {
      label = 'تم انتهاء المهمة';
      color = Colors.green;
    } else if (status == JobStatus.paid) {
      label = 'تم الدفع والإنهاء';
      color = Colors.teal;
    } else if (status == JobStatus.reviewed) {
      label = 'تم التقييم والإغلاق';
      color = Colors.purple;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildStepper(JobStatus currentStatus) {
    final stages = [
      {'status': JobStatus.requested, 'label': 'طلب'},
      {'status': JobStatus.accepted, 'label': 'قبول'},
      {'status': JobStatus.inProgress, 'label': 'تنفيذ'},
      {'status': JobStatus.completed, 'label': 'انتهاء'},
      {'status': JobStatus.paid, 'label': 'دفع'},
      {'status': JobStatus.reviewed, 'label': 'تقييم'},
    ];

    int currentIndex = stages.indexWhere((s) => s['status'] == currentStatus);
    if (currentIndex == -1) currentIndex = 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      textDirection: ui.TextDirection.rtl,
      children: List.generate(stages.length, (index) {
        final isCompleted = index <= currentIndex;
        final isLast = index == stages.length - 1;

        return Expanded(
          child: Row(
            children: [
              Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isCompleted ? NabaTheme.primary : Colors.grey.shade300,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCompleted ? NabaTheme.primary : Colors.grey.shade400,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: isCompleted
                          ? const Icon(Icons.check, color: Colors.white, size: 16)
                          : Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    stages[index]['label'] as String,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
                      color: isCompleted ? NabaTheme.textPrimary : Colors.grey,
                    ),
                  ),
                ],
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 24),
                    color: index < currentIndex ? NabaTheme.primary : Colors.grey.shade300,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildInfoCard() {
    final timeFormat = DateFormat('HH:mm');
    final duration =
        '${timeFormat.format(widget.job.startTime)} - ${timeFormat.format(widget.job.endTime)}';

    return NabaCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _infoRow(Icons.work_outline, 'نوع الخدمة', widget.job.serviceType),
          const Divider(height: 32),
          _infoRow(Icons.access_time, 'فترة العمل', duration),
          const Divider(height: 32),
          _infoRow(Icons.payments_outlined, 'السعر المتفق عليه',
              '${widget.job.price?.toStringAsFixed(0) ?? "---"} ج.م'),
          const Divider(height: 32),
          _infoRow(
              Icons.location_on_outlined,
              'موقع / عنوان العمل',
              widget.job.address?.isNotEmpty == true
                  ? widget.job.address!
                  : 'لم يتم تحديد عنوان كتابي'),
        ],
      ),
    );
  }

  Widget _buildUserCard(User user) {
    return NabaCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _infoRow(Icons.person_outline, 'الاسم', user.fullName),
          const Divider(height: 32),
          _infoRow(Icons.phone_android_outlined, 'رقم التواصل', user.phone),
          const Divider(height: 32),
          _infoRow(Icons.map_outlined, 'العنوان', user.address),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      textDirection: ui.TextDirection.rtl,
      children: [
        Icon(icon, color: NabaTheme.primary),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(label,
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
              Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
      BuildContext context, bool isRequester, bool isWorker, User? currentUser) {
    final status = widget.job.status;

    // Worker specific actions
    if (isWorker) {
      if (status == JobStatus.accepted) {
        return NabaButton(
          text: 'بدأ عملية العمل الآن',
          onPressed: () => _updateStatus(context, JobStatus.inProgress),
        );
      } else if (status == JobStatus.inProgress) {
        return NabaButton(
          text: 'إتمام المهمة وتأكيد الإنهاء',
          onPressed: () => _updateStatus(context, JobStatus.completed),
        );
      } else if (status == JobStatus.completed) {
        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                children: [
                  Icon(Icons.hourglass_top_rounded, color: Colors.orange.shade700, size: 32),
                  const SizedBox(height: 8),
                  const Text('تم إرسال طلب الدفع للمزارع. بانتظار التحويل.',
                      style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (currentUser != null)
              Text(
                'سيتم التحويل على: ${currentUser.paymentMethodLabel} (${currentUser.paymentDetails ?? "رقمك المسجل"})',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            const SizedBox(height: 16),
            // Report non-payment button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _reportNonPayment(context),
                icon: const Icon(Icons.report_problem_rounded, color: Colors.red),
                label: const Text('لم أستلم المبلغ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        );
      }
    }

    // Farmer specific actions
    if (isRequester) {
      if (status == JobStatus.completed) {
        return Column(
          children: [
            if (worker != null)
              NabaCard(
                color: Colors.blue.shade50,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('بيانات تحويل المبلغ لمقدم الخدمة',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      'الوسيلة: ${worker?.paymentMethodLabel}',
                      style: const TextStyle(color: Colors.blue),
                    ),
                    Text(
                      'الرقم: ${worker?.paymentDetails ?? worker?.phone}',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            NabaButton(
              text: 'تحويل المبلغ وإرسال الإثبات',
              onPressed: () => _showPaymentProofDialog(context),
            ),
          ],
        );
      } else if (status == JobStatus.paid &&
          widget.job.assignedUserId != null) {
        return NabaButton(
          text: 'تقييم الخدمة والجودة',
          onPressed: () => _showReviewDialog(context),
        );
      } else if (status == JobStatus.reviewed) {
        return const NabaCard(
          padding: EdgeInsets.all(20),
          child: Center(
            child: Text('تم التقييم بنجاح. شكراً لثقتكم في نبع!',
                style: TextStyle(
                    color: Colors.green, fontWeight: FontWeight.bold)),
          ),
        );
      } else if (status == JobStatus.requested) {
        return const NabaCard(
          padding: EdgeInsets.all(20),
          child: Center(
            child: Text('طلبك قيد الانتظار لموافقة مقدم الخدمة',
                style: TextStyle(color: Colors.grey)),
          ),
        );
      } else if (status == JobStatus.accepted ||
          status == JobStatus.inProgress) {
        return const NabaCard(
          padding: EdgeInsets.all(20),
          child: Center(
            child: Text('المهمة قيد التنفيذ حالياً',
                style: TextStyle(
                    color: NabaTheme.primary, fontWeight: FontWeight.bold)),
          ),
        );
      }
    }

    // If it's a general requested job and I'm a worker (able to accept)
    if (status == JobStatus.requested && !isRequester) {
      return NabaButton(
        text: 'قبول الطلب الآن',
        onPressed: () => _updateStatus(context, JobStatus.accepted),
      );
    }

    return const SizedBox.shrink();
  }

  Future<void> _updateStatus(BuildContext context, JobStatus nextStatus) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final jobProvider = Provider.of<JobProvider>(context, listen: false);

    try {
      String? workerId;
      if (nextStatus == JobStatus.accepted) {
        workerId = auth.user!.id;
      }

      await jobProvider.updateJobStatus(widget.job.id, nextStatus,
          workerId: workerId);

      if (context.mounted) {
        String msg = 'تم تحديث حالة الطلب بنجاح!';
        if (nextStatus == JobStatus.accepted) {
          msg = 'مبروك! تم قبول الطلب بنجاح.';
        }
        if (nextStatus == JobStatus.completed) {
          msg = 'تم إنهاء العمل بنجاح. بانتظار المزارع للدفع.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: NabaTheme.primary,
          ),
        );

        if (nextStatus == JobStatus.paid && widget.job.assignedUserId != null) {
          _showReviewDialog(context);
        } else if (nextStatus == JobStatus.accepted) {
          // Stay on screen after accepting
          setState(() {});
        } else {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء تحديث حالة الطلب.')),
        );
      }
    }
  }

  Future<void> _reportNonPayment(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تأكيد البلاغ', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'هل أنت متأكد أنك لم تستلم المبلغ؟\nسيتم إرسال بلاغ للإدارة للتواصل مع المزارع.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('تأكيد البلاغ'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance.collection('disputes').add({
        'jobId': widget.job.id,
        'type': 'non_payment',
        'reportedBy': widget.job.assignedUserId,
        'farmerId': widget.job.requesterUserId,
        'amount': widget.job.price,
        'serviceType': widget.job.serviceType,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('تم إرسال البلاغ للإدارة. سيتم التواصل مع المزارع.'),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _showPaymentProofDialog(BuildContext context) async {
    if (worker == null) return;

    // Get worker payment info — check both top-level fields and extraData
    String methodLabel = worker!.paymentMethodLabel;
    String paymentDetails = worker!.paymentDetails ?? worker!.phone;

    // Also try to fetch fresh data from Firestore for extraData
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.job.assignedUserId)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        final extra = data['extraData'] as Map<String, dynamic>?;
        if (extra != null && extra['paymentDetails'] != null) {
          paymentDetails = extra['paymentDetails'].toString();
        }
        if (data['paymentDetails'] != null && data['paymentDetails'].toString().isNotEmpty) {
          paymentDetails = data['paymentDetails'].toString();
        }
      }
    } catch (_) {}

    if (!context.mounted) return;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PaymentProofDialog(
        recipientName: worker!.fullName,
        paymentMethodLabel: methodLabel,
        paymentDetails: paymentDetails,
        amount: widget.job.price ?? 0,
        onSubmit: (senderNumber, screenshotBase64) async {
          final jobProvider = Provider.of<JobProvider>(context, listen: false);

          // Save payment proof to the job document
          await FirebaseFirestore.instance
              .collection('jobs')
              .doc(widget.job.id)
              .update({
            'paymentProof': {
              'senderNumber': senderNumber,
              'screenshotBase64': screenshotBase64,
              'submittedAt': FieldValue.serverTimestamp(),
            },
          });

          // Confirm payment and transfer
          await jobProvider.confirmPaymentAndTransfer(widget.job);

          // Add transaction to worker's wallet
          final workerId = widget.job.assignedUserId!;
          final amount = widget.job.price ?? 0.0;
          final auth = Provider.of<AuthProvider>(context, listen: false);
          final buyerName = auth.user?.fullName ?? 'المزارع';

          await FirebaseFirestore.instance.collection('transactions').add({
            'userId': workerId,
            'type': 'incoming',
            'amount': amount,
            'note': 'أجر عمل: ${widget.job.serviceType} من $buyerName',
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Update worker wallet balance
          final walletRef = FirebaseFirestore.instance.collection('wallets').doc(workerId);
          final walletDoc = await walletRef.get();
          if (walletDoc.exists) {
            final bal = ((walletDoc.data() ?? {})['balance'] ?? 0.0).toDouble();
            await walletRef.update({'balance': bal + amount});
          } else {
            await walletRef.set({'balance': amount, 'userId': workerId});
          }
        },
      ),
    );

    if (result == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تأكيد الدفع وإرسال الإثبات بنجاح!'),
          backgroundColor: Colors.green,
        ),
      );
      _showReviewDialog(context);
    }
  }

  void _showReviewDialog(BuildContext context) {
    if (widget.job.assignedUserId == null) return;

    int selectedStars = 5;
    final commentController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: NabaTheme.background,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('تقييم العامل',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starValue = 5 - index; // RTL logic
                      return IconButton(
                        icon: Icon(
                          starValue <= selectedStars
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                          size: 40,
                        ),
                        onPressed: () {
                          setSheetState(() => selectedStars = starValue);
                        },
                      );
                    }).reversed.toList(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      hintText: 'أضف تعليقاً على أداء العامل...',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              setSheetState(() => isSubmitting = true);
                              try {
                                await context
                                    .read<JobProvider>()
                                    .submitJobReview(
                                      widget.job.id,
                                      widget.job.assignedUserId!,
                                      selectedStars,
                                      commentController.text,
                                    );
                                if (bottomSheetContext.mounted) {
                                  Navigator.pop(bottomSheetContext);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('تم إرسال التقييم بنجاح!'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (bottomSheetContext.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('حدث خطأ أثناء الإرسال')),
                                  );
                                  setSheetState(() => isSubmitting = false);
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NabaTheme.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('إرسال التقييم',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18)),
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
