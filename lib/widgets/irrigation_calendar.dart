import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/auth_provider.dart';
import '../providers/well_provider.dart';
import '../models/types.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';

class IrrigationCalendar extends StatefulWidget {
  const IrrigationCalendar({super.key});

  @override
  State<IrrigationCalendar> createState() => _IrrigationCalendarState();
}

class _IrrigationCalendarState extends State<IrrigationCalendar> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();

  // Colors for different land plots
  static const List<Color> plotColors = [
    Color(0xFF2E7D32), // أخضر غامق
    Color(0xFF1565C0), // أزرق
    Color(0xFFE65100), // برتقالي
    Color(0xFF6A1B9A), // بنفسجي
    Color(0xFFC62828), // أحمر
    Color(0xFF00838F), // تركواز
  ];

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('land_plots')
          .where('ownerId', isEqualTo: user?.id)
          .snapshots(),
      builder: (context, plotSnapshot) {
        final plotDocs = plotSnapshot.data?.docs ?? [];

        return Column(
          children: [
            _buildCalendarSection(plotDocs),
            const SizedBox(height: 12),
            Expanded(
              child: _buildSlotsList(plotDocs),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCalendarSection(List<QueryDocumentSnapshot> plotDocs) {
    final wellProvider = context.watch<WellProvider>();
    final wells = wellProvider.wells;
    final well = wells.isNotEmpty ? wells.first : null;
    final auth = context.read<AuthProvider>();
    final userHash = auth.user?.id.hashCode.abs() ?? 0;

    return NabaCard(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: TableCalendar(
        firstDay: DateTime.utc(2024, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        rowHeight: 42,
        daysOfWeekHeight: 28,
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        calendarStyle: const CalendarStyle(
          selectedDecoration: BoxDecoration(
            color: NabaTheme.primary,
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: NabaTheme.accent,
            shape: BoxShape.circle,
          ),
          markersMaxCount: 3,
        ),
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        eventLoader: (day) {
          if (well == null) return [];
          final freq = well.irrigationFrequencyDays > 0 ? well.irrigationFrequencyDays : 1;
          final diff = day.difference(DateTime.utc(2024, 1, 1)).inDays;

          List<String> events = [];

          if (plotDocs.isEmpty) {
            // No plots - use default behavior
            final dayOffset = userHash % freq;
            if (diff % freq == dayOffset) events.add('default');
          } else {
            // Each plot gets its own irrigation offset
            for (int i = 0; i < plotDocs.length; i++) {
              final plotHash = (userHash + i * 7) % freq;
              if (diff % freq == plotHash) {
                final data = plotDocs[i].data() as Map<String, dynamic>;
                events.add(data['name'] ?? 'قطعة ${i + 1}');
              }
            }
          }
          return events;
        },
        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, date, focusedDay) {
            if (well == null) return null;
            final freq = well.irrigationFrequencyDays > 0 ? well.irrigationFrequencyDays : 1;
            final diff = date.difference(DateTime.utc(2024, 1, 1)).inDays;

            Color? circleColor;

            if (plotDocs.isEmpty) {
              final dayOffset = userHash % freq;
              if (diff % freq == dayOffset) {
                circleColor = NabaTheme.primary;
              }
            } else {
              for (int i = 0; i < plotDocs.length; i++) {
                final plotHash = (userHash + i * 7) % freq;
                if (diff % freq == plotHash) {
                  circleColor = plotColors[i % plotColors.length];
                  break; // Use first matching plot color
                }
              }
            }

            if (circleColor == null) return null;

            return Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: circleColor.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(color: circleColor, width: 2),
              ),
              child: Center(
                child: Text(
                  '${date.day}',
                  style: TextStyle(
                    color: circleColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            );
          },
          markerBuilder: (context, date, events) {
            if (events.isEmpty) return null;

            return Positioned(
              bottom: 1,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: events.asMap().entries.map((entry) {
                  Color dotColor;

                  if (plotDocs.isEmpty) {
                    dotColor = NabaTheme.primary;
                  } else {
                    final plotName = entry.value as String;
                    int plotIndex = 0;
                    for (int i = 0; i < plotDocs.length; i++) {
                      final data = plotDocs[i].data() as Map<String, dynamic>;
                      if ((data['name'] ?? 'قطعة ${i + 1}') == plotName) {
                        plotIndex = i;
                        break;
                      }
                    }
                    dotColor = plotColors[plotIndex % plotColors.length];
                  }

                  return Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dotColor,
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSlotsList(List<QueryDocumentSnapshot> plotDocs) {
    final wellProvider = context.watch<WellProvider>();
    final wells = wellProvider.myWells;
    if (wells.isEmpty) return const SizedBox();
    final well = wells.first;

    final auth = context.read<AuthProvider>();
    final userHash = auth.user?.id.hashCode.abs() ?? 0;
    final freq = well.irrigationFrequencyDays > 0 ? well.irrigationFrequencyDays : 1;
    final diff = _selectedDay!.difference(DateTime.utc(2024, 1, 1)).inDays;

    // Find which plots have irrigation on this day
    List<Map<String, dynamic>> irrigatingPlots = [];

    if (plotDocs.isEmpty) {
      final dayOffset = userHash % freq;
      if (diff % freq == dayOffset) {
        irrigatingPlots.add({'name': 'أرضك', 'colorIndex': 0});
      }
    } else {
      for (int i = 0; i < plotDocs.length; i++) {
        final plotHash = (userHash + i * 7) % freq;
        if (diff % freq == plotHash) {
          final data = plotDocs[i].data() as Map<String, dynamic>;
          irrigatingPlots.add({
            'name': data['name'] ?? 'قطعة ${i + 1}',
            'area': data['area'] ?? 0,
            'colorIndex': i,
          });
        }
      }
    }

    if (irrigatingPlots.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy_rounded, size: 64, color: Colors.grey.withOpacity(0.3)),
            const SizedBox(height: 16),
            const Text('لا توجد مواعيد ري في هذا اليوم', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: irrigatingPlots.length,
      itemBuilder: (context, index) =>
          _buildTimelineSlot(context, index, well, irrigatingPlots[index]),
    );
  }

  Widget _buildTimelineSlot(
      BuildContext context, int index, Well well, Map<String, dynamic> plotInfo) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;
    final colorIndex = plotInfo['colorIndex'] as int;
    final plotColor = plotColors[colorIndex % plotColors.length];
    final plotName = plotInfo['name'] as String;

    final userHash = user?.id.hashCode.abs() ?? 0;
    final hours = well.hoursPerPerson.toInt();
    final startHourOffset = (userHash + colorIndex * 3) % (16 - (hours > 0 ? hours : 1));
    final timePrefix = 6 + startHourOffset;

    final bool isPast = timePrefix < DateTime.now().hour &&
        isSameDay(_selectedDay, DateTime.now());
    final bool isCurrent = timePrefix == DateTime.now().hour &&
        isSameDay(_selectedDay, DateTime.now());

    return IntrinsicHeight(
      child: Row(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline Indicator
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: isPast ? Colors.grey : plotColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      if (isCurrent)
                        BoxShadow(
                          color: plotColor.withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.grey.withOpacity(0.2),
                  ),
                ),
              ],
            ),
          ),
          // Content Card  
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: NabaCard(
                padding: const EdgeInsets.all(16),
                onTap: () {},
                border: Border.all(color: plotColor.withOpacity(0.3), width: 1.5),
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (isCurrent)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('مباشر الآن',
                                      style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
                                ),
                              Text(
                                plotName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: plotColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${well.wellName} - ري ${user?.fullName ?? "أنت"}',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _buildMiniBadge(
                                  '${well.hoursPerPerson} ساعة', Icons.access_time_rounded),
                              const SizedBox(width: 8),
                              _buildMiniBadge(plotName, Icons.landscape_rounded,
                                  color: plotColor),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      children: [
                        Text(
                          '${timePrefix.toString().padLeft(2, '0')}:00',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        Text(
                          timePrefix < 12 ? 'صباحاً' : 'مساءً',
                          style:
                              const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBadge(String text, IconData icon, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (color ?? Colors.grey).withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: (color ?? Colors.grey).withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text,
              style: TextStyle(
                  fontSize: 11, color: color ?? Colors.grey.shade700)),
          const SizedBox(width: 6),
          Icon(icon, size: 14, color: color ?? Colors.grey),
        ],
      ),
    );
  }
}
