import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../models/types.dart';
import '../theme.dart';
import '../widgets/audio_player_widget.dart';
import '../widgets/naba_widgets.dart';

class EngineerConsultationDetailsScreen extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> requestData;
  final ConsultationStatus status;

  const EngineerConsultationDetailsScreen({
    super.key,
    required this.requestId,
    required this.requestData,
    required this.status,
  });

  @override
  State<EngineerConsultationDetailsScreen> createState() =>
      _EngineerConsultationDetailsScreenState();
}

class _EngineerConsultationDetailsScreenState
    extends State<EngineerConsultationDetailsScreen> {
  final _priceController = TextEditingController();
  DateTime? _selectedDate;
  bool _isLoading = false;

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _sendQuote() async {
    if (_priceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('برجاء إدخال سعر الاستشارة/الزيارة')));
      return;
    }
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('برجاء تحديد الموعد المقترح')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('consultations')
          .doc(widget.requestId)
          .update({
        'status': ConsultationStatus.pendingPriceApproval.name,
        'agreedPrice': double.tryParse(_priceController.text) ?? 0.0,
        'proposedDate': Timestamp.fromDate(_selectedDate!),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إرسال العرض للمزارع بنجاح')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _respondToFarmerDate(bool accept, DateTime newDate) async {
    setState(() => _isLoading = true);
    try {
      if (accept) {
        await FirebaseFirestore.instance
            .collection('consultations')
            .doc(widget.requestId)
            .update({
          'status': ConsultationStatus.confirmed.name,
          'proposedDate': Timestamp.fromDate(newDate),
          'finalAgreedDate': Timestamp.fromDate(newDate),
        });
      } else {
        if (_selectedDate == null) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('برجاء اقتراح موعد بديل')));
          setState(() => _isLoading = false);
          return;
        }
        await FirebaseFirestore.instance
            .collection('consultations')
            .doc(widget.requestId)
            .update({
          'status': ConsultationStatus.pendingPriceApproval
              .name, // send it back to farmer to approve date
          'proposedDate': Timestamp.fromDate(_selectedDate!),
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _completeVisit() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('consultations')
          .doc(widget.requestId)
          .update({
        'status': ConsultationStatus.completed.name,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: NabaAppBar(
          title: 'تفاصيل الاستشارة - ${widget.requestData['farmerName']}'),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('consultations')
              .doc(widget.requestId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text('الطلب غير موجود.'));
            }

            final data = snapshot.data!.data() as Map<String, dynamic>;
            final status = ConsultationStatus.values.firstWhere(
                (e) => e.name == data['status'],
                orElse: () => ConsultationStatus.pendingEngineerApproval);

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildChatBubble(
                  sender: data['farmerName'] ?? 'المزارع',
                  text: data['problemDescription'] ?? '',
                  audioUrl: data['audioNoteUrl'],
                  isMe: false,
                ),
                if (status == ConsultationStatus.pendingEngineerApproval)
                  _buildMakeOfferBox(data),
                if (status == ConsultationStatus.pendingPriceApproval ||
                    status == ConsultationStatus.negotiatingTime ||
                    status == ConsultationStatus.confirmed ||
                    status == ConsultationStatus.completed) ...[
                  _buildChatBubble(
                    sender: 'أنت',
                    text:
                        'قدمت عرض بقيمة ${data['agreedPrice']} ج.م، موعد: ${_formatDate(data['proposedDate'])}',
                    isMe: true,
                  ),
                ],
                if (status == ConsultationStatus.pendingPriceApproval)
                  _buildStatusCard(
                      'في انتظار موافقة المزارع أو تعديل الموعد...',
                      Icons.hourglass_top,
                      Colors.blue),
                if (status == ConsultationStatus.negotiatingTime) ...[
                  _buildChatBubble(
                    sender: data['farmerName'] ?? 'المزارع',
                    text:
                        'المزارع يطلب تعديل الموعد إلى: ${_formatDate(data['farmerProposedDate'])}',
                    isMe: false,
                    color: Colors.purple.shade50,
                  ),
                  _buildFarmerDateResponseBox(data['farmerProposedDate']),
                ],
                if (status == ConsultationStatus.confirmed) ...[
                  _buildStatusCard(
                      'اكتمل التفاوض! الزيارة مؤكدة يوم ${_formatDate(data['proposedDate'])}',
                      Icons.check_circle,
                      Colors.green),
                  const SizedBox(height: 24),
                  NabaButton(
                    text: _isLoading
                        ? 'جاري التنفيذ...'
                        : '✅ تم إنهاء المعاينة / الاستشارة بالكامل',
                    onPressed: _isLoading ? null : _completeVisit,
                  ),
                ],
                if (status == ConsultationStatus.completed ||
                    status == ConsultationStatus.rated)
                  _buildStatusCard('تم الانتهاء من الطلب بنجاح.',
                      Icons.done_all, Colors.teal),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildChatBubble(
      {required String sender,
      required String text,
      required bool isMe,
      String? audioUrl,
      Color? color}) {
    return Align(
      alignment: isMe ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color ??
              (isMe ? NabaTheme.primary.withOpacity(0.1) : Colors.white),
          borderRadius: BorderRadius.circular(16).copyWith(
            topLeft:
                isMe ? const Radius.circular(0) : const Radius.circular(16),
            topRight:
                !isMe ? const Radius.circular(0) : const Radius.circular(16),
          ),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sender,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.grey.shade600)),
            if (text.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(text, style: const TextStyle(fontSize: 16)),
            ],
            if (audioUrl != null && audioUrl.isNotEmpty) ...[
              const SizedBox(height: 8),
              AudioPlayerWidget(audioUrl: audioUrl),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(String msg, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
              child: Text(msg,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildMakeOfferBox(Map<String, dynamic> doc) {
    bool isVisit = doc['type'] == 'visit';
    List<dynamic> proposedDates = [];
    if (isVisit) {
      proposedDates = doc['proposedDates'] as List<dynamic>? ?? [];
    }

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NabaTheme.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(isVisit ? 'الرد على طلب الزيارة:' : 'الرد بتكلفة وموعد الزيارة:',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          if (isVisit) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الموقع: ${doc['visitLocation'] ?? ''}'),
                  Text('المساحة: ${doc['visitArea'] ?? ''}'),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: isVisit
                  ? 'تكلفة الزيارة الميدانية (ج.م)'
                  : 'السعر المقترح للاستشارة (ج.م)',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          if (isVisit && proposedDates.length == 3) ...[
            const Text('اختر أحد المواعيد التي اقترحها المزارع:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...proposedDates.map((d) {
              DateTime date = (d as Timestamp).toDate();
              bool isSelected = _selectedDate == date;
              return RadioListTile<DateTime>(
                title:
                    Text(_formatDate(d), style: const TextStyle(fontSize: 14)),
                value: date,
                groupValue: _selectedDate,
                activeColor: NabaTheme.primary,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) => setState(() => _selectedDate = val),
              );
            }),
          ] else ...[
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              icon: const Icon(Icons.calendar_month_rounded),
              label: Text(_selectedDate == null
                  ? 'حدد الموعد المقترح'
                  : 'الموعد: ${_formatDate(Timestamp.fromDate(_selectedDate!))}'),
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 1)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 60)),
                );
                if (d != null) {
                  final t = await showTimePicker(
                      context: context,
                      initialTime: const TimeOfDay(hour: 10, minute: 0));
                  if (t != null) {
                    setState(() => _selectedDate =
                        DateTime(d.year, d.month, d.day, t.hour, t.minute));
                  }
                }
              },
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: NabaTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12)),
            onPressed: _isLoading ? null : _sendQuote,
            child: Text(_isLoading ? 'جاري الإرسال...' : 'إرسال العرض للمزارع'),
          ),
        ],
      ),
    );
  }

  Widget _buildFarmerDateResponseBox(dynamic farmerProposedTimestamp) {
    if (farmerProposedTimestamp == null) return const SizedBox.shrink();
    DateTime farmerDate = (farmerProposedTimestamp as Timestamp).toDate();

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('رد المزارع:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, foregroundColor: Colors.white),
            icon: const Icon(Icons.check),
            label: const Text('موافق على موعد المزارع'),
            onPressed: () => _respondToFarmerDate(true, farmerDate),
          ),
          const SizedBox(height: 12),
          const Center(child: Text('أو', style: TextStyle(color: Colors.grey))),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.date_range),
            label: Text(_selectedDate == null
                ? 'اقتراح موعد ثالث جديد'
                : 'الموعد: ${_formatDate(Timestamp.fromDate(_selectedDate!))}'),
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: farmerDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 60)),
              );
              if (d != null) setState(() => _selectedDate = d);
            },
          ),
          if (_selectedDate != null) ...[
            const SizedBox(height: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white),
              onPressed: () => _respondToFarmerDate(false, farmerDate),
              child: const Text('إرسال هذا الموعد للمزارع'),
            ),
          ]
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'غير محدد';
    if (timestamp is Timestamp) {
      final d = timestamp.toDate();
      return DateFormat('yyyy/MM/dd - hh:mm a').format(d);
    }
    return '';
  }
}
