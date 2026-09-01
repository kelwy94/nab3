import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:universal_html/html.dart' as html;
import 'package:uuid/uuid.dart';

import '../models/types.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';
import '../widgets/audio_player_widget.dart';
import '../widgets/naba_widgets.dart';

class ConsultationRequestScreen extends StatefulWidget {
  final String engineerId;
  final Map<String, dynamic> engineerData;

  const ConsultationRequestScreen({
    super.key,
    required this.engineerId,
    required this.engineerData,
  });

  @override
  State<ConsultationRequestScreen> createState() =>
      _ConsultationRequestScreenState();
}

class _ConsultationRequestScreenState extends State<ConsultationRequestScreen> {
  final _problemController = TextEditingController();
  final _priceController = TextEditingController();
  DateTime? _selectedDate;
  bool _isLoading = false;
  double _uploadProgress = 0.0;
  String _uploadStatus = '';

  // Audio recording & playback
  late final AudioRecorder _audioRecorder;
  late final AudioPlayer _audioPlayer;
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _recordedFilePath;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _audioPlayer = AudioPlayer();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
  }

  @override
  void dispose() {
    _problemController.dispose();
    _priceController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        if (kIsWeb) {
          // Web browsers record in opus/webm — don't force AAC
          const webConfig = RecordConfig(
            encoder: AudioEncoder.opus,
            bitRate: 32000,
            sampleRate: 22050,
          );
          await _audioRecorder.start(webConfig, path: '');
        } else {
          const nativeConfig = RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 32000,
            sampleRate: 22050,
          );
          final dir = await getApplicationDocumentsDirectory();
          final path = '${dir.path}/audio_${const Uuid().v4()}.m4a';
          await _audioRecorder.start(nativeConfig, path: path);
        }
        setState(() => _isRecording = true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('لم يتم منح إذن التسجيل الصوتي'),
                backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ في التسجيل: $e')));
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _recordedFilePath = path;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  Future<void> _deleteRecording() async {
    await _audioPlayer.stop();
    setState(() => _recordedFilePath = null);
  }

  Future<void> _togglePlayPause() async {
    if (_recordedFilePath == null) return;
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      if (kIsWeb) {
        await _audioPlayer.play(UrlSource(_recordedFilePath!));
      } else {
        await _audioPlayer.play(DeviceFileSource(_recordedFilePath!));
      }
    }
  }

  Future<String?> _uploadVoiceNote() async {
    if (_recordedFilePath == null) return null;
    try {
      // Use correct extension and MIME type per platform
      final String ext = kIsWeb ? 'webm' : 'm4a';
      final String mime = kIsWeb ? 'audio/webm' : 'audio/m4a';

      final ref = FirebaseStorage.instance
          .ref()
          .child('voice_notes')
          .child('${const Uuid().v4()}.$ext');

      UploadTask uploadTask;

      if (kIsWeb) {
        // Fetch the blob URL produced by the recorder
        final req = await html.HttpRequest.request(
          _recordedFilePath!,
          responseType: 'arraybuffer',
        );
        final bytes = (req.response as ByteBuffer).asUint8List();
        debugPrint('Audio blob size: ${bytes.length} bytes');

        if (bytes.isEmpty) {
          throw Exception('الملف الصوتي فارغ');
        }

        uploadTask = ref.putData(bytes, SettableMetadata(contentType: mime));
      } else {
        final file = File(_recordedFilePath!);
        uploadTask = ref.putFile(file, SettableMetadata(contentType: mime));
      }

      // Listen to upload progress
      uploadTask.snapshotEvents.listen((event) {
        if (mounted && event.totalBytes > 0) {
          final progress = event.bytesTransferred / event.totalBytes;
          setState(() {
            _uploadProgress = progress;
            _uploadStatus = 'جاري رفع الصوت... ${(progress * 100).toInt()}%';
          });
        }
      });

      await uploadTask;
      setState(() => _uploadStatus = 'تم رفع الصوت بنجاح ✓');
      final downloadUrl = await ref.getDownloadURL();
      debugPrint('Audio uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading audio: $e');
      if (mounted) {
        setState(() => _uploadStatus = 'فشل رفع الملف الصوتي!');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('فشل رفع الملف الصوتي: $e'),
              backgroundColor: Colors.red),
        );
      }
      return null;
    }
  }

  Future<void> _startRequest(String farmerName) async {
    if (_problemController.text.trim().isEmpty && _recordedFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('برجاء كتابة تفاصيل المشكلة أو تسجيل رسالة صوتية')));
      return;
    }

    setState(() {
      _isLoading = true;
      _uploadProgress = 0.0;
      _uploadStatus = _recordedFilePath != null
          ? 'جاري تجهيز الملف الصوتي...'
          : 'جاري الإرسال...';
    });
    try {
      final farmerId =
          Provider.of<AuthProvider>(context, listen: false).user!.id;
      final docRef =
          FirebaseFirestore.instance.collection('consultations').doc();

      String? audioUrl;
      if (_recordedFilePath != null) {
        setState(() => _uploadStatus = 'جاري رفع الصوت...');
        audioUrl = await _uploadVoiceNote();
        // If audio upload failed, stop the request
        if (audioUrl == null) {
          setState(() {
            _isLoading = false;
            _uploadStatus = 'فشل الرفع — حاول مرة أخرى';
          });
          return;
        }
      }

      setState(() => _uploadStatus = 'جاري حفظ الطلب...');

      await docRef.set({
        'id': docRef.id,
        'type': 'remote',
        'farmerUserId': farmerId,
        'farmerName': farmerName,
        'engineerUserId': widget.engineerId,
        'engineerName': widget.engineerData['fullName'] ?? 'مهندس',
        'serviceType': widget.engineerData['extraData']?['specialization'] ??
            'استشارة عامة',
        'problemDescription': _problemController.text.trim(),
        'audioNoteUrl': audioUrl,
        'status': ConsultationStatus.pendingEngineerApproval.name,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _problemController.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تم إرسال الطلب بنجاح'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _respondToEngineer(
      String requestId, bool accept, ConsultationStatus currentStatus) async {
    setState(() => _isLoading = true);
    try {
      if (currentStatus == ConsultationStatus.pendingPriceApproval) {
        if (accept) {
          // Farmer accepts price and date — copy the proposed date as the final agreed date
          final consultDoc = await FirebaseFirestore.instance
              .collection('consultations')
              .doc(requestId)
              .get();
          final proposedDate = consultDoc.data()?['proposedDate'];
          await FirebaseFirestore.instance
              .collection('consultations')
              .doc(requestId)
              .update({
            'status': ConsultationStatus.confirmed.name,
            'finalAgreedDate': proposedDate ?? FieldValue.serverTimestamp(),
          });
        } else {
          // Farmer wants to negotiate time?
          if (_selectedDate == null) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('برجاء اختيار تاريخ جديد لتقديمه للمهندس')));
            setState(() => _isLoading = false);
            return;
          }
          await FirebaseFirestore.instance
              .collection('consultations')
              .doc(requestId)
              .update({
            'status': ConsultationStatus.negotiatingTime.name,
            'farmerProposedDate': Timestamp.fromDate(_selectedDate!),
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<AuthProvider>(context).user;
    if (currentUser == null) return const Scaffold();

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: NabaAppBar(
        title: 'تفاوض مع ${widget.engineerData['fullName'] ?? 'مهندس'}',
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('consultations')
              .where('farmerUserId', isEqualTo: currentUser.id)
              .where('engineerUserId', isEqualTo: widget.engineerId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('خطأ: ${snapshot.error}'));
            }

            final docs = snapshot.data?.docs.toList() ?? [];
            docs.sort((a, b) {
              final aMap = a.data() as Map<String, dynamic>;
              final bMap = b.data() as Map<String, dynamic>;
              final aTime = aMap['createdAt'] as Timestamp?;
              final bTime = bMap['createdAt'] as Timestamp?;
              if (aTime == null || bTime == null) return 0;
              return bTime.compareTo(aTime);
            });
            if (docs.isEmpty || _isRequestClosed(docs.first)) {
              return _buildNewRequestForm(currentUser.fullName);
            }

            final docInfo = docs.first.data() as Map<String, dynamic>;
            final statusStr = docInfo['status'] as String;
            final status = ConsultationStatus.values.firstWhere(
                (e) => e.name == statusStr,
                orElse: () => ConsultationStatus.pendingEngineerApproval);

            return _buildActiveNegotiation(docInfo, status, docs.first.id);
          },
        ),
      ),
    );
  }

  bool _isRequestClosed(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return true;
    final s = data['status'];
    return s == ConsultationStatus.completed.name ||
        s == ConsultationStatus.rated.name ||
        s == ConsultationStatus.rejected.name;
  }

  Widget _buildNewRequestForm(String farmerName) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: NabaTheme.primary.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.tips_and_updates_rounded,
                    color: NabaTheme.primary, size: 32),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'اشرح مشكلتك بالتفصيل ليقوم المهندس بتقدير سعر ووقت الزيارة المناسب.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('تفاصيل المشكلة',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          TextField(
            controller: _problemController,
            maxLines: 5,
            decoration: InputDecoration(
              hintText:
                  'مثلاً: يوجد اصفرار في أوراق الطماطم العلوية وانتشار لذبابة بيضاء...',
              filled: true,
              fillColor: Colors.white,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          if (_recordedFilePath != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                        _isPlaying
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_fill_rounded,
                        color: Colors.blue,
                        size: 32),
                    onPressed: _togglePlayPause,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                      child: Text('معاينة التسجيل الصوتي',
                          style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold))),
                  IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: _deleteRecording),
                ],
              ),
            )
          else ...[
            Center(
              child: InkWell(
                onTap: _isRecording ? _stopRecording : _startRecording,
                borderRadius: BorderRadius.circular(40),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: _isRecording
                        ? Colors.red.shade50
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                        color:
                            _isRecording ? Colors.red : Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                          _isRecording
                              ? Icons.stop_circle_rounded
                              : Icons.mic_rounded,
                          color: _isRecording ? Colors.red : NabaTheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        _isRecording
                            ? 'إيقاف التسجيل'
                            : 'أو سجل رسالة صوتية (اضغط هنا)',
                        style: TextStyle(
                            color: _isRecording
                                ? Colors.red
                                : Colors.grey.shade700,
                            fontWeight: FontWeight.bold),
                      )
                    ],
                  ),
                ),
              ),
            )
          ],
          const SizedBox(height: 32),
          if (_isLoading) ...[
            // Upload progress UI
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: NabaTheme.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: NabaTheme.primary.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          value: _uploadProgress > 0 ? _uploadProgress : null,
                          strokeWidth: 2.5,
                          color: NabaTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          _uploadStatus,
                          style: TextStyle(
                            color: NabaTheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_uploadProgress > 0) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _uploadProgress,
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade200,
                        color: NabaTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${(_uploadProgress * 100).toInt()}%',
                      style: TextStyle(
                        color: NabaTheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ] else
            NabaButton(
              text: 'إرسال طلب الاستشارة',
              onPressed: () => _startRequest(farmerName),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveNegotiation(
      Map<String, dynamic> doc, ConsultationStatus status, String requestId) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Problem bubble
          _buildChatBubble(
            sender: 'أنت',
            text: doc['problemDescription'] ?? '',
            audioUrl: doc['audioNoteUrl'],
            isMe: true,
          ),

          if (status == ConsultationStatus.pendingEngineerApproval)
            _buildStatusCard('جاري انتظار رد المهندس وتقييم المشكلة...',
                Icons.access_time_rounded, Colors.orange),

          if (status == ConsultationStatus.pendingPriceApproval ||
              status == ConsultationStatus.negotiatingTime ||
              status == ConsultationStatus.confirmed) ...[
            // Engineer quote bubble
            _buildChatBubble(
              sender: doc['engineerName'] ?? 'المهندس',
              text:
                  'لقد قمت بتقدير التكلفة والموعد المناسب:\n\nالسعر: ${doc['agreedPrice']} ج.م\nالموعد المقترح: ${_formatDate(doc['proposedDate'])}',
              isMe: false,
              color: Colors.blue.shade50,
            ),

            if (status == ConsultationStatus.pendingPriceApproval)
              _buildFarmerActionBox(requestId, doc),

            if (status == ConsultationStatus.negotiatingTime) ...[
              _buildChatBubble(
                sender: 'أنت',
                text:
                    'الرجاء تعديل الموعد ليكون: ${_formatDate(doc['farmerProposedDate'])}',
                isMe: true,
                color: NabaTheme.primary.withOpacity(0.1),
              ),
              _buildStatusCard(
                  'جاري انتظار موافقة المهندس على الموعد الجديد...',
                  Icons.access_time_rounded,
                  Colors.orange),
            ],

            if (status == ConsultationStatus.confirmed)
              _buildStatusCard('تم تأكيد الزيارة! سيتواصل معك المهندس قريباً.',
                  Icons.check_circle_rounded, Colors.green),
          ],
        ],
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
            ]
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

  Widget _buildFarmerActionBox(String requestId, Map<String, dynamic> doc) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('ردك على العرض:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: NabaTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12)),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('موافق (تأكيد الزيارة)'),
            onPressed: () => _respondToEngineer(
                requestId, true, ConsultationStatus.pendingPriceApproval),
          ),
          const SizedBox(height: 12),
          const Center(child: Text('أو', style: TextStyle(color: Colors.grey))),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12)),
            icon: const Icon(Icons.calendar_month_rounded),
            label: Text(_selectedDate == null
                ? 'اقتراح موعد آخر'
                : 'الموعد: ${_formatDate(Timestamp.fromDate(_selectedDate!))} (اضغط للتغيير)'),
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 1)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 60)),
              );
              if (d != null) {
                setState(() => _selectedDate = d);
              }
            },
          ),
          if (_selectedDate != null) ...[
            const SizedBox(height: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white),
              onPressed: () => _respondToEngineer(
                  requestId, false, ConsultationStatus.pendingPriceApproval),
              child: const Text('إرسال طلب تعديل الموعد'),
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
