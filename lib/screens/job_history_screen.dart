import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/types.dart';
import '../providers/auth_provider.dart';
import '../providers/job_provider.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';
import 'job_details_screen.dart';

class JobHistoryScreen extends StatelessWidget {
  const JobHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final jobs = Provider.of<JobProvider>(context).jobs.where((j) =>
        j.requesterUserId == user?.id &&
        (j.status == JobStatus.paid || j.status == JobStatus.reviewed)).toList();

    return Scaffold(
      backgroundColor: NabaTheme.background,
      appBar: const NabaAppBar(title: 'سجل الطلبات السابقة'),
      body: jobs.isEmpty
          ? const Center(
              child: Text('لا توجد طلبات سابقة',
                  style: TextStyle(color: Colors.grey, fontSize: 18)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: jobs.length,
              itemBuilder: (context, index) {
                final job = jobs[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: NabaCard(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(
                          builder: (_) => JobDetailsScreen(job: job)));
                    },
                    child: Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        Icon(
                          job.type == 'worker' ? Icons.engineering_rounded : Icons.agriculture_rounded,
                          color: job.type == 'worker' ? Colors.blue.shade700 : Colors.orange.shade700,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(job.serviceType, style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('السعر: ${job.price?.toStringAsFixed(0) ?? "غير محدد"} ج.م',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            job.status == JobStatus.reviewed ? 'تم التقييم' : 'تم الدفع',
                            style: const TextStyle(color: Colors.teal, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
