import 'package:supabase_flutter/supabase_flutter.dart';

class StudentProfile {
  final String id;
  final String name;
  final String regNo;
  final String admissionNo;
  final String capId;
  final String course;
  final int semester;
  final String status;
  final String avatarUrl;

  const StudentProfile({
    required this.id,
    required this.name,
    required this.regNo,
    required this.admissionNo,
    required this.capId,
    required this.course,
    required this.semester,
    required this.status,
    required this.avatarUrl,
  });

  factory StudentProfile.fromMap(
    Map<String, dynamic> row,
  ) {
    final rawAvatar = row['avatar_url'];

    return StudentProfile(
      id: '${row['id'] ?? ''}',
      name: '${row['name'] ?? ''}',
      regNo: '${row['reg_no'] ?? ''}',
      admissionNo: '${row['admission_no'] ?? ''}',
      capId: '${row['cap_id'] ?? ''}',
      course: '${row['course'] ?? ''}',
      semester:
          int.tryParse('${row['semester'] ?? 1}') ?? 1,
      status: '${row['status'] ?? ''}',

      // NULL / empty -> ''
      avatarUrl:
          rawAvatar == null
              ? ''
              : rawAvatar.toString().trim(),
    );
  }
}

class StudentDataService {
  static SupabaseClient get client =>
      Supabase.instance.client;

  // ============================================================
  // CURRENT AUTH USER
  // ============================================================

  static User? get currentUser =>
      client.auth.currentUser;

  // ============================================================
  // CURRENT STUDENT
  // IMPORTANT:
  // This ALWAYS reads from Supabase.
  // No local/cache student object is used.
  // ============================================================

  static Future<StudentProfile> currentStudent() async {
    final authUser = client.auth.currentUser;

    if (authUser == null) {
      throw Exception(
        'Please login again.',
      );
    }

    final result = await client
        .from('students')
        .select('''
          id,
          name,
          admission_no,
          cap_id,
          reg_no,
          course,
          semester,
          status,
          auth_user_id,
          avatar_url
        ''')
        .eq(
          'auth_user_id',
          authUser.id,
        )
        .maybeSingle();

    if (result == null) {
      throw Exception(
        'Student profile not found.',
      );
    }

    return StudentProfile.fromMap(
      Map<String, dynamic>.from(result),
    );
  }

  // ============================================================
  // GET CURRENT STUDENT RAW ROW
  // ============================================================

  static Future<Map<String, dynamic>>
      currentStudentRow() async {
    final authUser = client.auth.currentUser;

    if (authUser == null) {
      throw Exception(
        'Please login again.',
      );
    }

    final result = await client
        .from('students')
        .select('*')
        .eq(
          'auth_user_id',
          authUser.id,
        )
        .maybeSingle();

    if (result == null) {
      throw Exception(
        'Student profile not found.',
      );
    }

    return Map<String, dynamic>.from(
      result,
    );
  }

  // ============================================================
  // RESOLVE PROFILE IMAGE URL
  //
  // Supports:
  // 1. Full public Supabase URL
  // 2. Stored storage path
  // 3. Legacy file:///... or UUID values
  //
  // This never creates a URL when avatar_url is NULL/empty.
  // ============================================================

  static Future<String> resolveAvatarUrl(
    String? storedValue,
  ) async {
    final raw = storedValue?.trim() ?? '';

    if (raw.isEmpty) {
      return '';
    }

    // Already a real web URL.
    if (raw.startsWith('https://') ||
        raw.startsWith('http://')) {
      return raw;
    }

    final user = client.auth.currentUser;
    if (user == null) {
      return '';
    }

    // Try the value itself as a storage path.
    try {
      var storagePath = raw;

      if (storagePath.startsWith('file:///')) {
        storagePath = storagePath.substring('file:///'.length);
      }

      if (storagePath.startsWith('/')) {
        storagePath = storagePath.substring(1);
      }

      // If an old value only contains a filename/UUID, first try it
      // inside this student's folder.
      if (!storagePath.contains('/')) {
        storagePath = '${user.id}/$storagePath';
      }

      final url = client.storage
          .from('profile-images')
          .getPublicUrl(storagePath);

      if (url.startsWith('http://') ||
          url.startsWith('https://')) {
        return url;
      }
    } catch (e) {
      // Continue to the folder lookup below.
    }

    // Legacy-safe fallback:
    // Find the actual profile.* file in this student's folder.
    try {
      final files = await client.storage
          .from('profile-images')
          .list(path: user.id);

      final profileFile = files.cast<dynamic>().where((file) {
        final name = '${file.name}'.toLowerCase();
        return name.startsWith('profile.');
      }).toList();

      if (profileFile.isNotEmpty) {
        final name = '${profileFile.first.name}';
        final path = '${user.id}/$name';

        return client.storage
            .from('profile-images')
            .getPublicUrl(path);
      }
    } catch (e) {
      // No accessible image.
    }

    return '';
  }

