import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/assignment_model.dart';
import '../../services/assignment_service.dart';
import '../../services/teacher_service.dart';
import '../../services/class_services.dart';
import 'package:intl/intl.dart';
import '../../utils/constants.dart'; // Import constants for base URL

class TeacherAssignmentsScreen extends StatefulWidget {
  final User user;
  final Map<String, dynamic>? selectedClass;

  const TeacherAssignmentsScreen({
    super.key, 
    required this.user, 
    this.selectedClass,
  });

  @override
  // ignore: library_private_types_in_public_api
  _TeacherAssignmentsScreenState createState() => _TeacherAssignmentsScreenState();
}

class _TeacherAssignmentsScreenState extends State<TeacherAssignmentsScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  late TabController _tabController;
  List<Assignment> _assignments = [];
  final List<Map<String, dynamic>> _classes = [];
  Map<String, dynamic>? _selectedClass;
  String? _error;
  late TeacherService _teacherService;
  late ClassService _classService;
  
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');
  
  // Light theme colors
  final Color _primaryColor = const Color(0xFF5E63B6);
  final Color _backgroundColor = const Color(0xFFF5F7FA);
  final Color _cardColor = Colors.white;
  final Color _textPrimaryColor = const Color(0xFF333333);
  final Color _textSecondaryColor = const Color(0xFF717171);
  
  // Status colors for light theme
  final Map<String, Color> _statusColors = {
    'Active': const Color(0xFF43A047),
    'Scheduled': const Color(0xFF2196F3),
    'Past Due': const Color(0xFFE53935),
    'Closed': const Color(0xFF9E9E9E),
    'Draft': const Color(0xFFFF9800),
  };
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // Changed from 3 to 2
    _selectedClass = widget.selectedClass;
    _teacherService = TeacherService(baseUrl: Constants.apiBaseUrl);
    _classService = ClassService(baseUrl: Constants.apiBaseUrl);
    _loadData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      // Load assignments from API
      final assignments = await AssignmentService.getAssignments(
        teacherId: widget.user.id,
        classId: _selectedClass?['id'],
      );
      
      // Load teacher's classes if not already selected or if classes list is empty
      if (_selectedClass == null && _classes.isEmpty) {
        print('🎓 Loading teacher classes for assignments...');
        
        // Get all classes and filter by teacher
        final allClasses = await _classService.getAllClasses();
        final teacherData = await _teacherService.getTeacherById(widget.user.id);
        
        // Extract teacher's class IDs
        final teacherClasses = teacherData['classes'] as List<dynamic>? ?? [];
        final teacherClassIds = teacherClasses
            .map((c) => c['_id'] ?? c['id'])
            .where((id) => id != null)
            .toSet();
        
        // Extract subjects from teacher data
        final teachingSubs = teacherData['teachingSubs'] as List<dynamic>? ?? [];
        
        // Clear existing classes
        _classes.clear();
        
        // Filter classes that belong to this teacher
        for (final classData in allClasses) {
          final classId = classData['_id'] ?? classData['id'];
          if (teacherClassIds.contains(classId)) {
            _classes.add({
              'id': classId,
              'name': classData['name'] ?? '${classData['grade'] ?? 'Unknown'} ${classData['section'] ?? ''}',
              'subject': teachingSubs.isNotEmpty ? teachingSubs.join(', ') : 'No subjects',
              'subjects': teachingSubs.map((s) => s.toString()).toList(),
              'color': _getRandomColor(),
              'grade': classData['grade'] ?? 'Unknown',
              'section': classData['section'] ?? '',
              'year': classData['year']?.toString() ?? DateTime.now().year.toString(),
            });
          }
        }
        
        print('🎓 Loaded ${_classes.length} classes for assignment creation');
      }
      
      // If we still don't have classes and assignments exist, extract from assignments
      if (_classes.isEmpty && assignments.isNotEmpty) {
        final Set<String> addedClasses = {};
        for (final assignment in assignments) {
          if (assignment.classInfo != null && !addedClasses.contains(assignment.classInfo!.id)) {
            _classes.add({
              'id': assignment.classInfo!.id,
              'name': assignment.classInfo!.name,
              'subject': assignment.subject,
              'subjects': [assignment.subject], // Single subject from assignment
              'color': _getRandomColor(),
            });
            addedClasses.add(assignment.classInfo!.id);
          }
        }
      }
      
      setState(() {
        _assignments = assignments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
  
  Color _getRandomColor() {
    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red, Colors.teal];
    return colors[DateTime.now().millisecondsSinceEpoch % colors.length];
  }
  
  String _getAssignmentStatus(Assignment assignment) {
    final now = DateTime.now();
    if (assignment.dueDate.isBefore(now)) {
      return 'Past Due';
    } else if (assignment.assignedAt.isAfter(now)) {
      return 'Scheduled';
    } else {
      return 'Active';
    }
  }
  
  List<Assignment> get _filteredAssignments {
    if (_selectedClass == null) {
      return _assignments;
    } else {
      return _assignments.where((a) => a.classId == _selectedClass!['id']).toList();
    }
  }
  
  List<Assignment> get _activeAssignments {
    return _filteredAssignments.where((a) {
      final status = _getAssignmentStatus(a);
      return status == 'Active' || status == 'Scheduled';
    }).toList();
  }
  
  List<Assignment> get _pastAssignments {
    return _filteredAssignments.where((a) {
      final status = _getAssignmentStatus(a);
      return status == 'Past Due' || status == 'Closed';
    }).toList();
  }
  
  List<Assignment> get _draftAssignments {
    return _filteredAssignments.where((a) => _getAssignmentStatus(a) == 'Draft').toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        title: Text(_selectedClass == null ? 'HomeWork' : 
          'HomeWork - ${_selectedClass!['name']}'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Past'),
          ],
        ),
        actions: [
          if (_selectedClass == null)
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: _showClassSelectionDialog,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
        ? Center(child: CircularProgressIndicator(color: _primaryColor))
        : _error != null
          ? _buildErrorWidget()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAssignmentsList(_activeAssignments),
                _buildAssignmentsList(_pastAssignments),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateAssignmentDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Assignment'),
        backgroundColor: _primaryColor,
      ),
    );
  }
  
  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.red.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Error Loading Assignments',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Unknown error occurred',
            style: TextStyle(
              fontSize: 16,
              color: _textSecondaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            child: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAssignmentsList(List<Assignment> assignments) {
    if (assignments.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 80,
              color: _textSecondaryColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No Assignments',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _textPrimaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a new assignment to get started',
              style: TextStyle(
                fontSize: 16,
                color: _textSecondaryColor,
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: assignments.length,
      itemBuilder: (context, index) => _buildAssignmentCard(assignments[index]),
    );
  }
  
  Widget _buildAssignmentCard(Assignment assignment) {
    final String status = _getAssignmentStatus(assignment);
    final Color statusColor = _getStatusColor(status);
    final Color cardColor = _getClassColor(assignment.classId);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      color: _cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: InkWell(
        onTap: () => _showAssignmentDetails(assignment),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: cardColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getAssignmentIcon(assignment.subject),
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          assignment.title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _textPrimaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          assignment.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: _textSecondaryColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.class_, size: 16, color: _textSecondaryColor),
                          const SizedBox(width: 4),
                          Text(
                            assignment.classInfo?.name ?? assignment.classId,
                            style: TextStyle(
                              color: _textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 16, color: _textSecondaryColor),
                          const SizedBox(width: 4),
                          Text(
                            'Due: ${_dateFormat.format(assignment.dueDate)}',
                            style: TextStyle(
                              color: _textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.subject, size: 16, color: _textSecondaryColor),
                          const SizedBox(width: 4),
                          Text(
                            assignment.subject,
                            style: TextStyle(
                              color: _textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: _backgroundColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: () => _editAssignment(assignment),
                    icon: Icon(Icons.edit, color: _primaryColor),
                    label: Text('Edit', style: TextStyle(color: _primaryColor)),
                    style: TextButton.styleFrom(
                      foregroundColor: _primaryColor,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _confirmDeleteAssignment(assignment),
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text('Delete', style: TextStyle(color: Colors.red)),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Color _getStatusColor(String status) {
    return _statusColors[status] ?? Colors.grey;
  }
  
  Color _getClassColor(String classId) {
    if (_selectedClass != null && _selectedClass!['id'] == classId) {
      return _selectedClass!['color'] ?? _primaryColor;
    }
    
    final classData = _classes.firstWhere(
      (c) => c['id'] == classId, 
      orElse: () => {'color': _primaryColor},
    );
    
    return classData['color'] ?? _primaryColor;
  }
  
  IconData _getAssignmentIcon(String type) {
    switch (type) {
      case 'Quiz': return Icons.quiz;
      case 'Lab Report': return Icons.science;
      case 'Project': return Icons.engineering;
      case 'Test': return Icons.sticky_note_2;
      case 'Homework':
      default: return Icons.assignment;
    }
  }
  
  void _showClassSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Class'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _classes.length + 1, // +1 for "All Classes" option
              itemBuilder: (context, index) {
                if (index == 0) {
                  // "All Classes" option
                  return ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.all_inclusive),
                    ),
                    title: const Text('All Classes'),
                    selected: _selectedClass == null,
                    onTap: () {
                      setState(() {
                        _selectedClass = null;
                      });
                      Navigator.pop(context);
                    },
                  );
                }
                
                final classData = _classes[index - 1];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: classData['color'],
                    child: Text(
                      classData['id'],
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(classData['name']),
                  subtitle: Text(classData['subject']),
                  selected: _selectedClass != null && _selectedClass!['id'] == classData['id'],
                  onTap: () {
                    setState(() {
                      _selectedClass = classData;
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
  
  void _showAssignmentDetails(Assignment assignment) {
    final String status = _getAssignmentStatus(assignment);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: _backgroundColor,
          appBar: AppBar(
            title: Text(assignment.title),
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  Navigator.pop(context);
                  _editAssignment(assignment);
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200, width: 1),
                  ),
                  elevation: 1,
                  color: _cardColor,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          assignment.title,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: _textPrimaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(status),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Divider(color: Colors.grey.shade200),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(Icons.class_, color: _textSecondaryColor),
                            const SizedBox(width: 8),
                            Text(
                              'Class: ${assignment.classInfo?.name ?? assignment.classId}',
                              style: TextStyle(fontSize: 16, color: _textPrimaryColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.subject, color: _textSecondaryColor),
                            const SizedBox(width: 8),
                            Text(
                              'Subject: ${assignment.subject}',
                              style: TextStyle(fontSize: 16, color: _textPrimaryColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.calendar_today, color: _textSecondaryColor),
                            const SizedBox(width: 8),
                            Text(
                              'Due Date: ${_dateFormat.format(assignment.dueDate)}',
                              style: TextStyle(fontSize: 16, color: _textPrimaryColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.access_time, color: _textSecondaryColor),
                            const SizedBox(width: 8),
                            Text(
                              'Assigned: ${_dateFormat.format(assignment.assignedAt)}',
                              style: TextStyle(fontSize: 16, color: _textPrimaryColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _textPrimaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          assignment.description,
                          style: TextStyle(fontSize: 16, color: _textPrimaryColor),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _editAssignment(assignment),
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit Assignment'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _confirmDeleteAssignment(assignment),
                        icon: const Icon(Icons.delete),
                        label: const Text('Delete Assignment'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  void _showCreateAssignmentDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime dueDate = DateTime.now().add(const Duration(days: 7));
    String? selectedSubject;
    Map<String, dynamic>? classForAssignment = _selectedClass;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Update available subjects when class changes
            List<String> availableSubjects = [];
            if (classForAssignment != null && classForAssignment!['subjects'] != null) {
              availableSubjects = List<String>.from(classForAssignment!['subjects']);
            }
            
            return AlertDialog(
              title: Text(
                'Create New Assignment',
                style: TextStyle(color: _textPrimaryColor),
              ),
              backgroundColor: _cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Title *',
                        hintText: 'Enter assignment title',
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: _primaryColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        labelStyle: TextStyle(color: _textSecondaryColor),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Description *',
                        hintText: 'Enter assignment description',
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: _primaryColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        labelStyle: TextStyle(color: _textSecondaryColor),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Class: *',
                      style: TextStyle(color: _textSecondaryColor),
                    ),
                    if (_classes.isNotEmpty)
                      DropdownButton<Map<String, dynamic>>(
                        value: classForAssignment,
                        isExpanded: true,
                        hint: const Text('Select a class'),
                        items: _classes.map<DropdownMenuItem<Map<String, dynamic>>>((classData) {
                          return DropdownMenuItem<Map<String, dynamic>>(
                            value: classData,
                            child: Text('${classData['name']} - ${classData['grade']} ${classData['section']}'),
                          );
                        }).toList(),
                        onChanged: (Map<String, dynamic>? newValue) {
                          setState(() {
                            classForAssignment = newValue;
                            selectedSubject = null; // Reset subject when class changes
                          });
                        },
                      )
                    else
                      const Text('No classes available'),
                    const SizedBox(height: 16),
                    Text(
                      'Subject: *',
                      style: TextStyle(color: _textSecondaryColor),
                    ),
                    if (availableSubjects.isNotEmpty)
                      DropdownButton<String>(
                        value: selectedSubject,
                        isExpanded: true,
                        hint: const Text('Select a subject'),
                        items: availableSubjects.map<DropdownMenuItem<String>>((String subject) {
                          return DropdownMenuItem<String>(
                            value: subject,
                            child: Text(subject),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            selectedSubject = newValue;
                          });
                        },
                      )
                    else
                      Text(
                        classForAssignment == null 
                          ? 'Please select a class first' 
                          : 'No subjects available for selected class',
                        style: TextStyle(color: _textSecondaryColor),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'Due Date: *',
                      style: TextStyle(color: _textSecondaryColor),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _dateFormat.format(dueDate),
                        style: TextStyle(color: _textPrimaryColor),
                      ),
                      trailing: Icon(Icons.calendar_today, color: _primaryColor),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: dueDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: _primaryColor,
                                  onPrimary: Colors.white,
                                  surface: _cardColor,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() {
                            dueDate = picked;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: _textSecondaryColor),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton(
                  child: const Text('Create'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    if (titleController.text.isEmpty || 
                        descriptionController.text.isEmpty || 
                        classForAssignment == null ||
                        selectedSubject == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill all required fields')),
                      );
                      return;
                    }
                    
                    try {
                      final newAssignment = Assignment(
                        id: '',
                        teacherId: widget.user.id,
                        classId: classForAssignment!['id'],
                        subject: selectedSubject!,
                        title: titleController.text,
                        description: descriptionController.text,
                        assignedAt: DateTime.now(),
                        dueDate: dueDate,
                      );
                      
                      await AssignmentService.createAssignment(newAssignment);
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Assignment created successfully'),
                          backgroundColor: _primaryColor,
                        ),
                      );
                      Navigator.of(context).pop();
                      _loadData();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error creating assignment: $e')),
                      );
                    }
                  },
                ),
              ],
            );
          }
        );
      },
    );
  }
  
  void _editAssignment(Assignment assignment) {
    final titleController = TextEditingController(text: assignment.title);
    final descriptionController = TextEditingController(text: assignment.description);
    DateTime dueDate = assignment.dueDate;
    String selectedSubject = assignment.subject;
    
    // Find the class data for this assignment
    Map<String, dynamic>? assignmentClass;
    for (final classData in _classes) {
      if (classData['id'] == assignment.classId) {
        assignmentClass = classData;
        break;
      }
    }
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Get available subjects for the current class
            List<String> availableSubjects = [];
            if (assignmentClass != null && assignmentClass!['subjects'] != null) {
              availableSubjects = List<String>.from(assignmentClass!['subjects']);
            }
            
            return AlertDialog(
              title: Text(
                'Edit Assignment',
                style: TextStyle(color: _textPrimaryColor),
              ),
              backgroundColor: _cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Title *',
                        hintText: 'Enter assignment title',
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: _primaryColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        labelStyle: TextStyle(color: _textSecondaryColor),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Description *',
                        hintText: 'Enter assignment description',
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: _primaryColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        labelStyle: TextStyle(color: _textSecondaryColor),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Class:',
                      style: TextStyle(
                        color: _textSecondaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.class_, color: _textSecondaryColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            assignment.classInfo?.name ?? assignment.classId,
                            style: TextStyle(
                              color: _textPrimaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Read Only',
                              style: TextStyle(
                                fontSize: 10,
                                color: _primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Subject: *',
                      style: TextStyle(color: _textSecondaryColor),
                    ),
                    const SizedBox(height: 8),
                    if (availableSubjects.isNotEmpty)
                      DropdownButtonFormField<String>(
                        value: availableSubjects.contains(selectedSubject) ? selectedSubject : null,
                        isExpanded: true,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: _primaryColor),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        hint: const Text('Select a subject'),
                        items: availableSubjects.map<DropdownMenuItem<String>>((String subject) {
                          return DropdownMenuItem<String>(
                            value: subject,
                            child: Text(subject),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              selectedSubject = newValue;
                            });
                          }
                        },
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          selectedSubject,
                          style: TextStyle(color: _textPrimaryColor),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'Due Date: *',
                      style: TextStyle(color: _textSecondaryColor),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: dueDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: _primaryColor,
                                  onPrimary: Colors.white,
                                  surface: _cardColor,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() {
                            dueDate = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _dateFormat.format(dueDate),
                              style: TextStyle(color: _textPrimaryColor),
                            ),
                            Icon(Icons.calendar_today, color: _primaryColor, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade600, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Created: ${_dateFormat.format(assignment.assignedAt)}',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: _textSecondaryColor),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton(
                  child: const Text('Update'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    if (titleController.text.isEmpty || 
                        descriptionController.text.isEmpty ||
                        selectedSubject.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill all required fields')),
                      );
                      return;
                    }
                    
                    try {
                      // Show loading indicator
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (BuildContext context) {
                          return Center(
                            child: CircularProgressIndicator(color: _primaryColor),
                          );
                        },
                      );
                      
                      // Set time to end of the day to avoid timezone issues
                      final dueDateWithTime = DateTime(
                        dueDate.year,
                        dueDate.month,
                        dueDate.day,
                        23, 59, 59,
                      );
                      
                      // Prepare update data
                      final updateData = {
                        'title': titleController.text.trim(),
                        'description': descriptionController.text.trim(),
                        'subject': selectedSubject,
                        'dueDate': dueDateWithTime.toIso8601String(),
                      };
                      
                      print('📝 Updating assignment ${assignment.id} with data: $updateData');
                      
                      // Update the assignment
                      await AssignmentService.updateAssignment(assignment.id, updateData);
                      
                      // Close loading dialog
                      Navigator.of(context).pop();
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Assignment updated successfully'),
                          backgroundColor: _primaryColor,
                        ),
                      );
                      
                      // Close edit dialog
                      Navigator.of(context).pop();
                      
                      // Reload assignments
                      _loadData();
                      
                    } catch (e) {
                      // Close loading dialog if it's still open
                      Navigator.of(context).pop();
                      
                      print('📝 Error updating assignment: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error updating assignment: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),
              ],
            );
          }
        );
      },
    );
  }
  
  // Add new method for delete confirmation
  void _confirmDeleteAssignment(Assignment assignment) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Assignment'),
          content: Text('Are you sure you want to delete "${assignment.title}"? This action cannot be undone.'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'Cancel',
                style: TextStyle(color: _textSecondaryColor),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Delete'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                try {
                  // Close confirmation dialog
                  Navigator.of(context).pop();
                  
                  // Show loading indicator
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (BuildContext context) {
                      return Center(
                        child: CircularProgressIndicator(color: _primaryColor),
                      );
                    },
                  );
                  
                  // Delete the assignment
                  await AssignmentService.deleteAssignment(assignment.id);
                  
                  // Close loading dialog
                  Navigator.of(context).pop();
                  
                  // If we're in detail view, go back to list
                  if (ModalRoute.of(context)?.settings.name == null) {
                    Navigator.of(context).pop();
                  }
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Assignment deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  
                  // Reload assignments
                  _loadData();
                  
                } catch (e) {
                  // Close loading dialog if it's still open
                  Navigator.of(context).pop();
                  
                  print('📝 Error deleting assignment: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting assignment: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}
