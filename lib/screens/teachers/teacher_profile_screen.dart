import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';
import '../../services/teacher_service.dart';
import '../../services/image_service.dart';
import '../../services/api_service.dart'; // Import ApiService
import '../../utils/app_theme.dart';
import '../../utils/constants.dart'; // Import constants for base URL

class TeacherProfileScreen extends StatefulWidget {
  final User user;

  const TeacherProfileScreen({super.key, required this.user});

  @override
  State<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen> {
  late Color _accentColor;
  late List<Color> _gradientColors;
  bool _isLoading = true;
  bool _isResettingPassword = false;
  bool _isUploadingImage = false;
  Map<String, dynamic>? _teacherData;
  late ApiService _apiService; // Add ApiService instance
  late TeacherService _teacherService;
  late ImageService _imageService;
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _teacherService = TeacherService(baseUrl: Constants.apiBaseUrl); // Use the constant for base URL
    _imageService = ImageService();
     _apiService = ApiService(); // Initialize ApiService
    _loadThemeColors();
    _loadTeacherProfile();
    _loadProfileImageFromPrefs();
  }

  Future<void> _loadProfileImageFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedImageUrl = prefs.getString('profileImageUrl');
      if (cachedImageUrl != null) {
        setState(() {
          _profileImageUrl = cachedImageUrl;
        });
      } else {
        setState(() {
          _profileImageUrl = widget.user.profile.profilePicture;
        });
      }
      
      _fetchProfileImage();
    } catch (e) {
      print('Error loading profile image from prefs: $e');
      setState(() {
        _profileImageUrl = widget.user.profile.profilePicture;
      });
      _fetchProfileImage();
    }
  }

  Future<void> _fetchProfileImage() async {
    try {
      final imageUrl = await _imageService.getProfileImage(widget.user.id);
      if (imageUrl != null) {
        setState(() {
          _profileImageUrl = imageUrl;
        });
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profileImageUrl', imageUrl);
      }
    } catch (e) {
      print('Error fetching profile image: $e');
    }
  }

  void _loadThemeColors() {
    _accentColor = AppTheme.getAccentColor(AppTheme.defaultTheme);
    _gradientColors = AppTheme.getGradientColors(AppTheme.defaultTheme);
  }

  Future<void> _loadTeacherProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('👤 Loading teacher profile for ID: ${widget.user.id}');
      final teacherData = await _teacherService.getTeacherById(widget.user.id);
      
      setState(() {
        _teacherData = teacherData;
        _isLoading = false;
      });
      
      print('👤 Teacher profile loaded: $teacherData');
    } catch (e) {
      print('👤 Error loading teacher profile: $e');
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: $e'),
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
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profileImageUrl', updatedImageUrl);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile image updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Reload profile to get updated data
        _loadTeacherProfile();
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

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.getTheme(AppTheme.defaultTheme),
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'My Profile',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
            icon: const Icon(Icons.lock_reset),
            onPressed: _resetPassword, // Add reset password button
            tooltip: 'Reset Password',
          ),
          ],
        ),
        body: _isLoading ? _buildLoadingView() : _buildProfileView(),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: _accentColor),
          const SizedBox(height: 16),
          Text(
            _isResettingPassword ? 'Resetting password...' : 'Loading profile...',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileView() {
    if (_teacherData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Failed to load profile',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadTeacherProfile,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _accentColor,
      onRefresh: _loadTeacherProfile,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 24),
            _buildPersonalInfoCard(),
            const SizedBox(height: 16),
            _buildTeachingInfoCard(),
            const SizedBox(height: 16),
            _buildClassesCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: _gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Stack(
              children: [
                _profileImageUrl != null
                  ? CircleAvatar(
                      radius: 50,
                      backgroundImage: NetworkImage(_profileImageUrl!),
                      backgroundColor: Colors.white,
                      onBackgroundImageError: (exception, stackTrace) {
                        print('Error loading profile image: $exception');
                      },
                    )
                  : CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white,
                      child: Text(
                        '${widget.user.profile.firstName[0]}${widget.user.profile.lastName[0]}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
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
                          color: Colors.black.withOpacity(0.2),
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
            const SizedBox(height: 16),
            Text(
              _teacherData?['name']?.toString() ?? 'Unknown',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _teacherData?['email']?.toString() ?? '',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Teacher ID: ${_teacherData?['teacherId']?.toString() ?? 'N/A'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalInfoCard() {
    final dateJoined = _teacherData?['dateJoined']?.toString();
    String formattedDate = 'N/A';
    
    if (dateJoined != null) {
      try {
        final date = DateTime.parse(dateJoined);
        formattedDate = DateFormat('MMMM d, yyyy').format(date);
      } catch (e) {
        formattedDate = 'Invalid date';
      }
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: _accentColor),
                const SizedBox(width: 8),
                const Text(
                  'Personal Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Full Name', _teacherData?['name']?.toString() ?? 'N/A'),
            _buildInfoRow('Email', _teacherData?['email']?.toString() ?? 'N/A'),
            _buildInfoRow('Teacher ID', _teacherData?['teacherId']?.toString() ?? 'N/A'),
            _buildInfoRow('Date Joined', formattedDate),
          ],
        ),
      ),
    );
  }

  Widget _buildTeachingInfoCard() {
    final teachingSubs = _teacherData?['teachingSubs'] as List<dynamic>?;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.school, color: _accentColor),
                const SizedBox(width: 8),
                const Text(
                  'Teaching Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (teachingSubs != null && teachingSubs.isNotEmpty) ...[
              const Text(
                'Teaching Subjects:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: teachingSubs.map((subject) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _accentColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      subject.toString(),
                      style: TextStyle(
                        color: _accentColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    );
                  }).toList(),
              ),
            ] else ...[
              _buildInfoRow('Teaching Subjects', 'No subjects assigned'),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildClassesCard() {
    final classes = _teacherData?['classes'] as List<dynamic>?;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.class_, color: _accentColor),
                const SizedBox(width: 8),
                const Text(
                  'Classes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (classes != null && classes.isNotEmpty) ...[
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: classes.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final classItem = classes[index] as Map<String, dynamic>;
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          classItem['name']?.toString() ?? 'Unknown Class',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Grade ${classItem['grade']?.toString() ?? 'N/A'} - Section ${classItem['section']?.toString() ?? 'N/A'}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        if (classItem['year'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Academic Year: ${classItem['year']}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.class_, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'No classes assigned',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }


  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