  // ============================================================
  // UPDATE AVATAR URL
  // ============================================================

  static Future<StudentProfile>
      updateAvatarUrl(
    String? avatarUrl,
  ) async {
    final authUser = client.auth.currentUser;

    if (authUser == null) {
      throw Exception(
        'Please login again.',
      );
    }

    final cleanUrl =
        avatarUrl?.trim() ?? '';

    await client
        .from('students')
        .update({
      // Empty string should become NULL.
      'avatar_url':
          cleanUrl.isEmpty
              ? null
              : cleanUrl,
    })
        .eq(
      'auth_user_id',
      authUser.id,
    );

    // ----------------------------------------------------------
    // IMPORTANT:
    // Read again directly from DB.
    // ----------------------------------------------------------

    return currentStudent();
  }

  // ============================================================
  // REMOVE AVATAR URL FROM DATABASE
  // ============================================================

  static Future<StudentProfile>
      removeAvatarUrl() async {
    final authUser = client.auth.currentUser;

    if (authUser == null) {
      throw Exception(
        'Please login again.',
      );
    }

    await client
        .from('students')
        .update({
      'avatar_url': null,
    })
        .eq(
      'auth_user_id',
      authUser.id,
    );

    // ----------------------------------------------------------
    // VERIFY.
    // If DB still contains old URL, throw error.
    // ----------------------------------------------------------

    final row =
        await currentStudentRow();

    final dbAvatar =
        row['avatar_url'];

    if (dbAvatar != null &&
        dbAvatar
            .toString()
            .trim()
            .isNotEmpty) {
      throw Exception(
        'Profile picture could not be removed from database.',
      );
    }

    return currentStudent();
  }

  // ============================================================
  // GENERIC ROWS
  // ============================================================

  static Future<List<Map<String, dynamic>>> rows(
    String table, {
    int limit = 500,
  }) async {
    final result = await client
        .from(table)
        .select('*')
        .limit(limit);

    return List<Map<String, dynamic>>.from(
      result.map(
        (item) =>
            Map<String, dynamic>.from(item),
      ),
    );
  }

  // ============================================================
  // VALUE
  // ============================================================

  static String value(
    Map<String, dynamic> row,
    List<String> keys, [
    String fallback = '',
  ]) {
    for (final key in keys) {
      final rawValue = row[key];

      if (rawValue != null &&
          '$rawValue'.trim().isNotEmpty) {
        return '$rawValue';
      }
    }

    return fallback;
  }

  // ============================================================
  // NUMBER
  // ============================================================

  static int number(
    Map<String, dynamic> row,
    List<String> keys, [
    int fallback = 0,
  ]) {
    final rawValue =
        StudentDataService.value(
      row,
      keys,
    );

    return int.tryParse(
          rawValue,
        ) ??
        fallback;
  }

  // ============================================================
  // DATE
  // ============================================================

  static DateTime? date(
    Map<String, dynamic> row,
    List<String> keys,
  ) {
    final rawValue =
        StudentDataService.value(
      row,
      keys,
    );

    return DateTime.tryParse(
      rawValue,
    );
  }

  // ============================================================
  // ANNOUNCEMENTS
  // ============================================================

  static Future<List<Map<String, dynamic>>>
      announcements() async {
    final dataRows =
        await StudentDataService.rows(
      'announcements',
    );

    dataRows.sort(
      (a, b) {
        final da =
            StudentDataService.date(
          a,
          [
            'published_at',
            'created_at',
            'date',
          ],
        );

        final db =
            StudentDataService.date(
          b,
          [
            'published_at',
            'created_at',
            'date',
          ],
        );

        return (db ?? DateTime(1970))
            .compareTo(
          da ?? DateTime(1970),
        );
      },
    );

    return dataRows;
  }

  // ============================================================
  // TIMETABLE
  // ============================================================

  static Future<List<Map<String, dynamic>>>
      timetable(
    StudentProfile student,
  ) async {
    final dataRows =
        await StudentDataService.rows(
      'timetables',
    );

    return dataRows.where(
      (row) {
        final rowCourse =
            StudentDataService.value(
          row,
          [
            'course',
            'course_name',
            'programme',
          ],
        ).trim();

        final rowSemester =
            StudentDataService.number(
          row,
          [
            'semester',
            'sem',
          ],
          0,
        );

        final courseMatches =
            rowCourse.isEmpty ||
                rowCourse.toLowerCase() ==
                    student.course
                        .trim()
                        .toLowerCase();

        final semesterMatches =
            rowSemester == 0 ||
                rowSemester ==
                    student.semester;

        return courseMatches &&
            semesterMatches;
      },
    ).toList();
  }

