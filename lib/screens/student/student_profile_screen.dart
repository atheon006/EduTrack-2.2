import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/user_model.dart';
import '../../utils/app_theme.dart';
import '../../services/student_service.dart';
import '../../services/image_service.dart';
import '../../services/grading_service.dart'; // Import GradeService
import '../../services/attendance_service.dart'; // Import AttendanceService
import '../../services/api_service.dart'; // Import ApiService
import '../../utils/constants.dart'; 

class StudentProfileScreen extends StatefulWidget {
  final User user;
  final String? studentId;

  const StudentProfileScreen({
    super.key, 
    required this.user,
    this.studentId,
  });

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  late StudentService _studentService;
  late GradingService _gradeService; // Add GradingService instance
  late AttendanceService _attendanceService; // Add AttendanceService instance
  late ImageService _imageService;
  late ApiService _apiService; // Add ApiService instance
  Map<String, dynamic>? _studentData;
  List<Map<String, dynamic>> _grades = []; // Store grades
  Map<String, dynamic>? _attendanceData; // Store attendance data
  bool _isLoading = true;
  bool _isUploadingImage = false;
  bool _isLoadingGrades = true; // Track grades loading state
  bool _isLoadingAttendance = true; // Track attendance loading state
  String? _error;
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _studentService = StudentService(baseUrl: Constants.apiBaseUrl);
    _gradeService = GradingService(baseUrl: Constants.apiBaseUrl); // Initialize GradeService
    _attendanceService = AttendanceService(baseUrl: Constants.apiBaseUrl); // Initialize AttendanceService
    _imageService = ImageService();
    _apiService = ApiService(Constants.apiBaseUrl); // Initialize ApiService
    _profileImageUrl = widget.user.profile.profilePicture;
    _fetchStudentData();
    _fetchStudentGrades();
    _fetchStudentAttendance(); 
  }

  Future<void> _fetchStudentData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Use provided studentId or extract from user
      final String studentIdToFetch = widget.studentId ?? widget.user.id;
      
      final studentData = await _studentService.getStudentById(studentIdToFetch);
      
      setState(() {
        _studentData = studentData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchStudentGrades() async {
    try {
      setState(() {
        _isLoadingGrades = true;
      });

      final grades = await _gradeService.getStudentGrades(widget.studentId ?? widget.user.id);
      setState(() {
        _grades = grades;
        _isLoadingGrades = false;
      });
    } catch (e) {
      print('Error fetching grades: $e');
      setState(() {
        _isLoadingGrades = false;
      });
    }
  }

  Future<void> _fetchStudentAttendance() async {
    try {
      setState(() {
        _isLoadingAttendance = true;
      });

      final attendance = await _attendanceService.getStudentAttendance(widget.studentId ?? widget.user.id);
      setState(() {
        _attendanceData = attendance;
        _isLoadingAttendance = false;
      });
    } catch (e) {
      print('Error fetching attendance: $e');
      setState(() {
        _isLoadingAttendance = false;
      });
    }
  }

  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    
    try {
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (pickedFile == null) {
        print('No image selected');
        return;
      }
      
      setState(() {
        _isUploadingImage = true;
      });
      
      final updatedImageUrl = await _imageService.updateProfileImage(pickedFile);
      
      if (updatedImageUrl != null) {
        setState(() {
          _profileImageUrl = updatedImageUrl;
          _isUploadingImage = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile image updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Reload profile to get updated data
        _fetchStudentData();
      } else {
        setState(() {
          _isUploadingImage = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update profile image'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error picking/uploading image: $e');
      setState(() {
        _isUploadingImage = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _resetPassword() async {
    try {
      final response = await _apiService.forgotPassword(widget.user.email);
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset email sent successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send reset email: ${response.body}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchStudentData,
          ),
          IconButton(
            icon: const Icon(Icons.lock_reset),
            onPressed: _resetPassword, // Add reset password button
            tooltip: 'Reset Password',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading student data',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchStudentData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_studentData == null) {
      return const Center(
        child: Text('No student data available'),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildProfileHeader(context, _studentData!),
          const SizedBox(height: 20),
          _buildInfoSection(context, _studentData!),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, Map<String, dynamic> studentData) {
    final classData = studentData['classId'] as Map<String, dynamic>?; // Updated to handle object format
    final schoolData = studentData['schoolId'] as Map<String, dynamic>?; // Added to handle school details
    final studentName = studentData['name'] ?? 'Unknown Student';
    final studentId = studentData['studentId'] ?? 'N/A';
    final gradeSection = classData != null 
        ? 'Grade ${classData['grade']}-${classData['section']}'
        : 'No Class Assigned';
    final schoolName = schoolData?['name'] ?? 'Unknown School'; // Extract school name

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppTheme.getGradientColors(AppTheme.defaultTheme),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Hero(
                tag: 'profilePic',
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white,
                  backgroundImage: _profileImageUrl != null 
                    ? NetworkImage(_profileImageUrl!) 
                    : NetworkImage(widget.user.profile.profilePicture),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        spreadRadius: 1,
                        blurRadius: 3,
                      ),
                    ],
                  ),
                  child: _isUploadingImage
                    ? const CircularProgressIndicator()
                    : IconButton(
                        icon: const Icon(Icons.camera_alt, color: Colors.blue),
                        onPressed: _pickAndUploadImage,
                        tooltip: 'Update profile picture',
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            studentName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              gradeSection,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'ID: $studentId',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'School: $schoolName', // Display school name
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context, Map<String, dynamic> studentData) {
    final classData = studentData['classId'] as Map<String, dynamic>?; // Updated to handle object format
    final schoolData = studentData['schoolId'] as Map<String, dynamic>?; // Added to handle school details
   

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Personal Details'),
          _buildInfoCard([
            _buildInfoRow('Student ID', studentData['studentId'] ?? 'N/A'),
            _buildInfoRow('Name', studentData['name'] ?? 'N/A'),
            _buildInfoRow('Email', studentData['email'] ?? 'N/A'),
            _buildInfoRow('Gender', studentData['gender'] ?? 'Not specified'),
          ]),
          
          const SizedBox(height: 20),
          _buildSectionTitle('Academic Information'),
          _buildInfoCard([
            _buildInfoRow('Class', classData?['name'] ?? 'Not assigned'),
            _buildInfoRow('Grade', classData?['grade']?.toString() ?? 'N/A'),
            _buildInfoRow('Section', classData?['section'] ?? 'N/A'),
            _buildInfoRow('Academic Year', classData?['year']?.toString() ?? 'N/A'),
            _buildAttendanceRow(), // Add attendance row
          ]),
          
          const SizedBox(height: 20),
          _buildSectionTitle('Academic Performance'),
          _buildAcademicPerformanceSection(), // Add academic performance section
          
          const SizedBox(height: 20),
          _buildSectionTitle('System Information'),
          _buildInfoCard([
            _buildInfoRow('Created', _formatDate(studentData['createdAt'])),
            _buildInfoRow('Last Updated', _formatDate(studentData['updatedAt'])),
            _buildInfoRow('School Name', schoolData?['name'] ?? 'N/A'), // Display school name
          ]),
          
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildAcademicPerformanceSection() {
    if (_isLoadingGrades) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_grades.isEmpty) {
      return const Center(child: Text('No academic performance data available'));
    }

    return _buildInfoCard([
      for (var grade in _grades)
        _buildInfoRow(
          grade['subject'] ?? 'Subject',
          '${grade['percentage']?.toStringAsFixed(2) ?? 'N/A'}%',
        ),
    ]);
  }

  Widget _buildAttendanceRow() {
    if (_isLoadingAttendance) {
      return const Center(child: CircularProgressIndicator());
    }

    final presentCount = _attendanceData?['summary']?['present'] ?? 'N/A';
    final absentCount = _attendanceData?['summary']?['absent'] ?? 'N/A';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Days Present', presentCount.toString()),
        _buildInfoRow('Days Absent', absentCount.toString()),
      ],
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: AppTheme.getAccentColor(AppTheme.defaultTheme),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
