import 'package:flutter/material.dart';
import '../widgets/naba_widgets.dart';
import '../models/types.dart';
import 'package:provider/provider.dart';
import '../providers/well_provider.dart';

class WellDetailsScreen extends StatelessWidget {
  final Well well;
  const WellDetailsScreen({super.key, required this.well});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const NabaAppBar(title: 'تفاصيل البئر'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            NabaCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: well.status == WellStatus.approved ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          well.status == WellStatus.approved ? 'نشط' : 'قيد المراجعة',
                          style: TextStyle(
                            color: well.status == WellStatus.approved ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(well.wellName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow('مساحة الري المشتركة', '${well.irrigatedAreaFeddan} فدان', Icons.layers_rounded),
                  _buildDetailRow('دورة الري', 'كل ${well.irrigationFrequencyDays} أيام', Icons.calendar_today_rounded),
                  _buildDetailRow('حصتك للري', '${well.hoursPerPerson} ساعات', Icons.access_time_rounded),
                  _buildDetailRow('عدد المشتركين الكلي', '${well.participantCount}', Icons.group_rounded),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('خيارات التعديل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildOptionCard(
              context,
              title: 'طلب تعديل بيانات',
              desc: 'قدم طلباً للإدارة لتعديل بيانات البئر (المساحة، ساعات الري، المشتركين)',
              icon: Icons.edit_document,
              color: Colors.purple,
              onTap: () => _showEditRequestDialog(context),
            ),
            const SizedBox(height: 12),
            _buildOptionCard(
              context,
              title: 'إضافة مشترك جديد',
              desc: 'أضف مزارعاً آخر للبئر ليتم إدراجه في دورة الري',
              icon: Icons.person_add_rounded,
              color: Colors.indigo,
              onTap: () => _showAddParticipantDialog(context),
            ),
            const SizedBox(height: 12),
            _buildOptionCard(
              context,
              title: 'تعديل المساحة',
              desc: 'قدم طلباً لتعديل مساحتك المروية المعتمدة',
              icon: Icons.map_outlined,
              color: Colors.orange,
              onTap: () => _showEditAreaDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Icon(icon, color: Colors.grey, size: 20),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildOptionCard(BuildContext context, {required String title, required String desc, required IconData icon, required Color color, required VoidCallback onTap}) {
    return NabaCard(
      onTap: onTap,
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(desc, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ],
            ),
          ),
          const Icon(Icons.arrow_back_ios, size: 14, color: Colors.grey),
        ],
      ),
    );
  }

  void _showAddParticipantDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة مشترك جديد', textAlign: TextAlign.right),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          textAlign: TextAlign.right,
          decoration: const InputDecoration(
            hintText: 'أدخل رقم هاتف المزارع (مثال: 01xxxxxxxxx)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                final success = await ctx.read<WellProvider>().inviteParticipantByPhone(well.id, controller.text.trim());
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(success ? 'تم إرسال طلب الانضمام بنجاح وهو الآن بانتظار الإدارة' : 'لم يتم العثور على مزارع بهذا الرقم أو تمت دعوته مسبقاً')),
                  );
                }
              }
            },
            child: const Text('إرسال الدعوة'),
          ),
        ],
      ),
    );
  }

  void _showEditAreaDialog(BuildContext context) {
    final controller = TextEditingController(text: well.irrigatedAreaFeddan.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل مساحة الري', textAlign: TextAlign.right),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.right,
          decoration: const InputDecoration(
            labelText: 'المساحة الجديدة (فدان)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text.trim());
              if (val != null && val != well.irrigatedAreaFeddan) {
                ctx.read<WellProvider>().requestWellEdit(well.id, {'irrigatedAreaFeddan': val});
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم إرسال طلب تعديل المساحة بنجاح للإدارة')),
                );
              } else {
                Navigator.pop(ctx);
              }
            },
            child: const Text('إرسال الطلب'),
          ),
        ],
      ),
    );
  }

  void _showEditRequestDialog(BuildContext context) {
    final nameController = TextEditingController(text: well.wellName);
    final areaController = TextEditingController(text: well.irrigatedAreaFeddan.toString());
    final depthController = TextEditingController(text: well.depthMeters.toString());
    final flowController = TextEditingController(text: well.flowRateM3PerHour?.toString() ?? '');
    final partsController = TextEditingController(text: well.participantCount.toString());
    final freqController = TextEditingController(text: well.irrigationFrequencyDays.toString());
    final hoursController = TextEditingController(text: well.hoursPerPerson.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('طلب تعديل بيانات البئر', textAlign: TextAlign.right),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, textAlign: TextAlign.right, decoration: const InputDecoration(labelText: 'اسم البئر')),
              TextField(controller: areaController, textAlign: TextAlign.right, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المساحة المروية (فدان)')),
              TextField(controller: depthController, textAlign: TextAlign.right, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'العمق (متر)')),
              TextField(controller: flowController, textAlign: TextAlign.right, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'معدل التدفق (متر مكعب/ساعة)')),
              TextField(controller: partsController, textAlign: TextAlign.right, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'عدد المشتركين (المبدئي)')),
              TextField(controller: freqController, textAlign: TextAlign.right, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'دورة الري (بالأيام)')),
              TextField(controller: hoursController, textAlign: TextAlign.right, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'ساعات الري (للفرد)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              final edits = <String, dynamic>{};
              
              if (nameController.text.trim() != well.wellName && nameController.text.trim().isNotEmpty) edits['wellName'] = nameController.text.trim();
              
              final area = double.tryParse(areaController.text.trim());
              if (area != null && area != well.irrigatedAreaFeddan) edits['irrigatedAreaFeddan'] = area;

              final depth = double.tryParse(depthController.text.trim());
              if (depth != null && depth != well.depthMeters) edits['depthMeters'] = depth;

              final flow = double.tryParse(flowController.text.trim());
              if (flow != null && flow != well.flowRateM3PerHour) edits['flowRateM3PerHour'] = flow;

              final parts = int.tryParse(partsController.text.trim());
              if (parts != null && parts != well.participantCount) edits['participantCount'] = parts;

              final freq = int.tryParse(freqController.text.trim());
              if (freq != null && freq != well.irrigationFrequencyDays) edits['irrigationFrequencyDays'] = freq;

              final hours = double.tryParse(hoursController.text.trim());
              if (hours != null && hours != well.hoursPerPerson) edits['hoursPerPerson'] = hours;

              if (edits.isNotEmpty) {
                ctx.read<WellProvider>().requestWellEdit(well.id, edits);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم إرسال طلبات التعديل للإدارة بنجاح وتقييمها')),
                );
              } else {
                Navigator.pop(ctx);
              }
            },
            child: const Text('إرسال الطلب'),
          ),
        ],
      ),
    );
  }
}
