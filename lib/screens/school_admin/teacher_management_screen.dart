import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../utils/app_theme.dart';
import '../../services/teacher_service.dart'; 
import '../../services/class_services.dart'; // Import ClassService
import '../../utils/storage_util.dart'; 
import '../../utils/constants.dart';

class TeacherManagementScreen extends StatefulWidget {
  final User user;
  
  const TeacherManagementScreen({super.key, required this.user});

  @override
  // ignore: library_private_types_in_public_api
  _TeacherManagementScreenState createState() => _TeacherManagementScreenState();
}

class _TeacherManagementScreenState extends State<TeacherManagementScreen> {
  // Replace dummy data with API data
  List<Map<String, dynamic>> _teachers = [];
  List<Map<String, dynamic>> _filteredTeachers = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  
  // Initialize the teacher service
  late TeacherService _teacherService;
  late ClassService _classService; // Initialize ClassService
  
  // Theme colors
  late Color _primaryColor;
  late Color _accentColor;
  late Color _tertiaryColor;

  final _searchController = TextEditingController();
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadThemeColors();
    _teacherService = TeacherService(baseUrl: Constants.apiBaseUrl); // Use Constants for base URL
    _classService = ClassService(baseUrl: Constants.apiBaseUrl); // Use Constants for base URL
    _loadTeachers();
  }
  
  void _loadThemeColors() {
    _primaryColor = AppTheme.getPrimaryColor(AppTheme.defaultTheme);
    _accentColor = AppTheme.getAccentColor(AppTheme.defaultTheme);
    _tertiaryColor = AppTheme.getTertiaryColor(AppTheme.defaultTheme);
  }

  // Load teachers from API
  Future<void> _loadTeachers() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      final schoolId = await StorageUtil.getString('schoolId');
      if (schoolId == null || schoolId.isEmpty) {
        throw Exception('School ID not found. Please log in again.');
      }

      final teachers = await _teacherService.getAllTeachers();

      // Map API response to our expected data format
      final formattedTeachers = teachers.map((teacher) {
        final classes = teacher['classes'] is List
            ? (teacher['classes'] as List).map((c) => c['name']?.toString() ?? 'Unknown Class').toList()
            : <String>[];
        final subjects = teacher['teachingSubs'] is List
            ? List<String>.from(teacher['teachingSubs'])
            : <String>[];
        return {
          'id': teacher['_id'] ?? '',
          'name': teacher['name'] ?? 'Unknown',
          'email': teacher['email'] ?? '',
          'phone': teacher['phone'] ?? '',
          'subjects': subjects,
          'classes': classes,
          'joinDate': teacher['dateJoined'] != null
              ? _formatDate(teacher['dateJoined'])
              : (teacher['createdAt'] != null ? _formatDate(teacher['createdAt']) : 'Unknown'),
          'qualification': teacher['qualification'] ?? 'Not specified',
          'avatar': 'assets/images/teacher_default.png',
          'roles': teacher['roles'] ?? [],
        };
      }).toList();

      setState(() {
        _teachers = formattedTeachers;
        _filteredTeachers = List.from(_teachers);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load teachers: ${e.toString()}'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _loadTeachers,
            textColor: Colors.white,
          ),
          duration: const Duration(seconds: 10),
        ),
      );
    }
  }
  
  // Helper method to extract subjects from teacher data
  List<String> _extractSubjects(Map<String, dynamic> teacher) {
    if (teacher.containsKey('teachingSubs') && teacher['teachingSubs'] is List) {
      return List<String>.from(teacher['teachingSubs']);
    } else if (teacher.containsKey('subjects') && teacher['subjects'] is List) {
      return List<String>.from(teacher['subjects']);
    } else {
      return [];
    }
  }
  
  // Helper method to extract classes from teacher data
  List<String> _extractClasses(Map<String, dynamic> teacher) {
    if (teacher.containsKey('classes') && teacher['classes'] is List) {
      return List<String>.from(teacher['classes'].map((c) {
        if (c is String) return c;
        if (c is Map && c.containsKey('name')) return c['name'].toString();
        return "Unknown Class";
      }));
    }
    return [];
  }
  
  // Helper method to extract roles from teacher data
  List<String> _extractRoles(Map<String, dynamic> teacher) {
    if (teacher.containsKey('roles') && teacher['roles'] is List) {
      List<String> roles = List<String>.from(teacher['roles']);
      
      // Convert API role formats to display formats
      return roles.map((role) {
        // Convert CamelCase roles to spaced words (e.g., "ClassTeacher" to "Class Teacher")
        if (role == "ClassTeacher") return "Class Teacher";
        if (role == "SubjectTeacher") return "Subject Teacher";
        if (role == "HeadTeacher") return "Head Teacher";
        if (role == "DepartmentHead") return "Department Head";
        return role;
      }).toList();
    }
    return ['Subject Teacher']; // Default role
  }
  
  // Format date string from API
  String _formatDate(String dateStr) {
    try {
      final DateTime date = DateTime.parse(dateStr);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }
  
  // Refresh teachers data
  Future<void> _refreshTeachers() async {
    await _loadTeachers();
    _filterTeachers(_searchController.text);
  }

  void _filterTeachers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredTeachers = _teachers;
      } else {
        _filteredTeachers = _teachers
            .where((teacher) =>
                teacher['name'].toString().toLowerCase().contains(query.toLowerCase()) ||
                teacher['email'].toString().toLowerCase().contains(query.toLowerCase()) ||
                teacher['subjects'].toString().toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _applySubjectFilter(String subject) {
    setState(() {
      _selectedFilter = subject;
      if (subject == 'All') {
        _filteredTeachers = List.from(_teachers);
      } else {
        _filteredTeachers = _teachers
            .where((teacher) => (teacher['subjects'] as List<String>).contains(subject))
            .toList();
      }
    });
  }

  // Helper method to extract classes with names from teacher data
  Future<List<String>> _extractClassesWithNames(Map<String, dynamic> teacher) async {
    if (teacher.containsKey('classes') && teacher['classes'] is List) {
      final classIds = List<String>.from(teacher['classes']);
      final classNames = <String>[];
      for (final classId in classIds) {
        try {
          final className = await _classService.getClassNameById(classId);
          classNames.add(className);
        } catch (e) {
          classNames.add('Unknown Class');
        }
      }
      return classNames;
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Teacher Management', 
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          )
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
            onPressed: _refreshTeachers,
          ),
        ],
      ),
      body: _isLoading 
          ? Center(child: CircularProgressIndicator(color: _accentColor))
          : _hasError 
              ? _buildErrorView()
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.white, Colors.grey.shade100],
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
                          TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search teachers...',
                              prefixIcon: Icon(Icons.search, color: _accentColor),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16.0),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 0.0),
                              fillColor: Colors.grey.shade50,
                              filled: true,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16.0),
                                borderSide: BorderSide(color: Colors.grey.shade200),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16.0),
                                borderSide: BorderSide(color: _accentColor),
                              ),
                            ),
                            onChanged: _filterTeachers,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [_primaryColor, _primaryColor.withValues(alpha: 0.8)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _selectedFilter == 'All'
                                          ? 'All Teachers'
                                          : '$_selectedFilter Teachers',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${_filteredTeachers.length}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              OutlinedButton.icon(
                                icon: Icon(Icons.filter_list, color: _accentColor),
                                label: Text(
                                  'Filter', 
                                  style: TextStyle(color: _accentColor)
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: _accentColor),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                onPressed: _showFilterOptions,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(30),
                            topRight: Radius.circular(30),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.shade200,
                              blurRadius: 8,
                              offset: const Offset(0, -4),
                            ),
                          ],
                        ),
                        child: _teachers.isEmpty
                            ? _buildEmptyView()
                            : _filteredTeachers.isEmpty
                                ? _buildNoMatchView()
                                : ListView.builder(
                                    padding: const EdgeInsets.only(top: 20, left: 8, right: 8, bottom: 100), // Added bottom padding
                                    itemCount: _filteredTeachers.length,
                                    itemBuilder: (context, index) {
                                      final teacher = _filteredTeachers[index];
                                      // Create gradient colors based on index
                                      final List<Color> gradientColors;
                                      switch (index % 4) {
                                        case 0:
                                          gradientColors = [
                                            const Color(0xFF90CAF9),
                                            const Color(0xFFBBDEFB),
                                          ];
                                          break;
                                        case 1:
                                          gradientColors = [
                                            const Color(0xFF80CBC4),
                                            const Color(0xFFB2DFDB),
                                          ];
                                          break;
                                        case 2:
                                          gradientColors = [
                                            const Color(0xFFFFD54F),
                                            const Color(0xFFFFE082),
                                          ];
                                          break;
                                        case 3:
                                          gradientColors = [
                                            const Color(0xFFCE93D8),
                                            const Color(0xFFE1BEE7),
                                          ];
                                          break;
                                        default:
                                          gradientColors = [
                                            const Color(0xFF90CAF9),
                                            const Color(0xFFBBDEFB),
                                          ];
                                      }                          
                                      return Card(
                                        elevation: 3,
                                        shadowColor: gradientColors[0].withValues(alpha: 0.3),
                                        margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(18),
                                        ),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(18),
                                          onTap: () => _showTeacherDetails(teacher),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Header section with gradient
                                              Container(
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: gradientColors,
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  ),
                                                  borderRadius: const BorderRadius.only(
                                                    topLeft: Radius.circular(18),
                                                    topRight: Radius.circular(18),
                                                  ),
                                                ),
                                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.all(12),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        shape: BoxShape.circle,
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: gradientColors[0].withValues(alpha: 0.3),
                                                            blurRadius: 8,
                                                            offset: const Offset(0, 2),
                                                          ),
                                                        ],
                                                      ),
                                                      child: Text(
                                                        teacher['name'].toString().substring(0, 1),
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 18,
                                                          color: gradientColors[0],
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 16),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            teacher['name'] as String,
                                                            style: const TextStyle(
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 18,
                                                              color: Colors.white,
                                                              shadows: [
                                                                Shadow(
                                                                  offset: Offset(0, 1),
                                                                  blurRadius: 2,
                                                                  color: Color(0x50000000),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          const SizedBox(height: 4),
                                                          Text(
                                                            teacher['email'] as String,
                                                            style: const TextStyle(
                                                              color: Colors.white,
                                                              fontSize: 14,
                                                              shadows: [
                                                                Shadow(
                                                                  offset: Offset(0, 1),
                                                                  blurRadius: 2,
                                                                  color: Color(0x50000000),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius: BorderRadius.circular(16),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: gradientColors[0].withValues(alpha: 0.3),
                                                            blurRadius: 4,
                                                            offset: const Offset(0, 2),
                                                          ),
                                                        ],
                                                      ),
                                                      
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              // Body section
                                              Padding(
                                                padding: const EdgeInsets.all(16.0),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Icon(Icons.book, color: gradientColors[0], size: 20),
                                                        const SizedBox(width: 6),
                                                        const Text(
                                                          'Teaching Subjects:',
                                                          style: TextStyle(
                                                            fontWeight: FontWeight.w600,
                                                            fontSize: 15,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Wrap(
                                                      spacing: 8,
                                                      runSpacing: 8,
                                                      children: (teacher['subjects'] as List<String>)
                                                          .map((subject) => Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                                decoration: BoxDecoration(
                                                                  gradient: LinearGradient(
                                                                    colors: [
                                                                      gradientColors[0].withValues(alpha: 0.2),
                                                                      gradientColors[1].withValues(alpha: 0.2),
                                                                    ],
                                                                    begin: Alignment.topLeft,
                                                                    end: Alignment.bottomRight,
                                                                  ),
                                                                  borderRadius: BorderRadius.circular(16),
                                                                  border: Border.all(color: gradientColors[0].withValues(alpha: 0.3)),
                                                                ),
                                                                child: Text(
                                                                  subject,
                                                                  style: TextStyle(
                                                                    fontSize: 12, 
                                                                    color: gradientColors[0].withValues(alpha: 0.8),
                                                                    fontWeight: FontWeight.w500,
                                                                  ),
                                                                ),
                                                              ))
                                                          .toList(),
                                                    ),
                                                    const SizedBox(height: 16),
                                                    Row(
                                                      children: [
                                                        Icon(Icons.school, color: gradientColors[0], size: 20),
                                                        const SizedBox(width: 6),
                                                        const Text(
                                                          'Classes:',
                                                          style: TextStyle(
                                                            fontWeight: FontWeight.w600,
                                                            fontSize: 15,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Wrap(
                                                      spacing: 8,
                                                      runSpacing: 8,
                                                      children: (teacher['classes'] as List<String>)
                                                          .map((className) => Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                                decoration: BoxDecoration(
                                                                  color: gradientColors[0].withValues(alpha: 0.1),
                                                                  borderRadius: BorderRadius.circular(16),
                                                                  border: Border.all(color: gradientColors[0].withValues(alpha: 0.2)),
                                                                ),
                                                                child: Text(
                                                                  className,
                                                                  style: TextStyle(
                                                                    fontSize: 12, 
                                                                    color: gradientColors[0].withValues(alpha: 0.8),
                                                                    fontWeight: FontWeight.w500,
                                                                  ),
                                                                ),
                                                              ))
                                                          .toList(),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              // Footer with actions
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade50,
                                                  borderRadius: const BorderRadius.only(
                                                    bottomLeft: Radius.circular(18),
                                                    bottomRight: Radius.circular(18),
                                                  ),
                                                  border: Border(
                                                    top: BorderSide(
                                                      color: gradientColors[0].withValues(alpha: 0.2),
                                                      width: 1,
                                                    ),
                                                  ),
                                                ),
                                                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    TextButton.icon(
                                                      icon: Icon(Icons.edit, size: 18, color: gradientColors[0]),
                                                      label: Text('Edit', style: TextStyle(color: gradientColors[0])),
                                                      onPressed: () => _showEditTeacherDialog(teacher),
                                                    ),
                                                    Row(
                                                      children: [
                                                        // Material(
                                                        //   color: Colors.transparent,
                                                        //   shape: const CircleBorder(),
                                                        //   clipBehavior: Clip.antiAlias,
                                                        //   child: IconButton(
                                                        //     icon: Icon(Icons.class_, color: Colors.orange.shade400),
                                                        //     onPressed: () => _showAssignClassesDialog(teacher),
                                                        //     tooltip: "Assign Classes",
                                                        //   ),
                                                        // ),
                                                        Material(
                                                          color: Colors.transparent,
                                                          shape: const CircleBorder(),
                                                          clipBehavior: Clip.antiAlias,
                                                          child: IconButton(
                                                            icon: Icon(Icons.analytics, color: Colors.purple.shade400),
                                                            onPressed: () => _showTeacherPerformance(teacher),
                                                            tooltip: "Performance",
                                                          ),
                                                        ),
                                                        PopupMenuButton(
                                                          icon: const Icon(
                                                            Icons.more_vert,
                                                            color: Colors.grey,
                                                          ),
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius: BorderRadius.circular(12),
                                                          ),
                                                          itemBuilder: (context) => [
                                                            const PopupMenuItem(
                                                              value: 'delete',
                                                              child: Row(
                                                                children: [
                                                                  Icon(Icons.delete, color: Colors.red, size: 20),
                                                                  SizedBox(width: 8),
                                                                  Text('Delete Teacher'),
                                                                ],
                                                              ),
                                                            ),
                                                          ],
                                                          onSelected: (value) {
                                                            _handleMenuAction(value, teacher);
                                                          },
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        );
                                      },
                                    ),
                      ),
                    ),
                  ],
                ),
      backgroundColor: Colors.white,
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_accentColor, _accentColor.withValues(alpha: 0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: _accentColor.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _showAddTeacherDialog,
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text("Add Teacher", style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
  
  // Build error view for API failures
  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.red.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load teachers',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadTeachers,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  // Build empty view when no teachers are available
  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_outline,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Teachers Found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Get started by adding your first teacher',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddTeacherDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Teacher'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
  
  // Build view for when no teachers match filter criteria
  Widget _buildNoMatchView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.filter_list_off,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No teachers match your filter',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try changing your search criteria',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.clear),
            label: const Text('Clear Filters'),
            onPressed: () {
              setState(() {
                _searchController.clear();
                _selectedFilter = 'All';
                _filteredTeachers = List.from(_teachers);
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
            ),
          ),
        ],
      ),
    );
  }
  
  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              spreadRadius: 1,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_accentColor, _accentColor.withValues(alpha: 0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: _accentColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ],
                  ),
                  child: const Icon(
                    Icons.filter_list,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Filter Teachers',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Filter by Subject',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                'All',
                'Mathematics',
                'Physics',
                'Chemistry',
                'Biology',
                'English',
                'History',
                'Geography',
                'Computer Science',
                'Social Studies'
              ].map((subject) => _buildFilterChip(
                label: subject,
                selected: _selectedFilter == subject,
                onSelected: (selected) {
                  Navigator.pop(context);
                  _applySubjectFilter(subject);
                },
                color: _accentColor,
              )).toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Helper method to create consistent filter chips
  Widget _buildFilterChip({
    required String label, 
    required bool selected, 
    required Function(bool) onSelected, 
    required Color color
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      backgroundColor: Colors.white,
      selectedColor: color.withValues(alpha: 0.15),
      checkmarkColor: color.withValues(alpha: 0.8),
      labelStyle: TextStyle(
        color: selected ? color : Colors.black87,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(color: selected ? color : Colors.grey.shade300),
      elevation: 1,
      shadowColor: Colors.grey.shade200,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  void _showTeacherDetails(Map<String, dynamic> teacher) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Colorful header
              Container(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_accentColor, _accentColor.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: _accentColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.white,
                          child: Text(
                            teacher['name'].toString().substring(0, 1),
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: _accentColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                teacher['name'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 24,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                teacher['qualification'] as String,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  'Teacher ID: ${teacher['id']}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Content area with details
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Contact information
                      _buildInfoSection(
                        'Contact Information',
                        Icons.contact_mail,
                        [
                          _buildInfoRow(Icons.email, 'Email', teacher['email'] as String),
                          _buildInfoRow(Icons.phone, 'Phone', teacher['phone'] as String),
                          _buildInfoRow(Icons.calendar_today, 'Joined', teacher['joinDate'] as String),
                        ],
                        _primaryColor,
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Teacher Roles
                      _buildInfoSection(
                        'Teacher Roles',
                        Icons.badge,
                        [
                          Wrap(
                            spacing: 8,
                            children: ((teacher['roles'] ?? <String>[]) as List<dynamic>).map((role) => Chip(
                                  label: Text(role.toString()),
                                  backgroundColor: _tertiaryColor.withValues(alpha: 0.2),
                                )).toList(),
                          ),
                        ],
                        _tertiaryColor,
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Teaching Subjects
                      _buildInfoSection(
                        'Teaching Subjects',
                        Icons.book,
                        [
                          Wrap(
                            spacing: 8,
                            children: (teacher['subjects'] as List<String>).map((subject) => Chip(
                                  label: Text(subject),
                                  backgroundColor: _primaryColor.withValues(alpha: 0.2),
                                )).toList(),
                          ),
                        ],
                        _primaryColor,
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Assigned Classes
                      _buildInfoSection(
                        'Assigned Classes',
                        Icons.class_,
                        [
                          Wrap(
                            spacing: 8,
                            children: (teacher['classes'] as List<String>).map((className) => Chip(
                                  label: Text(className),
                                  backgroundColor: _accentColor.withValues(alpha: 0.2),
                                )).toList(),
                          ),
                        ],
                        _accentColor,
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Performance summary
                      if (teacher.containsKey('performance')) ...[
                        _buildPerformanceSummary(teacher['performance'] as Map<String, dynamic>),
                        const SizedBox(height: 32),
                      ],
                      
                      // Action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.edit),
                            label: const Text('Edit'),
                            onPressed: () {
                              Navigator.pop(context);
                              _showEditTeacherDialog(teacher);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),

                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      );
  }
  
  Widget _buildInfoSection(String title, IconData icon, List<Widget> children, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.grey[500],
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildPerformanceSummary(Map<String, dynamic> performance) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.blue.shade100.withValues(alpha: 0.3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade100.withValues(alpha: 0.5),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }
  

  void _showAddTeacherDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final dateJoinedController = TextEditingController(text: DateTime.now().toString().substring(0, 10));
    final teacherIdController = TextEditingController(); // Added for Teacher ID
    
    // Selected subjects and roles
    final selectedSubjects = <String>{};
    final selectedRoles = <String>{'SubjectTeacher'}; // Default role
    bool salaryPaid = false;
    
    // Track form validation errors
    Map<String, String?> errors = {
      'name': null,
      'email': null,
      'teacherId': null, // Added for Teacher ID validation
    };

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
            child: Column(
              children: [
                // Dialog header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _primaryColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.person_add, color: _primaryColor),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Add New Teacher',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                
                // Form fields in scrollable area
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Teacher Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Name field
                        TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: 'Full Name*',
                            hintText: 'Enter teacher\'s full name',
                            errorText: errors['name'],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: const Icon(Icons.person),
                          ),
                          onChanged: (value) {
                            setState(() {
                              errors['name'] = value.isEmpty ? 'Name is required' : null;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Email field
                        TextField(
                          controller: emailController,
                          decoration: InputDecoration(
                            labelText: 'Email*',
                            hintText: 'Enter email address',
                            errorText: errors['email'],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: const Icon(Icons.email),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (value) {
                            setState(() {
                              if (value.isEmpty) {
                                errors['email'] = 'Email is required';
                              } else if (!value.contains('@')) {
                                errors['email'] = 'Enter a valid email address';
                              } else {
                                errors['email'] = null;
                              }
                            });
                          },
                        
                        ),
                        const SizedBox(height: 16),
                        
                        // Teacher ID field
                        TextField(
                          controller: teacherIdController,
                          decoration: InputDecoration(
                            labelText: 'Teacher ID*',
                            hintText: 'Enter unique teacher ID',
                            errorText: errors['teacherId'],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: const Icon(Icons.badge_outlined),
                          ),
                          onChanged: (value) {
                            setState(() {
                              errors['teacherId'] = value.isEmpty ? 'Teacher ID is required' : null;
                            });
                          },
                        ),
                        const SizedBox(height: 16),

                        // Phone number
                        TextField(
                          controller: phoneController,
                          decoration: InputDecoration(
                            labelText: 'Phone Number',
                            hintText: 'Enter phone number',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: const Icon(Icons.phone),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),
                        
                        // Date joined
                        TextField(
                          controller: dateJoinedController,
                          decoration: InputDecoration(
                            labelText: 'Date Joined',
                            hintText: 'YYYY-MM-DD',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: const Icon(Icons.calendar_today),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.calendar_month),
                              onPressed: () async {
                                final DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) {
                                  setState(() {
                                    dateJoinedController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                                  });
                                }
                              },
                            ),
                          ),
                          keyboardType: TextInputType.datetime,
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        
                        // Teaching subjects section
                        const Text(
                          'Teaching Subjects:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            'Mathematics',
                            'Physics',
                            'Chemistry',
                            'Biology',
                            'English',
                            'History',
                            'Geography',
                            'Computer Science',
                            'Social Studies'
                          ].map((subject) => FilterChip(
                                label: Text(subject),
                                selected: selectedSubjects.contains(subject),
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      selectedSubjects.add(subject);
                                    } else {
                                      selectedSubjects.remove(subject);
                                    }
                                  });
                                },
                                checkmarkColor: _accentColor,
                                selectedColor: _accentColor.withValues(alpha: 0.15),
                                backgroundColor: Colors.grey.shade50,
                                side: BorderSide(color: Colors.grey.shade300),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              )).toList(),
                        ),
                        const SizedBox(height: 24),
                        
                        // Teacher roles section
                        // const Text(
                        //   'Teacher Roles:',
                        //   style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        // ),
                        // const SizedBox(height: 8),
                        // const Text(
                        //   'Select one or more roles for the teacher',
                        //   style: TextStyle(fontSize: 12, color: Colors.grey),
                        // ),
                        const SizedBox(height: 12),
                        // Wrap(
                        //   spacing: 8,
                        //   runSpacing: 8,
                        //   children: [
                        //     'ClassTeacher',
                        //     'SubjectTeacher',
                        //     'DepartmentHead',
                        //     'HeadTeacher',
                        //   ].map((role) => FilterChip(
                        //         label: Text(_formatRoleForDisplay(role)),
                        //         selected: selectedRoles.contains(role),
                        //         onSelected: (selected) {
                        //           setState(() {
                        //             if (selected) {
                        //               selectedRoles.add(role);
                        //             } else {
                        //               // Ensure at least one role is selected
                        //               if (selectedRoles.length > 1) {
                        //                 selectedRoles.remove(role);
                        //               }
                        //             }
                        //           });
                        //         },
                        //         checkmarkColor: _accentColor,
                        //         selectedColor: _accentColor.withValues(alpha: 0.15),
                        //         backgroundColor: Colors.grey.shade50,
                        //         side: BorderSide(color: Colors.grey.shade300),
                        //         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        //       )).toList(),
                        // ),
                      ],
                    ),
                  ),
                ),
                
                // Actions area
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade400),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.person_add),
                        label: const Text('Add Teacher'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          elevation: 2,
                        ),
                        onPressed: () async {
                          // Validate required fields
                          bool hasErrors = false;
                          setState(() {
                            errors['name'] = nameController.text.isEmpty ? 'Name is required' : null;
                            if (emailController.text.isEmpty) {
                              errors['email'] = 'Email is required';
                            } else if (!emailController.text.contains('@')) {
                              errors['email'] = 'Enter a valid email address';
                            } else {
                              errors['email'] = null;
                            }
                            errors['teacherId'] = teacherIdController.text.isEmpty ? 'Teacher ID is required' : null;
                            
                            hasErrors = errors.values.any((error) => error != null);
                          });
                          
                          if (hasErrors) {
                            return; // Don't proceed if there are validation errors
                          }

                          try {
                            Navigator.pop(context);
                            setState(() => _isLoading = true);
                            
                            // Show progress message
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    const Text('Creating teacher account...'),
                                  ],
                                ),
                                backgroundColor: _primaryColor,
                                duration: const Duration(seconds: 5),
                              ),
                            );
                            
                            await _teacherService.createTeacher(
                              name: nameController.text,
                              email: emailController.text,
                              phone: phoneController.text,
                              dateJoined: dateJoinedController.text,
                              teacherId: teacherIdController.text,
                              salaryPaid: salaryPaid,
                              subjects: selectedSubjects.isNotEmpty ? selectedSubjects.toList() : null,
                              classes: [],
                              roles: selectedRoles.toList(),
                            );
                            
                            await _refreshTeachers();
                            
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Teacher account created successfully! Teacher can now login with their email and school secret key.'),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 4),
                              ),
                            );
                          } catch (e) {
                            setState(() => _isLoading = false);
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            
                            String errorMessage = e.toString();
                            if (errorMessage.contains('School secret key not found')) {
                              errorMessage = 'School secret key not found. Please contact administrator.';
                            } else if (errorMessage.contains('Email already exists')) {
                              errorMessage = 'A user with this email already exists.';
                            }
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to create teacher: $errorMessage'),
                                backgroundColor: Colors.red,
                                action: SnackBarAction(
                                  label: 'Retry',
                                  onPressed: () => _showAddTeacherDialog(),
                                  textColor: Colors.white,
                                ),
                                duration: const Duration(seconds: 8),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      );
  }
  
  // Helper method to format API role names for display
  String _formatRoleForDisplay(String apiRole) {
    if (apiRole == "ClassTeacher") return "Class Teacher";
    if (apiRole == "SubjectTeacher") return "Subject Teacher";
    if (apiRole == "HeadTeacher") return "Head Teacher";
    if (apiRole == "DepartmentHead") return "Department Head";
    return apiRole;
  }

  // Update the show edit teacher dialog to use the API
  void _showEditTeacherDialog(Map<String, dynamic> teacher) {
    final nameController = TextEditingController(text: teacher['name'] as String);
    final phoneController = TextEditingController(text: teacher['phone'] as String);
    
    // Selected subjects
    final selectedSubjects = Set<String>.from(teacher['subjects'] as List<String>);
    bool salaryPaid = teacher['salaryPaid'] ?? false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Teacher'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                  keyboardType: TextInputType.phone,
                ),

                const SizedBox(height: 24),
                const Text(
                  'Teaching Subjects:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    'Mathematics',
                    'Physics',
                    'Chemistry',
                    'Biology',
                    'English',
                    'History',
                    'Geography',
                    'Computer Science',
                    'Social Studies'
                  ].map((subject) => FilterChip(
                        label: Text(subject),
                        selected: selectedSubjects.contains(subject),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              selectedSubjects.add(subject);
                            } else {
                              selectedSubjects.remove(subject);
                            }
                          });
                        },
                      )).toList(),
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
              onPressed: () async {
                if (nameController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all required fields')),
                  );
                  return;
                }

                try {
                  Navigator.pop(context);
                  setState(() => _isLoading = true);
                  
                  final teacherIdToUpdate = teacher['id'].toString(); // This 'id' is now MongoDB '_id'
                  
                  await _teacherService.updateTeacher(
                    id: teacherIdToUpdate, 
                    name: nameController.text,
                    phone: phoneController.text,
                    salaryPaid: salaryPaid,
                    teachingSubs: selectedSubjects.toList(),
                  );
                  
                  await _refreshTeachers();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Teacher updated successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to update teacher: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
      );
  }
  
  void _showAssignClassesDialog(Map<String, dynamic> teacher) async {
    try {
      setState(() => _isLoading = true);
      final allClasses = await _classService.getAllClasses();
      final selectedClassIds = Set<String>.from(teacher['classes'] as List<String>);

      setState(() => _isLoading = false);

      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text('Assign Classes to ${teacher['name']}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: allClasses.map((classData) {
                  final classId = classData['_id'] ?? ''; // Use class ID
                  final className = classData['name'] ?? 'Unknown Class';
                  return CheckboxListTile(
                    title: Text(className),
                    value: selectedClassIds.contains(classId),
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          selectedClassIds.add(classId);
                        } else {
                          selectedClassIds.remove(classId);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    Navigator.pop(context);
                    setState(() => _isLoading = true);

                    await _teacherService.updateTeacherAssignments(
                      id: teacher['id'].toString(),
                      classIds: selectedClassIds.toList(), // Pass class IDs in the required format
                    );

                    await _refreshTeachers();

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Classes assigned successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    setState(() => _isLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to assign classes: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load classes: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDeleteConfirmationDialog(Map<String, dynamic> teacher) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete ${teacher['name']}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                final teacherIdToDelete = teacher['id'].toString();
                Navigator.pop(context);
                setState(() => _isLoading = true);
                
                await _teacherService.deleteTeacher(teacherIdToDelete);
                await _refreshTeachers();
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Teacher deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                setState(() => _isLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete teacher: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  
  void _showTeacherPerformance(Map<String, dynamic> teacher) async {
    setState(() => _isLoading = true);
    
    try {
      final teacherId = teacher['id'].toString();
      // Use the TeacherService to get performance data
      final performance = await _teacherService.getTeacherPerformance(teacherId);
      
      setState(() => _isLoading = false);
      
      // Show simple dialog with only performance data
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Performance: ${teacher['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Classes: ${performance['totalClasses']}'),
              const SizedBox(height: 8),
              Text('Average Attendance: ${performance['avgAttendancePct']}%'),
              const SizedBox(height: 8),
              Text('Average Grade: ${performance['avgClassGrade']}'),
              const SizedBox(height: 8),
              Text('Pass Rate: ${performance['avgPassPct']}%'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load teacher performance: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
 
  
  void _handleMenuAction(String action, Map<String, dynamic> teacher) {
    switch (action) {
      case 'view':
        _showTeacherDetails(teacher);
        break;
      case 'edit':
        _showEditTeacherDialog(teacher);
        break;
      // case 'assign':
      //   _showAssignClassesDialog(teacher);
      //   break;
      case 'performance':
        _showTeacherPerformance(teacher);
        break;
      case 'delete':
        _showDeleteConfirmationDialog(teacher);
        break;
    }
  }
}