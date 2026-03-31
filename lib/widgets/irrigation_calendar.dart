import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NabaTheme.background,
      appBar: NabaAppBar(
        title: 'جدول الري - نسخة مطوّرة',
        showBackButton: false,
        actions: [
          IconButton(
              icon: const Icon(Icons.notifications_none_rounded),
              onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          _buildCalendarSection(),
          const SizedBox(height: 12),
          Expanded(
            child: _buildSlotsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarSection() {
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
        rowHeight: 38,
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
          markersMaxCount: 1,
        ),
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        eventLoader: (day) {
          if (well == null) return [];
          final freq = well.irrigationFrequencyDays > 0 ? well.irrigationFrequencyDays : 1;
          final dayOffset = userHash % freq;
          final diff = day.difference(DateTime.utc(2024, 1, 1)).inDays;
          if (diff % freq == dayOffset) return ['irrigation'];
          return [];
        },
      ),
    );
  }

  Widget _buildSlotsList() {
    final wellProvider = context.watch<WellProvider>();
    final wells = wellProvider.myWells;
    if (wells.isEmpty) return const SizedBox();
    final well = wells.first;

    final auth = context.read<AuthProvider>();
    final userHash = auth.user?.id.hashCode.abs() ?? 0;
    final freq = well.irrigationFrequencyDays > 0 ? well.irrigationFrequencyDays : 1;
    final dayOffset = userHash % freq;
    final diff = _selectedDay!.difference(DateTime.utc(2024, 1, 1)).inDays;
    
    final isMyDay = (diff % freq == dayOffset);

    // Ensure no fake participants are shown:
    if (!isMyDay) {
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
      itemCount: 1, // Only my slot
      itemBuilder: (context, index) => _buildTimelineSlot(context, index, isMyDay, well),
    );
  }

  Widget _buildTimelineSlot(BuildContext context, int index, bool isMyDay, Well well) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;

    final userHash = user?.id.hashCode.abs() ?? 0;
    final hours = well.hoursPerPerson.toInt();
    
    // Calculate a pseudo-random start hour based on day and index so it looks dynamic
    final startHourOffset = userHash % (16 - (hours > 0 ? hours : 1));
    final timePrefix = 6 + startHourOffset; // Starts between 6 AM and 8 PM
    
    final String personName = user?.fullName ?? 'أنت';
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
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isPast ? Colors.grey : NabaTheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      if (isCurrent)
                        BoxShadow(
                          color: NabaTheme.primary.withOpacity(0.3),
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
                border: Border.all(
                        color: NabaTheme.primary.withOpacity(0.3), width: 1.5),
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
                                personName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: NabaTheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${well.wellName} - قطاع ${index + 1}',
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
                              _buildMiniBadge(
                                  'أرضك', Icons.layers_outlined),
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

  Widget _buildMiniBadge(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
          const SizedBox(width: 6),
          Icon(icon, size: 14, color: Colors.grey),
        ],
      ),
    );
  }
}
