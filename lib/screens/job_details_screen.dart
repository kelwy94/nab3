import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/types.dart';
import '../providers/auth_provider.dart';
import '../providers/job_provider.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';
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
            _buildActionButton(context, isRequester, isWorker),
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
    }
    if (status == JobStatus.inProgress) {
      label = 'جاري التنفيذ';
      color = NabaTheme.primary;
    }
    if (status == JobStatus.completed) {
      label = 'انتهى العمل';
      color = Colors.green;
    }
    if (status == JobStatus.paid) {
      label = 'تم الدفع والإنهاء';
      color = Colors.teal;
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
          _infoRow(Icons.location_on_outlined, 'موقع / عنوان العمل',
              widget.job.address?.isNotEmpty == true ? widget.job.address! : 'لم يتم تحديد عنوان كتابي'),
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
      BuildContext context, bool isRequester, bool isWorker) {
    final status = widget.job.status;

    // Worker specific actions
    if (isWorker) {
      if (status == JobStatus.accepted) {
        return NabaButton(
          text: 'بدأ عملية الري الآن',
          onPressed: () => _updateStatus(context, JobStatus.inProgress),
        );
      } else if (status == JobStatus.inProgress) {
        return NabaButton(
          text: 'إتمام عملية الري وتأكيد الإنهاء',
          onPressed: () => _updateStatus(context, JobStatus.completed),
        );
      } else if (status == JobStatus.completed) {
        return const NabaCard(
          padding: EdgeInsets.all(20),
          child: Center(
            child: Text('بانتظار المزارع لتأكيد الدفع والاستلام',
                style: TextStyle(
                    color: Colors.orange, fontWeight: FontWeight.bold)),
          ),
        );
      }
    }

    // Farmer specific actions
    if (isRequester) {
      if (status == JobStatus.completed) {
        return NabaButton(
          text: 'دفع المبلغ وتأكيد الاستلام',
          onPressed: () => _updateStatus(context, JobStatus.paid),
        );
      } else if (status == JobStatus.paid &&
          widget.job.assignedUserId != null) {
        return NabaButton(
          text: 'تقييم العامل',
          onPressed: () => _showReviewDialog(context),
        );
      } else if (status == JobStatus.reviewed) {
        return const NabaCard(
          padding: EdgeInsets.all(20),
          child: Center(
            child: Text('شكراً لتقييمك! تم إغلاق الطلب.',
                style: TextStyle(
                    color: Colors.green, fontWeight: FontWeight.bold)),
          ),
        );
      } else if (status == JobStatus.requested) {
        return const NabaCard(
          padding: EdgeInsets.all(20),
          child: Center(
            child: Text('طلبك بانتظار قبول أحد العمال المتاحين',
                style: TextStyle(color: Colors.grey)),
          ),
        );
      } else if (status == JobStatus.accepted ||
          status == JobStatus.inProgress) {
        return const NabaCard(
          padding: EdgeInsets.all(20),
          child: Center(
            child: Text('العمل قيد التنفيذ من قبل العامل المناوب',
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
        if (nextStatus == JobStatus.accepted)
          msg = 'مبروك! تم قبول الطلب بنجاح.';
        if (nextStatus == JobStatus.completed)
          msg = 'تم إنهاء العمل بنجاح. بانتظار المزارع للدفع.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: NabaTheme.primary,
          ),
        );
        
        if (nextStatus == JobStatus.paid && widget.job.assignedUserId != null) {
          _showReviewDialog(context);
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
