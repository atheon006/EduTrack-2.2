import 'package:flutter/material.dart';
import '../../services/analytics_service.dart';
import '../../services/class_services.dart';
import '../../utils/constants.dart'; // Import constants for base URL

class AnalyticsDashboard extends StatefulWidget {
  final String? preselectedClassId;
  
  const AnalyticsDashboard({super.key, this.preselectedClassId});

  @override
  State<AnalyticsDashboard> createState() => _AnalyticsDashboardState();
}

class _AnalyticsDashboardState extends State<AnalyticsDashboard>
    with TickerProviderStateMixin {
  late final AnalyticsService _analyticsService;
  late final ClassService _classService;
  List<Map<String, dynamic>> _classes = [];
  String? _selectedClassId;
  List<Map<String, dynamic>> _attendanceData = [];
  Map<String, dynamic>? _gradeAnalytics;
  String? _selectedSubject;
  List<String> _availableSubjects = [];
  bool _isLoading = true;
  
  // Date selection variables
  DateTime? _startDate;
  DateTime? _endDate;
  bool _canLoadAnalytics = false;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _analyticsService = AnalyticsService(baseUrl:  Constants.apiBaseUrl);
    _classService = ClassService(baseUrl:  Constants.apiBaseUrl);
    
    // Initialize tab controller
    _tabController = TabController(length: 2, vsync: this);
    
    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack));
    
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final classes = await _classService.getAllClasses();
      setState(() {
        _classes = classes;
        _isLoading = false;
        
        // Use preselected class ID if provided
        if (widget.preselectedClassId != null) {
          _selectedClassId = widget.preselectedClassId;
          _loadClassSubjects();
          _checkCanLoadAnalytics();
          
          // If it's a preselected class, initialize with current month date range
          final now = DateTime.now();
          _startDate = DateTime(now.year, now.month, 1);
          _endDate = DateTime(now.year, now.month + 1, 0);
          
          // Load analytics data if we have the class ID
          if (_canLoadAnalytics) {
            _loadAttendanceData();
          }
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading classes: $e')),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  // Future<void> _loadInitialData() async {
  //   try {
  //     final classes = await _classService.getAllClasses();
  //     setState(() {
  //       _classes = classes;
  //       _isLoading = false;
  //     });
  //   } catch (e) {
  //     setState(() {
  //       _isLoading = false;
  //     });
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Error loading classes: $e')),
  //     );
  //   }
  // }

  void _checkCanLoadAnalytics() {
    setState(() {
      _canLoadAnalytics = _selectedClassId != null && _startDate != null && _endDate != null;
    });
  }

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
      _checkCanLoadAnalytics();
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
      });
      _checkCanLoadAnalytics();
    }
  }

  Future<void> _loadAttendanceData() async {
    if (!_canLoadAnalytics) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final startDateStr = '${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}';
      final endDateStr = '${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}';

      final attendanceData = await _analyticsService.getAttendanceAnalytics(
        classId: _selectedClassId!,
        startDate: startDateStr,
        endDate: endDateStr,
      );

      setState(() {
        _attendanceData = attendanceData;
        _isLoading = false;
      });
      
      // Trigger animations after data loads
      _fadeController.forward();
      _slideController.forward();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error loading attendance data: $e');
    }
  }

  Future<void> _loadClassSubjects() async {
    if (_selectedClassId == null) return;

    try {
      final classData = await _classService.getClassById(_selectedClassId!);
      if (classData.containsKey('subjects')) {
        setState(() {
          _availableSubjects = List<String>.from(classData['subjects']);
          _selectedSubject = null;
          _gradeAnalytics = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading subjects: $e')),
      );
    }
  }

  Future<void> _loadGradeAnalytics() async {
    if (_selectedClassId == null || _selectedSubject == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final gradeData = await _analyticsService.getGradeAnalytics(
        classId: _selectedClassId!,
        subject: _selectedSubject!,
      );

      setState(() {
        _gradeAnalytics = gradeData;
        _isLoading = false;
      });
      
      // Trigger animations
      _fadeController.forward();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error loading grade analytics: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        bottom: _isLoading ? null : TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(
              icon: Icon(Icons.grade),
              text: 'Grade Analytics',
            ),
            Tab(
              icon: Icon(Icons.calendar_today),
              text: 'Attendance Data',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading analytics...',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Header and Controls Section (always visible)
                Container(
                  color: Colors.grey.shade50,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildHeaderSection(theme),
                            const SizedBox(height: 24),
                            _buildControlsSection(theme),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Grade Analytics Tab
                      _buildGradeAnalyticsTab(theme),
                      // Attendance Data Tab
                      _buildAttendanceDataTab(theme),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeaderSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade200,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.analytics_outlined,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'School Analytics',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Track performance and attendance metrics',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeAnalyticsTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subject selector for grade analytics
          if (_availableSubjects.isNotEmpty) ...[
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 8,
                  ),
                ],
              ),
              child: DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Select Subject for Grade Analytics',
                  prefixIcon: Icon(Icons.subject_outlined, color: Colors.orange.shade600),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                value: _selectedSubject,
                items: _availableSubjects.map((subject) {
                  return DropdownMenuItem<String>(
                    value: subject,
                    child: Text(subject),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedSubject = value;
                  });
                  _loadGradeAnalytics();
                },
              ),
            ),
          ],

          // Grade Analytics Card
          if (_gradeAnalytics != null)
            _buildGradeAnalyticsCard(theme)
          else if (_availableSubjects.isNotEmpty)
            _buildEmptyState(
              icon: Icons.grade,
              title: 'Select a Subject',
              message: 'Choose a subject from the dropdown above to view grade analytics',
            )
          else
            _buildEmptyState(
              icon: Icons.class_outlined,
              title: 'Select a Class',
              message: 'Please select a class first to view subjects and grade analytics',
            ),
        ],
      ),
    );
  }

  Widget _buildAttendanceDataTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date selection and load button
          Row(
            children: [
              Expanded(child: _buildDateSelector('Start Date', _startDate, _selectStartDate)),
              const SizedBox(width: 16),
              Expanded(child: _buildDateSelector('End Date', _endDate, _selectEndDate)),
            ],
          ),
          const SizedBox(height: 16),

          // Load button
          if (_canLoadAnalytics)
            Container(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _loadAttendanceData,
                icon: const Icon(Icons.analytics),
                label: const Text('Load Attendance Analytics'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          const SizedBox(height: 24),

          // Attendance Section
          _buildAttendanceSection(theme),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Configuration',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 16),
        
        // Class selector with improved design
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'Select Class',
              prefixIcon: Icon(Icons.class_outlined, color: Colors.blue.shade600),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            value: _selectedClassId,
            items: _classes.map((classData) {
              return DropdownMenuItem<String>(
                value: classData['_id'],
                child: Text('${classData['name']} - ${classData['grade']}'),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedClassId = value;
                _attendanceData = [];
                _gradeAnalytics = null;
                _selectedSubject = null;
                _availableSubjects = [];
              });
              _checkCanLoadAnalytics();
              _loadClassSubjects();
              _fadeController.reset();
              _slideController.reset();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDateSelector(String label, DateTime? date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
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
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              date != null
                  ? '${date.day}/${date.month}/${date.year}'
                  : 'Select $label',
              style: TextStyle(
                fontSize: 16,
                color: date != null ? Colors.grey.shade800 : Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradeAnalyticsCard(ThemeData theme) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade500, Colors.orange.shade300],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
           
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.grade, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Grade Analytics - $_selectedSubject',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildAnalyticsGrid(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      childAspectRatio: 1.2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        _buildAnalyticsGridItem('Count', '${_gradeAnalytics!['count']}', Icons.people),
        _buildAnalyticsGridItem('Average', '${_gradeAnalytics!['average']}', Icons.trending_up),
        _buildAnalyticsGridItem('Highest', '${_gradeAnalytics!['highest']}', Icons.star),
        _buildAnalyticsGridItem('Lowest', '${_gradeAnalytics!['lowest']}', Icons.trending_down),
        _buildAnalyticsGridItem('Median', '${_gradeAnalytics!['median']}', Icons.bar_chart),
        Container(), // Empty container for grid alignment
      ],
    );
  }

  Widget _buildAnalyticsGridItem(String label, String value, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceSection(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _attendanceData.isEmpty
          ? Container(
              height: 200,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _canLoadAnalytics ? Icons.analytics_outlined : Icons.info_outline,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _canLoadAnalytics 
                          ? 'Click "Load Attendance Analytics" to view data'
                          : 'Select a class and date range to view attendance analytics',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_month, color: Colors.blue.shade600),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Period: ${_startDate != null ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}' : ''} - ${_endDate != null ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}' : ''}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _attendanceData.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: Colors.grey.shade200,
                    ),
                    itemBuilder: (context, index) {
                      final data = _attendanceData[index];
                      final date = DateTime.parse(data['date']);
                      final attendancePct = data['attendancePct'];
                      
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _getAttendanceColor(attendancePct).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.calendar_today,
                            color: _getAttendanceColor(attendancePct),
                            size: 16,
                          ),
                        ),
                        title: Text(
                          '${date.day}/${date.month}/${date.year}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: const Text('Daily Attendance'),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getAttendanceColor(attendancePct),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '$attendancePct%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Color _getAttendanceColor(int percentage) {
    if (percentage >= 90) return Colors.green.shade600;
    if (percentage >= 75) return Colors.orange.shade600;
    return Colors.red.shade600;
  }

  // ...existing code... (keep the existing _buildAnalyticsItem method for compatibility)
  Widget _buildAnalyticsItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}
