import 'package:flutter/material.dart';

import '../widgets/app_bar.dart';
import '../services/student_data_service.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({
    super.key,
  });

  @override
  State<TimetableScreen> createState() =>
      _TimetableScreenState();
}

class _TimetableScreenState
    extends State<TimetableScreen> {
  // ============================================================
  // COLORS
  // ============================================================

  static const Color primary =
      Color(0xFF6D28D9);

  static const Color primaryDark =
      Color(0xFF4C1D95);

  static const Color primarySoft =
      Color(0xFFF3EEFF);

  static const Color background =
      Color(0xFFF7F7FB);

  static const Color navy =
      Color(0xFF171B2D);

  static const Color muted =
      Color(0xFF687386);

  static const Color border =
      Color(0xFFE7E8EF);

  StudentProfile? student;

  List<Map<String, dynamic>> rows = [];

  bool loading = true;

  String error = '';

  // ============================================================
  // MONDAY - FRIDAY ONLY
  // ============================================================

  int selectedDay =
      DateTime.now().weekday - 1;

  final days = const [
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
  ];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    // Saturday / Sunday -> Monday
    if (selectedDay < 0 ||
        selectedDay >= days.length) {
      selectedDay = 0;
    }

    _load();
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = '';
      });
    }

    try {
      final s =
          await StudentDataService.currentStudent();

      final data =
          await StudentDataService.timetable(s);

      if (!mounted) return;

      setState(() {
        student = s;

        rows =
            List<Map<String, dynamic>>.from(
          data,
        );

        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e
            .toString()
            .replaceFirst(
              'Exception: ',
              '',
            );

        loading = false;
      });
    }
  }

  // ============================================================
  // DAY NORMALIZER
  // ============================================================

  String _normalizeDay(
    dynamic value,
  ) {
    final raw =
        '$value'.trim().toLowerCase();

    switch (raw) {
      case 'mon':
      case 'monday':
        return 'monday';

      case 'tue':
      case 'tues':
      case 'tuesday':
        return 'tuesday';

      case 'wed':
      case 'wednesday':
        return 'wednesday';

      case 'thu':
      case 'thur':
      case 'thurs':
      case 'thursday':
        return 'thursday';

      case 'fri':
      case 'friday':
        return 'friday';

      default:
        return raw;
    }
  }

  // ============================================================
  // SELECTED DAY
  // ============================================================

  String _selectedDayName() {
    switch (selectedDay) {
      case 0:
        return 'monday';

      case 1:
        return 'tuesday';

      case 2:
        return 'wednesday';

      case 3:
        return 'thursday';

      case 4:
        return 'friday';

      default:
        return 'monday';
    }
  }

  // ============================================================
  // DATABASE DAY
  // ============================================================

  String _dayValue(
    Map<String, dynamic> row,
  ) {
    final raw =
        StudentDataService.value(
      row,
      [
        'day',
        'day_name',
        'weekday',
        'day_of_week',
      ],
    );

    return _normalizeDay(raw);
  }

  // ============================================================
  // FILTERED DATA
  // ============================================================

  List<Map<String, dynamic>> get filtered {
    final selected =
        _selectedDayName();

    final result = rows.where(
      (row) {
        final rowDay =
            _dayValue(row);

        // Missing day should never
        // appear on every tab.
        if (rowDay.isEmpty) {
          return false;
        }

        return rowDay == selected;
      },
    ).toList();

    // Sort by hour
    result.sort(
      (a, b) {
        final hourA =
            StudentDataService.number(
          a,
          ['hour', 'period'],
          0,
        );

        final hourB =
            StudentDataService.number(
          b,
          ['hour', 'period'],
          0,
        );

        return hourA.compareTo(hourB);
      },
    );

    return result;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: background,

      appBar: const RoyalAppBar(
        title: 'Timetable',
      ),

      body: RefreshIndicator(
        color: primary,
        backgroundColor: Colors.white,
        onRefresh: _load,

        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),

          padding:
              const EdgeInsets.fromLTRB(
            16,
            6,
            16,
            30,
          ),

          children: [
            _hero(),

            const SizedBox(height: 16),

            _daySelector(),

            const SizedBox(height: 20),

            _sectionHeader(),

            const SizedBox(height: 12),

            if (error.isNotEmpty)
              _errorCard(),

            if (loading)
              _loadingState()
            else if (filtered.isEmpty)
              _emptyState()
            else
              ...filtered
                  .asMap()
                  .entries
                  .map(
                    (entry) => _classCard(
                      entry.key,
                      entry.value,
                    ),
                  ),
          ],
        ),
      ),

      bottomNavigationBar:
          const BottomNav(
        currentIndex: 2,
      ),
    );
  }

  // ============================================================
  // HERO
  // ============================================================

  Widget _hero() {
    return Container(
      width: double.infinity,

      padding:
          const EdgeInsets.fromLTRB(
        20,
        20,
        20,
        19,
      ),

      decoration: BoxDecoration(
        gradient:
            const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF3B176D),
            Color(0xFF6D28D9),
            Color(0xFF8B5CF6),
          ],
        ),

        borderRadius:
            BorderRadius.circular(26),

        boxShadow: [
          BoxShadow(
            color:
                primary.withValues(alpha: .22),
            blurRadius: 24,
            offset:
                const Offset(0, 10),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,

                decoration:
                    BoxDecoration(
                  color: Colors.white
                      .withValues(alpha: .14),

                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),

                  border: Border.all(
                    color: Colors.white
                        .withValues(alpha: .12),
                  ),
                ),

                child: const Icon(
                  Icons
                      .calendar_month_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,

                  children: [
                    const Text(
                      'My Timetable',
                      style:
                          TextStyle(
                        color:
                            Colors.white,
                        fontSize: 20,
                        fontWeight:
                            FontWeight.w900,
                        letterSpacing:
                            -.3,
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      student == null
                          ? 'Loading schedule...'
                          : '${student!.course}  •  '
                              'Semester ${student!.semester}',

                      maxLines: 1,

                      overflow:
                          TextOverflow
                              .ellipsis,

                      style:
                          const TextStyle(
                        color:
                            Colors.white70,
                        fontSize: 10,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Container(
            width: double.infinity,

            padding:
                const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 11,
            ),

            decoration:
                BoxDecoration(
              color: Colors.white
                  .withValues(alpha: .10),

              borderRadius:
                  BorderRadius.circular(
                13,
              ),

              border: Border.all(
                color: Colors.white
                    .withValues(alpha: .08),
              ),
            ),

            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,

                  decoration:
                      const BoxDecoration(
                    color:
                        Color(0xFFC4B5FD),
                    shape:
                        BoxShape.circle,
                  ),
                ),

                const SizedBox(width: 8),

                Text(
                  _fullDayName(
                    selectedDay,
                  ),

                  style:
                      const TextStyle(
                    color:
                        Colors.white,
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const Spacer(),

                if (!loading)
                  Text(
                    '${filtered.length} '
                    '${filtered.length == 1 ? 'class' : 'classes'}',

                    style:
                        const TextStyle(
                      color:
                          Colors.white70,
                      fontSize: 9,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DAY SELECTOR
  // ============================================================

  Widget _daySelector() {
    return Container(
      height: 76,

      padding:
          const EdgeInsets.all(7),

      decoration:
          BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(20),

        border: Border.all(
          color: border,
        ),

        boxShadow: const [
          BoxShadow(
            color:
                Color(0x07000000),
            blurRadius: 14,
            offset:
                Offset(0, 5),
          ),
        ],
      ),

      child: Row(
        children: List.generate(
          days.length,
          (i) {
            final active =
                i == selectedDay;

            final today =
                i ==
                    DateTime.now()
                        .weekday -
                        1 &&
                i >= 0 &&
                i < days.length;

            return Expanded(
              child: Padding(
                padding:
                    EdgeInsets.only(
                  right:
                      i ==
                              days.length -
                                  1
                          ? 0
                          : 5,
                ),

                child:
                    GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedDay = i;
                    });
                  },

                  child:
                      AnimatedContainer(
                    duration:
                        const Duration(
                      milliseconds: 200,
                    ),

                    height: 60,

                    decoration:
                        BoxDecoration(
                      gradient: active
                          ? const LinearGradient(
                              begin:
                                  Alignment.topLeft,
                              end:
                                  Alignment.bottomRight,
                              colors: [
                                Color(
                                  0xFF7C3AED,
                                ),
                                Color(
                                  0xFF5B21B6,
                                ),
                              ],
                            )
                          : null,

                      color: active
                          ? null
                          : const Color(
                              0xFFF8F8FC,
                            ),

                      borderRadius:
                          BorderRadius.circular(
                        15,
                      ),

                      border:
                          Border.all(
                        color: active
                            ? Colors
                                .transparent
                            : const Color(
                                0xFFE7E8EF,
                              ),
                      ),

                      boxShadow:
                          active
                              ? [
                                  BoxShadow(
                                    color:
                                        primary.withValues(
                                      alpha: .22,
                                    ),
                                    blurRadius:
                                        10,
                                    offset:
                                        const Offset(
                                      0,
                                      4,
                                    ),
                                  ),
                                ]
                              : null,
                    ),

                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .center,

                      children: [
                        Text(
                          days[i],

                          style:
                              TextStyle(
                            color: active
                                ? Colors
                                    .white
                                : muted,
                            fontSize: 9,
                            fontWeight:
                                FontWeight.w900,
                            letterSpacing:
                                .3,
                          ),
                        ),

                        const SizedBox(
                          height: 6,
                        ),

                        AnimatedContainer(
                          duration:
                              const Duration(
                            milliseconds:
                                200,
                          ),

                          width:
                              active
                                  ? 6
                                  : 5,

                          height:
                              active
                                  ? 6
                                  : 5,

                          decoration:
                              BoxDecoration(
                            color: active
                                ? Colors
                                    .white
                                : today
                                    ? primary
                                    : const Color(
                                        0xFFD1D5DB,
                                      ),

                            shape:
                                BoxShape
                                    .circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // SECTION HEADER
  // ============================================================

  Widget _sectionHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,

            children: [
              Text(
                _fullDayName(
                  selectedDay,
                ),

                style:
                    const TextStyle(
                  color: navy,
                  fontSize: 18,
                  fontWeight:
                      FontWeight.w900,
                  letterSpacing:
                      -.2,
                ),
              ),

              const SizedBox(
                height: 3,
              ),

              const Text(
                'Your scheduled classes',
                style:
                    TextStyle(
                  color: muted,
                  fontSize: 10,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        if (!loading &&
            filtered.isNotEmpty)
          Container(
            padding:
                const EdgeInsets
                    .symmetric(
              horizontal: 10,
              vertical: 7,
            ),

            decoration:
                BoxDecoration(
              color:
                  primarySoft,

              borderRadius:
                  BorderRadius.circular(
                10,
              ),
            ),

            child: Row(
              mainAxisSize:
                  MainAxisSize.min,

              children: [
                const Icon(
                  Icons
                      .auto_awesome_rounded,
                  size: 11,
                  color: primary,
                ),

                const SizedBox(
                  width: 4,
                ),

                Text(
                  '${filtered.length}',
                  style:
                      const TextStyle(
                    color: primary,
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ============================================================
  // FULL DAY NAME
  // ============================================================

  String _fullDayName(
    int index,
  ) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
    ];

    if (index < 0 ||
        index >= names.length) {
      return 'Monday';
    }

    return names[index];
  }

  // ============================================================
  // CLASS CARD
  // ============================================================

  Widget _classCard(
    int index,
    Map<String, dynamic> r,
  ) {
    final subject =
        StudentDataService.value(
      r,
      [
        'subject',
        'subject_name',
        'course_subject',
      ],
      'Class',
    );

    final faculty =
        StudentDataService.value(
      r,
      [
        'faculty',
        'teacher',
        'faculty_name',
      ],
      'Faculty',
    );

    final time =
        StudentDataService.value(
      r,
      [
        'time',
        'start_time',
      ],
      'Scheduled class',
    );

    final room =
        StudentDataService.value(
      r,
      [
        'room',
        'classroom',
        'location',
      ],
    );

    final hour =
        StudentDataService.number(
      r,
      [
        'hour',
        'period',
      ],
      0,
    );

    final endTime =
        StudentDataService.value(
      r,
      [
        'end_time',
      ],
    );

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),

      decoration:
          BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(
          19,
        ),

        border: Border.all(
          color: border,
        ),

        boxShadow: const [
          BoxShadow(
            color:
                Color(0x06000000),
            blurRadius: 14,
            offset:
                Offset(0, 5),
          ),
        ],
      ),

      child: IntrinsicHeight(
        child: Row(
          children: [
            // ==================================================
            // LEFT ACCENT
            // ==================================================

            Container(
              width: 5,

              decoration:
                  const BoxDecoration(
                gradient:
                    LinearGradient(
                  begin:
                      Alignment.topCenter,
                  end:
                      Alignment.bottomCenter,
                  colors: [
                    Color(
                      0xFF8B5CF6,
                    ),
                    Color(
                      0xFF4C1D95,
                    ),
                  ],
                ),

                borderRadius:
                    BorderRadius.only(
                  topLeft:
                      Radius.circular(
                    19,
                  ),
                  bottomLeft:
                      Radius.circular(
                    19,
                  ),
                ),
              ),
            ),

            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  14,
                ),

                child: Row(
                  children: [
                    // ========================================
                    // HOUR
                    // ========================================

                    Container(
                      width: 54,
                      height: 58,

                      decoration:
                          BoxDecoration(
                        gradient:
                            const LinearGradient(
                          begin:
                              Alignment.topLeft,
                          end:
                              Alignment.bottomRight,
                          colors: [
                            Color(
                              0xFFF4EEFF,
                            ),
                            Color(
                              0xFFEDE5FF,
                            ),
                          ],
                        ),

                        borderRadius:
                            BorderRadius.circular(
                          15,
                        ),
                      ),

                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .center,

                        children: [
                          Text(
                            hour == 0
                                ? '—'
                                : '$hour',

                            style:
                                const TextStyle(
                              color:
                                  primary,
                              fontSize: 19,
                              fontWeight:
                                  FontWeight
                                      .w900,
                              height: 1,
                            ),
                          ),

                          const SizedBox(
                            height: 4,
                          ),

                          Text(
                            'HOUR',

                            style:
                                TextStyle(
                              color:
                                  primary.withValues(
                                alpha: .60,
                              ),
                              fontSize: 6,
                              fontWeight:
                                  FontWeight
                                      .w900,
                              letterSpacing:
                                  .8,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      width: 13,
                    ),

                    // ========================================
                    // DETAILS
                    // ========================================

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,

                        mainAxisAlignment:
                            MainAxisAlignment
                                .center,

                        children: [
                          Text(
                            subject,

                            maxLines: 1,

                            overflow:
                                TextOverflow
                                    .ellipsis,

                            style:
                                const TextStyle(
                              color: navy,
                              fontSize: 13,
                              fontWeight:
                                  FontWeight
                                      .w900,
                            ),
                          ),

                          const SizedBox(
                            height: 7,
                          ),

                          Row(
                            children: [
                              Container(
                                width: 23,
                                height: 23,

                                decoration:
                                    BoxDecoration(
                                  color:
                                      const Color(
                                    0xFFF3F4F8,
                                  ),
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    7,
                                  ),
                                ),

                                child:
                                    const Icon(
                                  Icons
                                      .person_outline_rounded,
                                  size: 13,
                                  color:
                                      muted,
                                ),
                              ),

                              const SizedBox(
                                width: 6,
                              ),

                              Expanded(
                                child: Text(
                                  faculty,

                                  maxLines:
                                      1,

                                  overflow:
                                      TextOverflow
                                          .ellipsis,

                                  style:
                                      const TextStyle(
                                    color:
                                        muted,
                                    fontSize:
                                        9,
                                    fontWeight:
                                        FontWeight
                                            .w600,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          if (room.isNotEmpty) ...[
                            const SizedBox(
                              height: 5,
                            ),

                            Row(
                              children: [
                                const Icon(
                                  Icons
                                      .location_on_outlined,
                                  size: 12,
                                  color:
                                      Color(
                                    0xFF9AA3B2,
                                  ),
                                ),

                                const SizedBox(
                                  width: 4,
                                ),

                                Expanded(
                                  child: Text(
                                    room,

                                    maxLines:
                                        1,

                                    overflow:
                                        TextOverflow
                                            .ellipsis,

                                    style:
                                        const TextStyle(
                                      color:
                                          Color(
                                        0xFF9AA3B2,
                                      ),
                                      fontSize:
                                          8,
                                      fontWeight:
                                          FontWeight
                                              .w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(
                      width: 8,
                    ),

                    // ========================================
                    // TIME
                    // ========================================

                    Container(
                      constraints:
                          const BoxConstraints(
                        minWidth: 55,
                      ),

                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),

                      decoration:
                          BoxDecoration(
                        color:
                            primarySoft,

                        borderRadius:
                            BorderRadius.circular(
                          10,
                        ),
                      ),

                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .center,

                        children: [
                          const Icon(
                            Icons
                                .schedule_rounded,
                            size: 13,
                            color:
                                primary,
                          ),

                          const SizedBox(
                            height: 4,
                          ),

                          Text(
                            time,

                            maxLines: 2,

                            textAlign:
                                TextAlign
                                    .center,

                            overflow:
                                TextOverflow
                                    .ellipsis,

                            style:
                                const TextStyle(
                              color:
                                  primary,
                              fontSize: 8,
                              fontWeight:
                                  FontWeight
                                      .w900,
                            ),
                          ),

                          if (endTime
                              .isNotEmpty) ...[
                            const SizedBox(
                              height: 2,
                            ),

                            Text(
                              endTime,

                              style:
                                  const TextStyle(
                                color:
                                    muted,
                                fontSize:
                                    7,
                                fontWeight:
                                    FontWeight
                                        .w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LOADING
  // ============================================================

  Widget _loadingState() {
    return Column(
      children: List.generate(
        3,
        (index) {
          return Container(
            height: 96,

            margin:
                const EdgeInsets.only(
              bottom: 12,
            ),

            decoration:
                BoxDecoration(
              color: Colors.white,

              borderRadius:
                  BorderRadius.circular(
                19,
              ),

              border: Border.all(
                color: border,
              ),
            ),

            child: const Center(
              child:
                  CircularProgressIndicator(
                strokeWidth: 2,
                color: primary,
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _errorCard() {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),

      padding:
          const EdgeInsets.all(13),

      decoration:
          BoxDecoration(
        color:
            const Color(0xFFFFF1F2),

        borderRadius:
            BorderRadius.circular(
          14,
        ),

        border: Border.all(
          color:
              const Color(0xFFFECACA),
        ),
      ),

      child: Row(
        children: [
          const Icon(
            Icons
                .error_outline_rounded,
            color:
                Color(0xFFBE123C),
            size: 19,
          ),

          const SizedBox(
            width: 8,
          ),

          Expanded(
            child: Text(
              error,

              style:
                  const TextStyle(
                color:
                    Color(0xFFBE123C),
                fontSize: 9,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _emptyState() {
    return Container(
      width: double.infinity,

      padding:
          const EdgeInsets.symmetric(
        horizontal: 25,
        vertical: 42,
      ),

      decoration:
          BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(
          21,
        ),

        border: Border.all(
          color: border,
        ),

        boxShadow: const [
          BoxShadow(
            color:
                Color(0x04000000),
            blurRadius: 10,
            offset:
                Offset(0, 3),
          ),
        ],
      ),

      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,

            decoration:
                const BoxDecoration(
              gradient:
                  LinearGradient(
                colors: [
                  Color(0xFFF3EEFF),
                  Color(0xFFEDE5FF),
                ],
              ),

              shape:
                  BoxShape.circle,
            ),

            child: const Icon(
              Icons
                  .event_note_rounded,
              color: primary,
              size: 31,
            ),
          ),

          const SizedBox(
            height: 14,
          ),

          const Text(
            'No Classes Today',
            style:
                TextStyle(
              color: navy,
              fontSize: 14,
              fontWeight:
                  FontWeight.w900,
            ),
          ),

          const SizedBox(
            height: 5,
          ),

          Text(
            'There are no classes scheduled '
            'for ${_fullDayName(selectedDay)}.',

            textAlign:
                TextAlign.center,

            style:
                const TextStyle(
              color: muted,
              fontSize: 9,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}