  // ============================================================
  // SYLLABUS
  // ============================================================

  static Future<List<Map<String, dynamic>>>
      syllabus(
    StudentProfile student,
  ) async {
    final courseResult = await client
        .from('syllabus_courses')
        .select('id,code,name')
        .ilike(
          'name',
          student.course.trim(),
        )
        .maybeSingle();

    if (courseResult == null) {
      return [];
    }

    final courseId =
        '${courseResult['id']}';

    final result = await client
        .from('syllabus_subjects')
        .select('''
          id,
          course_id,
          semester,
          subject_code,
          subject_name,
          description,
          created_at,
          updated_at
        ''')
        .eq(
          'course_id',
          courseId,
        )
        .eq(
          'semester',
          student.semester,
        )
        .order(
          'subject_code',
          ascending: true,
        );

    return List<Map<String, dynamic>>.from(
      result.map(
        (item) =>
            Map<String, dynamic>.from(item),
      ),
    );
  }

  // ============================================================
  // ONLINE CLASSES
  // ============================================================

  static Future<List<Map<String, dynamic>>>
      onlineClasses(
    StudentProfile student,
  ) async {
    final dataRows =
        await StudentDataService.rows(
      'online_classes',
    );

    return dataRows.where(
      (row) {
        final rowCourse =
            StudentDataService.value(
          row,
          [
            'course',
            'course_name',
            'programme',
          ],
        );

        final rowSemester =
            StudentDataService.number(
          row,
          [
            'semester',
            'sem',
          ],
          0,
        );

        return (rowCourse.isEmpty ||
                rowCourse ==
                    student.course) &&
            (rowSemester == 0 ||
                rowSemester ==
                    student.semester);
      },
    ).toList();
  }

  // ============================================================
  // ATTENDANCE
  // ============================================================

  static Future<List<Map<String, dynamic>>>
      attendance(
    StudentProfile student,
  ) async {
    final sessions = await client
        .from('attendance_sessions')
        .select('''
          id,
          attendance_date,
          course,
          semester,
          hour
        ''')
        .eq(
          'course',
          student.course,
        )
        .eq(
          'semester',
          student.semester,
        )
        .order(
          'attendance_date',
          ascending: false,
        )
        .order(
          'hour',
          ascending: true,
        );

    if (sessions.isEmpty) {
      return [];
    }

    final sessionIds = sessions
        .map(
          (row) => row['id'],
        )
        .toList();

    final records = await client
        .from('attendance_records')
        .select('''
          session_id,
          student_id,
          status
        ''')
        .eq(
          'student_id',
          student.id,
        )
        .inFilter(
          'session_id',
          sessionIds,
        );

    final sessionMap =
        <String, Map<String, dynamic>>{
      for (final row in sessions)
        '${row['id']}':
            Map<String, dynamic>.from(
          row,
        ),
    };

    return records.map(
      (record) {
        final session =
            sessionMap[
                  '${record['session_id']}'
                ] ??
                {};

        return {
          ...Map<String, dynamic>.from(
            record,
          ),
          'attendance_date':
              session[
                  'attendance_date'],
          'hour':
              session['hour'],
          'course':
              session['course'],
          'semester':
              session['semester'],
        };
      },
    ).toList();
  }

  // ============================================================
  // ATTENDANCE DATE
  // ============================================================

  static Future<List<Map<String, dynamic>>>
      attendanceForDate(
    StudentProfile student,
    DateTime date,
  ) async {
    final all =
        await attendance(student);

    final target = DateTime(
      date.year,
      date.month,
      date.day,
    );

    return all.where(
      (row) {
        final raw =
            row['attendance_date'];

        if (raw == null) {
          return false;
        }

        final parsed =
            DateTime.tryParse(
          '$raw',
        );

        if (parsed == null) {
          return false;
        }

        final current = DateTime(
          parsed.year,
          parsed.month,
          parsed.day,
        );

        return current == target;
      },
    ).toList();
  }

  // ============================================================
  // ATTENDANCE MONTH
  // ============================================================

  static Future<List<Map<String, dynamic>>>
      attendanceForMonth(
    StudentProfile student,
    DateTime month,
  ) async {
    final all =
        await attendance(student);

    return all.where(
      (row) {
        final raw =
            row['attendance_date'];

        if (raw == null) {
          return false;
        }

        final parsed =
            DateTime.tryParse(
          '$raw',
        );

        if (parsed == null) {
          return false;
        }

        return parsed.year ==
                month.year &&
            parsed.month ==
                month.month;
      },
    ).toList();
  }

