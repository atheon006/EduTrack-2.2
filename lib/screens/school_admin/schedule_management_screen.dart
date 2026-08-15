import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../services/schedule_service.dart';
import '../../services/class_services.dart';
import '../../services/teacher_service.dart';
import '../../utils/constants.dart'; 

class ScheduleManagementScreen extends StatefulWidget {
  const ScheduleManagementScreen({super.key});

  @override
  _ScheduleManagementScreenState createState() => _ScheduleManagementScreenState();
}

class _ScheduleManagementScreenState extends State<ScheduleManagementScreen>
    with SingleTickerProviderStateMixin {
  late ScheduleService _scheduleService;
  late ClassService _classService;
  late TeacherService _teacherService;
  late TabController _tabController;
  
  // Theme colors
  late Color _primaryColor;
  late Color _accentColor;
  late Color _tertiaryColor;

  // State variables
  bool _isLoading = true;
  bool _isCreatingSchedule = false;
  
  // Data storage
  List<Map<String, dynamic>> _availableClasses = [];
  List<Map<String, dynamic>> _classTeachers = [];
  List<String> _classSubjects = [];
  List<Map<String, dynamic>> _existingSchedules = [];
  
  // Selection state for view tab
  String? _selectedViewClassId;
  Map<String, dynamic>? _selectedViewClass;
  Map<String, dynamic>? _viewSchedule;
  
  // Selection state for create/edit tab
  String? _selectedClassId;
  Map<String, dynamic>? _selectedClass;
  List<Map<String, dynamic>> _periods = [];
  Map<String, dynamic>? _existingScheduleForClass;
  bool _isUpdateMode = false;
  String? _scheduleIdToUpdate;
  
  // Constants
  final List<String> _daysOfWeek = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'
  ];
  
  final List<Map<String, String>> _timeSlots = [
    {'period': '1', 'start': '09:00', 'end': '09:45'},
    {'period': '2', 'start': '09:45', 'end': '10:30'},
    {'period': '3', 'start': '10:45', 'end': '11:30'},
    {'period': '4', 'start': '11:30', 'end': '12:15'},
    {'period': '5', 'start': '01:00', 'end': '01:45'},
    {'period': '6', 'start': '01:45', 'end': '02:30'},
    {'period': '7', 'start': '02:45', 'end': '03:30'},
    {'period': '8', 'start': '03:30', 'end': '04:15'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadThemeColors();
    _scheduleService = ScheduleService(baseUrl: Constants.apiBaseUrl);
    _classService = ClassService(baseUrl: Constants.apiBaseUrl );
    _teacherService = TeacherService(baseUrl:  Constants.apiBaseUrl);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadThemeColors() {
    _primaryColor = AppTheme.getPrimaryColor(AppTheme.defaultTheme);
    _accentColor = AppTheme.getAccentColor(AppTheme.defaultTheme);
    _tertiaryColor = AppTheme.getTertiaryColor(AppTheme.defaultTheme);
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    
    try {
      await _loadAvailableClasses();
      await _loadExistingSchedules();
    } catch (e) {
      _showErrorSnackBar('Failed to load initial data: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAvailableClasses() async {
    try {
      final classes = await _classService.getAllClasses();
      setState(() {
        _availableClasses = classes;
      });
      print('📅 Loaded ${classes.length} classes');
    } catch (e) {
      print('❌ Error loading classes: $e');
      throw e;
    }
  }

  Future<void> _loadExistingSchedules() async {
    try {
      final schedules = await _scheduleService.getAllSchedules();
      setState(() {
        _existingSchedules = schedules;
      });
      print('📅 Loaded ${schedules.length} existing schedules');
    } catch (e) {
      print('❌ Error loading schedules: $e');
    }
  }

  // View Schedule Methods
  Future<void> _selectClassForView(String classId) async {
    final selectedClass = _availableClasses.firstWhere((c) => c['_id'] == classId);
    
    setState(() {
      _selectedViewClassId = classId;
      _selectedViewClass = selectedClass;
      _viewSchedule = null;
      _isLoading = true;
    });
    
    await _loadScheduleForClass(classId);
  }

  Future<void> _loadScheduleForClass(String classId) async {
    try {
      print('📅 Loading schedule for classId: $classId');
      final schedules = await _scheduleService.getSchedulesByClassId(classId);
      
      setState(() {
        if (schedules.isNotEmpty) {
          _viewSchedule = schedules.first;
          print('📅 Found schedule with ${_viewSchedule!['periods']?.length ?? 0} periods');
          print('📅 Schedule data: $_viewSchedule');
        } else {
          _viewSchedule = null;
          print('📅 No schedule found for this class');
        }
        _isLoading = false;
      });
    } catch (e) {
      print('📅 Error loading schedule: $e');
      setState(() {
        _viewSchedule = null;
        _isLoading = false;
      });
    }
  }

  void _editSchedule() {
    if (_viewSchedule != null && _selectedViewClassId != null) {
      // Switch to create/edit tab and pre-populate data
      _tabController.animateTo(1);
      _selectClassForEdit(_selectedViewClassId!);
    }
  }

  // Create/Edit Schedule Methods
  Future<void> _selectClassForEdit(String classId) async {
    final selectedClass = _availableClasses.firstWhere((c) => c['_id'] == classId);
    
    setState(() {
      _selectedClassId = classId;
      _selectedClass = selectedClass;
      _periods.clear();
      _existingScheduleForClass = null;
      _isUpdateMode = false;
      _scheduleIdToUpdate = null;
    });
    
    await _loadClassDetails(classId);
    await _checkExistingSchedule(classId);
  }

  Future<void> _loadClassDetails(String classId) async {
    setState(() => _isLoading = true);
    
    try {
      print('📅 Loading class details for classId: $classId');
      
      final results = await Future.wait([
        _classService.getClassTeachers(classId),
        _classService.getClassSubjects(classId).catchError((error) {
          print('📅 Warning: Failed to load subjects: $error');
          return <String>[];
        }),
      ]);
      
      setState(() {
        _classTeachers = results[0] as List<Map<String, dynamic>>;
        _classSubjects = results[1] as List<String>;
      });
      
      print('📅 Loaded ${_classTeachers.length} teachers and ${_classSubjects.length} subjects for class');
      
    } catch (e) {
      print('📅 Error loading class details: $e');
      _showErrorSnackBar('Failed to load class details: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkExistingSchedule(String classId) async {
    try {
      print('📅 Checking for existing schedule for classId: $classId');
      final schedules = await _scheduleService.getSchedulesByClassId(classId);
      
      if (schedules.isNotEmpty) {
        final existingSchedule = schedules.first;
        setState(() {
          _existingScheduleForClass = existingSchedule;
          _isUpdateMode = true;
          _scheduleIdToUpdate = existingSchedule['_id'];
        });
        
        _loadExistingPeriods(existingSchedule);
        print('📅 Found existing schedule for class. Schedule ID: ${existingSchedule['_id']}');
      } else {
        setState(() {
          _existingScheduleForClass = null;
          _isUpdateMode = false;
          _scheduleIdToUpdate = null;
        });
        print('📅 No existing schedule found for this class');
      }
    } catch (e) {
      print('📅 Error checking existing schedule: $e');
    }
  }

  void _loadExistingPeriods(Map<String, dynamic> schedule) {
    if (schedule['periods'] != null) {
      final periods = schedule['periods'] as List<dynamic>;
      setState(() {
        _periods = periods.map((period) => {
          'dayOfWeek': period['dayOfWeek'],
          'periodNumber': period['periodNumber'],
          'subject': period['subject'],
          'teacherId': _getTeacherIdFromData(period['teacherId']),
          'startTime': period['startTime'],
          'endTime': period['endTime'],
        }).toList();
      });
      print('📅 Loaded ${_periods.length} existing periods');
    }
  }

  void _addPeriod() {
    if (_selectedClassId == null) {
      _showErrorSnackBar('Please select a class first');
      return;
    }
    
    if (_classTeachers.isEmpty || _classSubjects.isEmpty) {
      _showErrorSnackBar('Class must have teachers and subjects assigned');
      return;
    }
    
    _showAddPeriodDialog();
  }

  // Add new method to edit existing period
  void _editPeriod(int periodIndex) {
    if (_selectedClassId == null) {
      _showErrorSnackBar('Please select a class first');
      return;
    }
    
    if (_classTeachers.isEmpty || _classSubjects.isEmpty) {
      _showErrorSnackBar('Class must have teachers and subjects assigned');
      return;
    }
    
    final period = _periods[periodIndex];
    _showAddPeriodDialog(
      editingIndex: periodIndex,
      existingPeriod: period,
    );
  }

  void _showAddPeriodDialog({int? editingIndex, Map<String, dynamic>? existingPeriod, String? preSelectedDay}) {
    if (_classSubjects.isEmpty) {
      _showErrorSnackBar('No subjects available for this class. Please add subjects first.');
      return;
    }
    
    if (_classTeachers.isEmpty) {
      _showErrorSnackBar('No teachers available for this class. Please assign teachers first.');
      return;
    }
    
    // Initialize with existing data if editing, otherwise use defaults
    String selectedDay = existingPeriod?['dayOfWeek'] ?? preSelectedDay ?? _daysOfWeek[0];
    int selectedPeriod = existingPeriod?['periodNumber'] ?? 1;
    String selectedSubject = existingPeriod?['subject'] ?? _classSubjects[0];
    String selectedTeacherId = existingPeriod?['teacherId'] ?? _classTeachers[0]['_id'];
    
    // Validate that existing values are still valid
    if (!_daysOfWeek.contains(selectedDay)) {
      selectedDay = _daysOfWeek[0];
    }
    if (!_classSubjects.contains(selectedSubject)) {
      selectedSubject = _classSubjects[0];
    }
    if (!_classTeachers.any((t) => t['_id'] == selectedTeacherId)) {
      selectedTeacherId = _classTeachers[0]['_id'];
    }
    
    final isEditing = editingIndex != null;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(
                isEditing ? Icons.edit : Icons.access_time, 
                color: _primaryColor,
              ),
              const SizedBox(width: 8),
              Text(isEditing ? 'Edit Period' : 'Add Period'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Show current period info if editing
                if (isEditing) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.orange, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Editing: ${existingPeriod!['dayOfWeek']} Period ${existingPeriod['periodNumber']}',
                            style: const TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                DropdownButtonFormField<String>(
                  value: selectedDay,
                  decoration: InputDecoration(
                    labelText: 'Day of Week',
                    border: const OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today, color: _accentColor),
                  ),
                  items: _daysOfWeek.map((day) => DropdownMenuItem(
                    value: day,
                    child: Text(day),
                  )).toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedDay = value!);
                  },
                ),
                const SizedBox(height: 16),
                
                DropdownButtonFormField<int>(
                  value: selectedPeriod,
                  decoration: InputDecoration(
                    labelText: 'Period Number',
                    border: const OutlineInputBorder(),
                    prefixIcon: Icon(Icons.schedule, color: _accentColor),
                  ),
                  items: _timeSlots.map((slot) => DropdownMenuItem(
                    value: int.parse(slot['period']!),
                    child: Text('Period ${slot['period']} (${slot['start']} - ${slot['end']})'),
                  )).toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedPeriod = value!);
                  },
                ),
                const SizedBox(height: 16),
                
                DropdownButtonFormField<String>(
                  value: _classSubjects.contains(selectedSubject) ? selectedSubject : null,
                  decoration: InputDecoration(
                    labelText: 'Subject',
                    border: const OutlineInputBorder(),
                    prefixIcon: Icon(Icons.book, color: _accentColor),
                  ),
                  items: _classSubjects.map((subject) => DropdownMenuItem(
                    value: subject,
                    child: Text(subject),
                  )).toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedSubject = value!);
                  },
                ),
                const SizedBox(height: 16),
                
                DropdownButtonFormField<String>(
                  value: _classTeachers.any((t) => t['_id'] == selectedTeacherId) ? selectedTeacherId : null,
                  decoration: InputDecoration(
                    labelText: 'Teacher',
                    border: const OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person, color: _accentColor),
                  ),
                  items: _classTeachers.map<DropdownMenuItem<String>>((teacher) => DropdownMenuItem<String>(
                    value: teacher['_id'],
                    child: Text(teacher['name'] ?? 'Unknown Teacher'),
                  )).toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedTeacherId = value!);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (isEditing) {
                  _updatePeriodInSchedule(
                    editingIndex!,
                    selectedDay,
                    selectedPeriod,
                    selectedSubject,
                    selectedTeacherId,
                  );
                } else {
                  _addPeriodToSchedule(
                    selectedDay,
                    selectedPeriod,
                    selectedSubject,
                    selectedTeacherId,
                  );
                }
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isEditing ? Colors.orange : _primaryColor,
                foregroundColor: Colors.white,
              ),
              child: Text(isEditing ? 'Update Period' : 'Add Period'),
            ),
          ],
        ),
      ),
      );
  }

  // Add new method to update existing period
  void _updatePeriodInSchedule(
    int editingIndex,
    String day,
    int periodNumber,
    String subject,
    String teacherId,
  ) {
    // Check for conflicts with other periods (excluding the one being edited)
    final conflict = _periods.asMap().entries.any((entry) {
      final index = entry.key;
      final period = entry.value;
      return index != editingIndex &&
             period['dayOfWeek'] == day &&
             period['periodNumber'] == periodNumber;
    });
    
    if (conflict) {
      _showErrorSnackBar('Period conflict: $day Period $periodNumber already exists');
      return;
    }
    
    final timeSlot = _timeSlots.firstWhere((slot) => slot['period'] == periodNumber.toString());
    
    final updatedPeriod = {
      'dayOfWeek': day,
      'periodNumber': periodNumber,
      'subject': subject,
      'teacherId': teacherId,
      'startTime': timeSlot['start'],
      'endTime': timeSlot['end'],
    };
    
    setState(() {
      _periods[editingIndex] = updatedPeriod;
    });
    
    _showSuccessSnackBar('Period updated successfully');
  }

  void _addPeriodToSchedule(String day, int periodNumber, String subject, String teacherId) {
    final conflict = _periods.any((period) =>
        period['dayOfWeek'] == day && period['periodNumber'] == periodNumber);
    
    if (conflict) {
      _showErrorSnackBar('Period conflict: $day Period $periodNumber already exists');
      return;
    }
    
    final timeSlot = _timeSlots.firstWhere((slot) => slot['period'] == periodNumber.toString());
    
    final newPeriod = {
      'dayOfWeek': day,
      'periodNumber': periodNumber,
      'subject': subject,
      'teacherId': teacherId,
      'startTime': timeSlot['start'],
      'endTime': timeSlot['end'],
    };
    
    setState(() {
      _periods.add(newPeriod);
    });
    
    _showSuccessSnackBar('Period added successfully');
  }

  void _removePeriod(int index) {
    setState(() {
      _periods.removeAt(index);
    });
    _showSuccessSnackBar('Period removed');
  }

  Future<void> _createOrUpdateSchedule() async {
    if (_selectedClassId == null) {
      _showErrorSnackBar('Please select a class');
      return;
    }
    
    if (_periods.isEmpty) {
      _showErrorSnackBar('Please add at least one period');
      return;
    }
    
    setState(() => _isCreatingSchedule = true);
    
    try {
      if (_isUpdateMode && _scheduleIdToUpdate != null) {
        await _scheduleService.updateSchedule(
          scheduleId: _scheduleIdToUpdate!,
          classId: _selectedClassId!,
          periods: _periods,
        );
        _showSuccessSnackBar('Schedule updated successfully!');
      } else {
        await _scheduleService.createSchedule(
          classId: _selectedClassId!,
          periods: _periods,
        );
        _showSuccessSnackBar('Schedule created successfully!');
      }
      
      setState(() {
        _selectedClassId = null;
        _selectedClass = null;
        _periods.clear();
        _classTeachers.clear();
        _classSubjects.clear();
        _existingScheduleForClass = null;
        _isUpdateMode = false;
        _scheduleIdToUpdate = null;
      });
      
      await _loadExistingSchedules();
      
    } catch (e) {
      _showErrorSnackBar('Failed to ${_isUpdateMode ? 'update' : 'create'} schedule: ${e.toString()}');
    } finally {
      setState(() => _isCreatingSchedule = false);
    }
  }

  String _getTeacherName(String teacherId) {
    final teacher = _classTeachers.firstWhere(
      (t) => t['_id'] == teacherId,
      orElse: () => {'name': 'Unknown Teacher'},
    );
    return teacher['name'] ?? 'Unknown Teacher';
  }

  // Helper method to get teacher name for schedule display
  String _getTeacherNameForDisplay(dynamic teacherData) {
    if (teacherData == null) {
      return 'No Teacher Assigned';
    }
    
    // If teacherId is an object with teacher details
    if (teacherData is Map<String, dynamic>) {
      return teacherData['name'] ?? 'Unknown Teacher';
    }
    
    // If teacherId is just a string ID
    if (teacherData is String) {
      // If we have loaded teachers for this class, use them
      if (_classTeachers.isNotEmpty) {
        final teacher = _classTeachers.firstWhere(
          (t) => t['_id'] == teacherData,
          orElse: () => {'name': 'Teacher ID: $teacherData'},
        );
        return teacher['name'] ?? 'Unknown Teacher';
      }
      
      // Otherwise, just show the teacher ID
      return 'Teacher ID: $teacherData';
    }
    
    return 'Unknown Teacher';
  }

  // Helper method to get teacher ID from teacher data
  String _getTeacherIdFromData(dynamic teacherData) {
    if (teacherData == null) {
      return '';
    }
    
    // If teacherId is an object with teacher details
    if (teacherData is Map<String, dynamic>) {
      return teacherData['_id'] ?? '';
    }
    
    // If teacherId is just a string ID
    if (teacherData is String) {
      return teacherData;
    }
    
    return '';
  }

  // Helper method to organize periods by day for better display
  Map<String, List<Map<String, dynamic>>> _organizePeriodsByDay(List<dynamic> periods) {
    final Map<String, List<Map<String, dynamic>>> organizedPeriods = {};
    
    for (final day in _daysOfWeek) {
      organizedPeriods[day] = [];
    }
    
    for (final period in periods) {
      final dayOfWeek = period['dayOfWeek'] as String;
      if (organizedPeriods.containsKey(dayOfWeek)) {
        organizedPeriods[dayOfWeek]!.add(period as Map<String, dynamic>);
      }
    }
    
    // Sort periods by period number for each day
    for (final day in organizedPeriods.keys) {
      organizedPeriods[day]!.sort((a, b) => 
        (a['periodNumber'] as int).compareTo(b['periodNumber'] as int));
    }
    
    return organizedPeriods;
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Schedule Management',
          style: TextStyle(color:Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _primaryColor,
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, _primaryColor.withValues(alpha: 0.8)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInitialData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: const Color.fromARGB(255, 165, 158, 158),
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.view_list), text: 'View Schedules'),
            Tab(icon: Icon(Icons.add), text: 'Create/Edit'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _accentColor))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildViewSchedulesTab(),
                _buildCreateEditTab(),
              ],
            ),
    );
  }

  Widget _buildViewSchedulesTab() {
    return Column(
      children: [
        // Class selection for viewing
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Class to View Schedule',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedViewClassId,
                decoration: InputDecoration(
                  labelText: 'Select Class',
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(Icons.school, color: _accentColor),
                ),
                items: _availableClasses.map((classItem) {
                  return DropdownMenuItem<String>(
                    value: classItem['_id'],
                    child: Text(
                      '${classItem['name']} (Grade ${classItem['grade']}${classItem['section']})',
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    _selectClassForView(value);
                  }
                },
              ),
            ],
          ),
        ),
        
        // Schedule display
        Expanded(
          child: _selectedViewClassId == null
              ? _buildSelectClassForViewPrompt()
              : _isLoading
                  ? Center(child: CircularProgressIndicator(color: _accentColor))
                  : _viewSchedule == null
                      ? _buildNoScheduleFound()
                      : _buildScheduleDisplay(),
        ),
      ],
    );
  }

  Widget _buildSelectClassForViewPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.schedule, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Select a Class',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a class from the dropdown above to view its schedule',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildNoScheduleFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.schedule_outlined, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No Schedule Found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This class doesn\'t have a schedule yet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              _tabController.animateTo(1);
              if (_selectedViewClassId != null) {
                _selectClassForEdit(_selectedViewClassId!);
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Create Schedule'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleDisplay() {
    if (_viewSchedule == null) return Container();

    final periods = _viewSchedule!['periods'] as List<dynamic>? ?? [];
    final organizedPeriods = _organizePeriodsByDay(periods);
    final classInfo = _viewSchedule!['classId'] as Map<String, dynamic>? ?? {};
    
    return Column(
      children: [
        // Schedule header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _primaryColor.withValues(alpha: 0.1),
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.schedule, color: _primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${classInfo['name'] ?? 'Unknown Class'}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _primaryColor,
                          ),
                        ),
                        Text(
                          'Grade ${classInfo['grade'] ?? 'N/A'}${classInfo['section'] ?? ''} - ${classInfo['year'] ?? 'N/A'}',
                          style: TextStyle(
                            fontSize: 14,
                            color: _primaryColor.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _editSchedule,
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: _primaryColor, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${periods.length} periods across ${organizedPeriods.keys.where((day) => organizedPeriods[day]!.isNotEmpty).length} days',
                      style: TextStyle(
                        fontSize: 12,
                        color: _primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Schedule display - organized by days
        Expanded(
          child: periods.isEmpty
              ? const Center(child: Text('No periods in this schedule'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _daysOfWeek.length,
                  itemBuilder: (context, dayIndex) {
                    final day = _daysOfWeek[dayIndex];
                    final dayPeriods = organizedPeriods[day] ?? [];
                    
                    if (dayPeriods.isEmpty) {
                      return Container(); // Skip days with no periods
                    }
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Day header
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _accentColor.withValues(alpha: 0.2),
                                  _accentColor.withValues(alpha: 0.1),
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(8),
                                topRight: Radius.circular(8),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _accentColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.calendar_today, 
                                    color: Colors.white, 
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    day,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: _accentColor,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _accentColor,
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Text(
                                    '${dayPeriods.length} period${dayPeriods.length > 1 ? 's' : ''}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Periods for this day
                          ...dayPeriods.asMap().entries.map((entry) {
                            final index = entry.key;
                            final period = entry.value;
                            final isLast = index == dayPeriods.length - 1;
                            
                            return Container(
                              margin: EdgeInsets.only(
                                bottom: isLast ? 0 : 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: !isLast ? Border(
                                  bottom: BorderSide(
                                    color: Colors.grey.shade100,
                                    width: 1,
                                  ),
                                ) : null,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    // Period number with enhanced styling
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            _primaryColor,
                                            _primaryColor.withValues(alpha: 0.8),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: _primaryColor.withValues(alpha: 0.3),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          period['periodNumber'].toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    
                                    // Subject and time info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            period['subject'] ?? 'Unknown Subject',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.access_time,
                                                size: 14,
                                                color: Colors.grey.shade600,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${period['startTime']} - ${period['endTime']}',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey.shade600,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          // Teacher info with better styling
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: period['teacherId'] == null || 
                                                     period['teacherId'] == ''
                                                  ? Colors.red.shade50
                                                  : Colors.blue.shade50,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: period['teacherId'] == null || 
                                                       period['teacherId'] == ''
                                                    ? Colors.red.shade200
                                                    : Colors.blue.shade200,
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  period['teacherId'] == null || 
                                                  period['teacherId'] == ''
                                                      ? Icons.person_off
                                                      : Icons.person,
                                                  size: 12,
                                                  color: period['teacherId'] == null || 
                                                         period['teacherId'] == ''
                                                      ? Colors.red.shade600
                                                      : Colors.blue.shade600,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  _getTeacherNameForDisplay(period['teacherId']),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: period['teacherId'] == null || 
                                                           period['teacherId'] == ''
                                                        ? Colors.red.shade700
                                                        : Colors.blue.shade700,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCreateEditTab() {
    return Column(
      children: [
        // Class selection header for create/edit
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Colors.grey.shade50],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Step 1: Select Class',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedClassId,
                decoration: InputDecoration(
                  labelText: 'Select Class',
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(Icons.school, color: _accentColor),
                ),
                items: _availableClasses.map((classItem) {
                  return DropdownMenuItem<String>(
                    value: classItem['_id'],
                    child: Text(
                      '${classItem['name']} (Grade ${classItem['grade']}${classItem['section']})',
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    _selectClassForEdit(value);
                  }
                },
              ),
              if (_selectedClass != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: _primaryColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Selected: ${_selectedClass!['name']} | '
                          'Teachers: ${_classTeachers.length} | '
                          'Subjects: ${_classSubjects.length}',
                          style: TextStyle(color: _primaryColor),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_existingScheduleForClass != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.edit, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Update Mode: This class already has a schedule with ${_periods.length} periods',
                            style: const TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
        
        // Schedule building section
        Expanded(
          child: _selectedClassId == null
              ? _buildSelectClassPrompt()
              : _classTeachers.isEmpty || _classSubjects.isEmpty
                  ? _buildMissingDataPrompt()
                  : _buildScheduleBuilder(),
        ),
      ],
    );
  }

  Widget _buildSelectClassPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Select a Class to Begin',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a class from the dropdown above to start creating a schedule',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildMissingDataPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.warning, size: 80, color: Colors.orange.shade400),
          const SizedBox(height: 16),
          Text(
            'Class Setup Incomplete',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _classTeachers.isEmpty && _classSubjects.isEmpty
                ? 'This class needs both teachers and subjects assigned'
                : _classTeachers.isEmpty
                    ? 'This class needs teachers assigned'
                    : 'This class needs subjects assigned',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.people, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Teachers: ${_classTeachers.length}',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.book, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Subjects: ${_classSubjects.length}',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.settings),
            label: const Text('Go to Class Management'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleBuilder() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isUpdateMode ? 'Step 2: Update Schedule' : 'Step 2: Build Schedule',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _isUpdateMode 
                    ? 'Modify existing periods or add new ones'
                    : 'Add periods by selecting day, period number, subject, and teacher',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              if (_periods.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Current periods: ${_periods.length}',
                  style: TextStyle(
                    color: _primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
        
        Expanded(
          child: _periods.isEmpty
              ? _buildEmptyPeriodsView()
              : _buildPeriodsListView(),
        ),
        
        if (_periods.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _isCreatingSchedule ? null : _createOrUpdateSchedule,
              icon: _isCreatingSchedule
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(_isUpdateMode ? Icons.update : Icons.save),
              label: Text(_isCreatingSchedule 
                  ? (_isUpdateMode ? 'Updating...' : 'Creating...') 
                  : (_isUpdateMode ? 'Update Schedule' : 'Create Schedule')),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isUpdateMode ? Colors.orange : _primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyPeriodsView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.access_time, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            _isUpdateMode ? 'No Periods in Schedule' : 'No Periods Added',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isUpdateMode 
                ? 'This schedule doesn\'t have any periods yet. Add some periods to complete the schedule.'
                : 'Tap the + button to add your first period',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addPeriod,
            icon: const Icon(Icons.add),
            label: Text(_isUpdateMode ? 'Add First Period' : 'Add First Period'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodsListView() {
    final organizedPeriods = _organizePeriodsByDay(_periods);
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _daysOfWeek.length,
      itemBuilder: (context, dayIndex) {
        final day = _daysOfWeek[dayIndex];
        final dayPeriods = organizedPeriods[day] ?? [];
        
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day header with Add Period button
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: dayPeriods.isEmpty 
                        ? [Colors.grey.shade100, Colors.grey.shade50]
                        : [_accentColor.withValues(alpha: 0.2), _accentColor.withValues(alpha: 0.1)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: dayPeriods.isEmpty 
                            ? Colors.grey.shade400 
                            : _accentColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.calendar_today, 
                        color: Colors.white, 
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        day,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: dayPeriods.isEmpty 
                              ? Colors.grey.shade600 
                              : _accentColor,
                        ),
                      ),
                    ),
                    if (dayPeriods.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: _accentColor,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          '${dayPeriods.length} period${dayPeriods.length > 1 ? 's' : ''}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    // Add Period button for each day
                    Container(
                      decoration: BoxDecoration(
                        color: _primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _primaryColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.add, 
                          color: _primaryColor, 
                          size: 18,
                        ),
                        onPressed: () => _showAddPeriodDialog(preSelectedDay: day),
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        tooltip: 'Add Period to $day',
                      ),
                    ),
                  ],
                ),
              ),
              
              // Periods for this day or empty state
              if (dayPeriods.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.schedule_outlined,
                        size: 32,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No periods scheduled',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontStyle: FontStyle.italic,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => _showAddPeriodDialog(preSelectedDay: day),
                        icon: Icon(Icons.add, size: 16, color: _primaryColor),
                        label: Text(
                          'Add Period',
                          style: TextStyle(color: _primaryColor),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...dayPeriods.asMap().entries.map((entry) {
                  final index = entry.key;
                  final period = entry.value;
                  final globalIndex = _periods.indexOf(period);
                  final isLast = index == dayPeriods.length - 1;
                  
                  return Container(
                    margin: EdgeInsets.only(bottom: isLast ? 0 : 1),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: !isLast ? Border(
                        bottom: BorderSide(
                          color: Colors.grey.shade100,
                          width: 1,
                        ),
                      ) : null,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Period number
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _primaryColor,
                                  _primaryColor.withValues(alpha: 0.8),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: _primaryColor.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                period['periodNumber'].toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          
                          // Subject and details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  period['subject'],
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${period['startTime']} - ${period['endTime']}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Teacher: ${_getTeacherName(period['teacherId'])}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Action buttons
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Edit button
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    Icons.edit, 
                                    color: Colors.orange.shade600, 
                                    size: 18,
                                  ),
                                  onPressed: () => _editPeriod(globalIndex),
                                  padding: const EdgeInsets.all(6),
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                  tooltip: 'Edit Period',
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Delete button
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    Icons.delete_outline, 
                                    color: Colors.red.shade600, 
                                    size: 18,
                                  ),
                                  onPressed: () => _removePeriod(globalIndex),
                                  padding: const EdgeInsets.all(6),
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                  tooltip: 'Delete Period',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
            ],
          ),
        );
      },
    );
  }
}