  // ============================================================
  // ATTENDANCE SEMESTER
  // ============================================================

  static Future<List<Map<String, dynamic>>>
      attendanceForSemester(
    StudentProfile student,
  ) async {
    return attendance(student);
  }

  // ============================================================
  // LIBRARY
  // ============================================================

  static Future<List<Map<String, dynamic>>>
      libraryBooks() async {
    final result = await client
        .from('library_books')
        .select('''
          id,
          title,
          author,
          book_code,
          category,
          total_copies,
          available_copies,
          status,
          created_at,
          updated_at
        ''')
        .eq(
          'status',
          'ACTIVE',
        )
        .order(
          'title',
          ascending: true,
        );

    return List<Map<String, dynamic>>.from(
      result.map(
        (item) =>
            Map<String, dynamic>.from(item),
      ),
    );
  }

  // ============================================================
  // LIBRARY RESERVATIONS
  // ============================================================

  static Future<List<Map<String, dynamic>>>
      myLibraryReservations(
    StudentProfile student,
  ) async {
    final result = await client
        .from('library_reservations')
        .select('''
          id,
          book_id,
          student_id,
          reserved_at,
          pickup_deadline,
          status,
          created_at,
          updated_at,
          library_books (
            id,
            title,
            author,
            book_code,
            category
          )
        ''')
        .eq(
          'student_id',
          student.id,
        )
        .order(
          'reserved_at',
          ascending: false,
        );

    return List<Map<String, dynamic>>.from(
      result.map(
        (item) =>
            Map<String, dynamic>.from(item),
      ),
    );
  }

  // ============================================================
  // RESERVE BOOK
  // ============================================================

  static Future<void> reserveBook({
    required StudentProfile student,
    required String bookId,
  }) async {
    if (bookId.trim().isEmpty) {
      throw Exception(
        'Invalid book.',
      );
    }

    await client.rpc(
      'reserve_library_book',
      params: {
        'p_book_id': bookId,
        'p_student_id': student.id,
      },
    );
  }

  // ============================================================
  // DOUBTS
  // ============================================================

  static Future<List<Map<String, dynamic>>>
      doubts(
    StudentProfile student,
  ) async {
    final result = await client
        .from('doubts')
        .select('*')
        .eq(
          'student_id',
          student.id,
        );

    return List<Map<String, dynamic>>.from(
      result.map(
        (item) =>
            Map<String, dynamic>.from(item),
      ),
    );
  }

  // ============================================================
  // CREATE DOUBT
  // ============================================================

  static Future<void> createDoubt({
    required StudentProfile student,
    required String subject,
    required String question,
  }) async {
    await client.from('doubts').insert({
      'student_id': student.id,
      'student_name': student.name,
      'title': subject,
      'course': student.course,
      'subject': subject,
      'question': question,
      'status': 'pending',
    });
  }

  // ============================================================
  // LEAVES
  // ============================================================

  static Future<List<Map<String, dynamic>>>
      leaves(
    StudentProfile student,
  ) async {
    final result = await client
        .from('leave_requests')
        .select('*')
        .eq(
          'student_id',
          student.id,
        );

    return List<Map<String, dynamic>>.from(
      result.map(
        (item) =>
            Map<String, dynamic>.from(item),
      ),
    );
  }

  // ============================================================
  // CREATE LEAVE
  // ============================================================

  static Future<void> createLeave({
    required StudentProfile student,
    required DateTime from,
    required DateTime to,
    required String reason,
  }) async {
    final studentName =
        student.name.trim();

    if (studentName.isEmpty) {
      throw Exception(
        'Student name is missing. Please login again.',
      );
    }

    await client
        .from('leave_requests')
        .insert({
      'student_id': student.id,
      'student_name': studentName,
      'course': student.course,
      'semester': student.semester,
      'from_date':
          from.toIso8601String(),
      'to_date':
          to.toIso8601String(),
      'reason': reason,
      'status': 'pending',
    });
  }

  // ============================================================
  // PRESENT COUNT
  // ============================================================

  static Future<int> presentCount(
    StudentProfile student,
  ) async {
    final data =
        await attendance(student);

    return data.where(
      (row) {
        final status =
            value(
          row,
          ['status'],
        ).toLowerCase();

        return status == 'present';
      },
    ).length;
  }

  // ============================================================
  // ATTENDANCE COUNT
  // ============================================================

  static Future<int> attendanceCount(
    StudentProfile student,
  ) async {
    final data =
        await attendance(student);

    return data.length;
  }

  // ============================================================
  // SIGN OUT
  // ============================================================

  static Future<void> signOut() async {
    await client.auth.signOut();
  }
}