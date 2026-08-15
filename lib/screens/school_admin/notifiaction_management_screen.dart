import 'package:flutter/material.dart';
import '../../models/notification_model.dart';
import '../../services/notification_service.dart';
import '../../services/class_services.dart';
import '../../services/teacher_service.dart';
import '../../services/student_service.dart';
import '../../services/parent_service.dart';
import '../../utils/storage_util.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart'; // Import constants for base URL

class NotificationManagementScreen extends StatefulWidget {
  const NotificationManagementScreen({Key? key}) : super(key: key);

  @override
  State<NotificationManagementScreen> createState() => _NotificationManagementScreenState();
}

class _NotificationManagementScreenState extends State<NotificationManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final NotificationService _notificationService = NotificationService();
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  String? _error;
  String? _currentUserId;  

    // Theme colors
  late Color _primaryColor;

  // Services for fetching recipients
  late ClassService _classService;
  late TeacherService _teacherService;
  late StudentService _studentService;
  late ParentService _parentService;
  
  @override
  void initState() {
    super.initState();
     _loadThemeColors();
    _tabController = TabController(length: 2, vsync: this); // Change to 2 tabs
    _fetchNotifications();
    _fetchCurrentUserId(); // Add this to get the current user's ID
    
    // Initialize services
    _classService = ClassService(baseUrl: Constants.apiBaseUrl);
    _teacherService = TeacherService(baseUrl:  Constants.apiBaseUrl);
    _studentService = StudentService(baseUrl: Constants.apiBaseUrl);
    _parentService = ParentService(baseUrl:  Constants.apiBaseUrl);
  }

  void _loadThemeColors() {
    _primaryColor = AppTheme.getPrimaryColor(AppTheme.defaultTheme);
  }
  // Add method to fetch current user ID
  Future<void> _fetchCurrentUserId() async {
    try {
      final userId = await StorageUtil.getString('userId');
      setState(() {
        _currentUserId = userId;
      });
    } catch (e) {
      print('Error fetching current user ID: $e');
    }
  }

  // Fetch notifications from the API
  Future<void> _fetchNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final notifications = await _notificationService.getNotifications();
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }


  // Update this method to filter announcements
  List<NotificationModel> _getAnnouncementNotifications() {
    return _notifications.where((notification) => 
      notification.type == 'Announcement').toList();
  }
  
  // Add new method to filter my notifications
  List<NotificationModel> _getMyNotifications() {
    if (_currentUserId == null) return [];
    return _notifications.where((notification) => 
      notification.createdBy == _currentUserId).toList();
  }

  void _showComposeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Notification Type'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildNotificationTypeCard(
                  icon: Icons.campaign,
                  color: Colors.amberAccent.shade700,
                  title: 'Announcement',
                  subtitle: 'Send to everyone in the school',
                  onTap: () {
                    Navigator.pop(context);
                    _showAnnouncementDialog();
                  },
                ),
                _buildNotificationTypeCard(
                  icon: Icons.class_,
                  color: Colors.purpleAccent.shade200,
                  title: 'Message to Class',
                  subtitle: 'Send to a specific class',
                  onTap: () {
                    Navigator.pop(context);
                    _showClassMessageDialog();
                  },
                ),
                _buildNotificationTypeCard(
                  icon: Icons.school,
                  color: Colors.blueAccent,
                  title: 'Message to Teacher',
                  subtitle: 'Send to a specific teacher',
                  onTap: () {
                    Navigator.pop(context);
                    _showTeacherMessageDialog();
                  },
                ),
                _buildNotificationTypeCard(
                  icon: Icons.person,
                  color: Colors.tealAccent.shade400,
                  title: 'Message to Student',
                  subtitle: 'Send to a specific student',
                  onTap: () {
                    Navigator.pop(context);
                    _showStudentMessageDialog();
                  },
                ),
                _buildNotificationTypeCard(
                  icon: Icons.family_restroom,
                  color: Colors.pinkAccent.shade200,
                  title: 'Message to Parent',
                  subtitle: 'Send to a specific parent',
                  onTap: () {
                    Navigator.pop(context);
                    _showParentMessageDialog();
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
          ],
        );
      },
    );
  }

  Widget _buildNotificationTypeCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color,
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: color, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  // Show dialog for creating an announcement
  void _showAnnouncementDialog() {
    final messageController = TextEditingController();
    List<String> selectedAudience = ['all_students', 'all_teachers', 'all_parents'];
    DateTime scheduleDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.amberAccent.shade700,
                  child: const Icon(Icons.campaign, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Text('New Announcement'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: messageController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Announcement Message',
                      hintText: 'Enter your announcement message',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Select Audience',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  CheckboxListTile(
                    title: const Text('All Students'),
                    value: selectedAudience.contains('all_students'),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          if (!selectedAudience.contains('all_students')) {
                            selectedAudience.add('all_students');
                          }
                        } else {
                          selectedAudience.remove('all_students');
                        }
                      });
                    },
                  ),
                  CheckboxListTile(
                    title: const Text('All Teachers'),
                    value: selectedAudience.contains('all_teachers'),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          if (!selectedAudience.contains('all_teachers')) {
                            selectedAudience.add('all_teachers');
                          }
                        } else {
                          selectedAudience.remove('all_teachers');
                        }
                      });
                    },
                  ),
                  CheckboxListTile(
                    title: const Text('All Parents'),
                    value: selectedAudience.contains('all_parents'),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          if (!selectedAudience.contains('all_parents')) {
                            selectedAudience.add('all_parents');
                          }
                        } else {
                          selectedAudience.remove('all_parents');
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amberAccent.shade700,
                ),
                onPressed: () async {
                  if (messageController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a message')),
                    );
                    return;
                  }
                  
                  if (selectedAudience.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select at least one audience')),
                    );
                    return;
                  }
                  
                  Navigator.pop(context);
                  
                  // Show loading indicator
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(child: CircularProgressIndicator()),
                  );
                  
                  try {
                    // Send announcement notification with the expected format
                    final success = await _notificationService.sendNotification(
                      type: 'Announcement',
                      message: messageController.text,
                      audience: selectedAudience,
                    );
                    
                    // Always close loading dialog if context is still valid
                    if (mounted) {
                      Navigator.pop(context);
                    }
                    
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Announcement sent successfully')),
                      );
                      _fetchNotifications(); // Refresh the list
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to send announcement')),
                      );
                    }
                  } catch (e) {
                    // Ensure loading dialog is dismissed even on error
                    if (mounted) {
                      Navigator.pop(context);
                    }
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}')),
                    );
                  }
                },
                child: const Text('Send Announcement', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  // Show dialog for sending message to a class
  void _showClassMessageDialog() {
    // Navigate to class selection screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecipientSelectionScreen(
          title: 'Select Class',
          recipientType: 'class',
          service: _classService,
          icon: Icons.class_,
          iconBackgroundColor: Colors.purpleAccent.shade200,
          onRecipientSelected: (String classId, String className) {
            // Show message composition dialog
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MessageCompositionScreen(
                  recipientType: 'Class',
                  recipientId: classId,
                  recipientName: className,
                  iconData: Icons.class_,
                  iconColor: Colors.purpleAccent.shade200,
                  onSendMessage: (message) {
                    _sendNotification(
                      type: 'Class',
                      message: message,
                      classId: classId,
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Show dialog for sending message to a teacher
  void _showTeacherMessageDialog() {
    // Navigate to teacher selection screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecipientSelectionScreen(
          title: 'Select Teacher',
          recipientType: 'teacher',
          service: _teacherService,
          icon: Icons.school,
          iconBackgroundColor: Colors.blueAccent,
          onRecipientSelected: (String teacherId, String teacherName) {
            // Show message composition dialog
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MessageCompositionScreen(
                  recipientType: 'Teacher',
                  recipientId: teacherId,
                  recipientName: teacherName,
                  iconData: Icons.school,
                  iconColor: Colors.blueAccent,
                  onSendMessage: (message) {
                    _sendNotification(
                      type: 'Teacher',
                      message: message,
                      teacherId: teacherId,
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Show dialog for sending message to a student
  void _showStudentMessageDialog() {
    // Navigate to student selection screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecipientSelectionScreen(
          title: 'Select Student',
          recipientType: 'student',
          service: _studentService,
          icon: Icons.person,
          iconBackgroundColor: Colors.tealAccent.shade400,
          onRecipientSelected: (String studentId, String studentName) {
            // Show message composition dialog
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MessageCompositionScreen(
                  recipientType: 'Student',
                  recipientId: studentId,
                  recipientName: studentName,
                  iconData: Icons.person,
                  iconColor: Colors.tealAccent.shade400,
                  onSendMessage: (message) {
                    _sendNotification(
                      type: 'Student',
                      message: message,
                      studentId: studentId,
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }  // Show dialog for sending message to a parent
  void _showParentMessageDialog() {
    // First show student selection to find parents
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentWithParentsSelectionScreen(
          studentService: _studentService,
          onParentSelected: (String parentId, String parentName) {
            // Debug print to verify the parent ID
            print('👪 Selected parent ID: $parentId');
            print('👪 Selected parent name: $parentName');
            
            // Extract just the ID part if we received a full object
            String actualParentId = parentId;
            if (parentId.contains('_id:')) {
              // Try to extract the ID from a stringified object
              final idMatch = RegExp(r'_id:\s*([^,\s}]+)').firstMatch(parentId);
              if (idMatch != null && idMatch.group(1) != null) {
                actualParentId = idMatch.group(1)!;
              }
            }
            
            if (actualParentId.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invalid parent ID')),
              );
              return;
            }
            
            print('👪 Processed parent ID: $actualParentId');
            
            // Show message composition dialog
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MessageCompositionScreen(
                  recipientType: 'Parent',
                  recipientId: actualParentId,
                  recipientName: parentName,
                  iconData: Icons.family_restroom,
                  iconColor: Colors.pinkAccent.shade200,
                  onSendMessage: (message) {
                    _sendNotification(
                      type: 'Parent',
                      message: message,
                      parentId: actualParentId,
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
  // Common method to send notifications of any type
  Future<void> _sendNotification({
    required String type,
    required String message,
    List<String> audience = const [],
    String? teacherId,
    String? studentId,
    String? classId,
    String? parentId,
  }) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      bool success;
      
      // Use specific endpoints based on notification type
      if (type == 'Teacher' && teacherId != null) {
        success = await _notificationService.sendTeacherNotification(
          teacherId: teacherId,
          message: message,
        );
      } 
      else if (type == 'Class' && classId != null) {
        success = await _notificationService.sendClassNotification(
          classId: classId,
          message: message,
        );
      }      else if (type == 'Parent' && parentId != null) {
        print('👪 Sending notification to parent ID: $parentId');
        success = await _notificationService.sendParentNotification(
          parentId: parentId,
          message: message,
        );
      }
      else {
        // Use the general notification endpoint for other types
        success = await _notificationService.sendNotification(
          type: type,
          message: message,
          audience: audience,
          teacherId: teacherId,
          studentId: studentId,
          classId: classId,
          parentId: parentId,
        );
      }
      
      // Ensure loading dialog is dismissed regardless of success state
      if (mounted) {
        Navigator.pop(context);
      }
      
      // Now handle success or failure
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification sent successfully')),
        );
        _fetchNotifications(); // Refresh the list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send notification')),
        );
      }
    } catch (e) {
      // Make sure loading dialog is dismissed even if there's an error
      if (mounted) {
        Navigator.pop(context);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Management'),
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amberAccent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Announcements'),
            Tab(text: 'My Notifications'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchNotifications,
            tooltip: 'Refresh notifications',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $_error', style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchNotifications,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAnnouncementsList(), // First tab - Announcements
                    _buildMyNotificationsList(), // Second tab - My Notifications
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showComposeDialog,
        backgroundColor: Colors.lightGreen.shade400,
        child: const Icon(Icons.add),
        tooltip: 'Compose New Notification',
      ),
    );
  }

  // Add a new method to build the announcements list
  Widget _buildAnnouncementsList() {
    final announcements = _getAnnouncementNotifications();
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.blue.shade50, Colors.white],
        ),
      ),
      child: announcements.isEmpty
        ? const Center(child: Text('No announcements', style: TextStyle(fontSize: 16, color: Colors.blueGrey)))
        : RefreshIndicator(
            onRefresh: _fetchNotifications,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: announcements.length,
              itemBuilder: (context, index) {
                return _buildNotificationCard(announcements[index]);
              },
            ),
          ),
    );
  }

  // Add a new method to build my notifications list
  Widget _buildMyNotificationsList() {
    final myNotifications = _getMyNotifications();
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.purple.shade50, Colors.white],
        ),
      ),
      child: myNotifications.isEmpty
        ? const Center(child: Text('No notifications created by you', style: TextStyle(fontSize: 16, color: Colors.blueGrey)))
        : RefreshIndicator(
            onRefresh: _fetchNotifications,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: myNotifications.length,
              itemBuilder: (context, index) {
                return _buildNotificationCard(myNotifications[index]);
              },
            ),
          ),
    );
  }

  // Add a helper method to build notification cards to avoid code duplication
  Widget _buildNotificationCard(NotificationModel notification) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shadowColor: notification.getTypeColor().withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: notification.getTypeColor().withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: notification.getTypeColor(),
          child: Icon(notification.getTypeIcon(), color: Colors.white),
        ),
        title: Text(
          notification.type,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(notification.message),
            const SizedBox(height: 4),
            Text(
              notification.getRecipientDescription(),
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey[700],
              ),
            ),
            Text(
              'Issued: ${notification.issuedAt.day}/${notification.issuedAt.month}/${notification.issuedAt.year}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: Icon(Icons.more_vert, color: notification.getTypeColor()),
          onPressed: () {
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              builder: (context) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.delete, color: Colors.redAccent),
                      title: const Text('Delete'),
                      onTap: () async {
                        Navigator.pop(context);
                        
                        // Show confirmation dialog
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Notification'),
                            content: const Text('Are you sure you want to delete this notification?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Delete', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                        
                        if (confirm == true) {
                          try {
                            final success = await _notificationService.deleteNotification(notification.id);
                            if (success) {
                              setState(() {
                                _notifications.remove(notification);
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Notification deleted successfully')),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Failed to delete notification')),
                              );
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: ${e.toString()}')),
                            );
                          }
                        }
                      },
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// New recipient selection screen with search functionality
class RecipientSelectionScreen extends StatefulWidget {
  final String title;
  final String recipientType; // 'teacher', 'student', 'class', 'parent'
  final dynamic service; // The service to use for fetching data
  final IconData icon;
  final Color iconBackgroundColor;
  final Function(String id, String name) onRecipientSelected;

  const RecipientSelectionScreen({
    Key? key,
    required this.title,
    required this.recipientType,
    required this.service,
    required this.icon,
    required this.iconBackgroundColor,
    required this.onRecipientSelected,
  }) : super(key: key);

  @override
  State<RecipientSelectionScreen> createState() => _RecipientSelectionScreenState();
}

class _RecipientSelectionScreenState extends State<RecipientSelectionScreen> {
  List<Map<String, dynamic>> _allRecipients = [];
  List<Map<String, dynamic>> _filteredRecipients = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRecipients();
    
    _searchController.addListener(() {
      _filterRecipients(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecipients() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      List<Map<String, dynamic>> recipients = [];
      
      // Call the appropriate method based on recipient type
      if (widget.recipientType == 'teacher') {
        recipients = await widget.service.getAllTeachers();
      } else if (widget.recipientType == 'student') {
        recipients = await widget.service.getAllStudents();
      } else if (widget.recipientType == 'class') {
        recipients = await widget.service.getAllClasses();
      } else if (widget.recipientType == 'parent') {
        recipients = await widget.service.getAllParents();
      }
      
      setState(() {
        _allRecipients = recipients;
        _filteredRecipients = recipients;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterRecipients(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredRecipients = _allRecipients;
      });
      return;
    }
    
    final lowercaseQuery = query.toLowerCase();
    
    setState(() {
      _filteredRecipients = _allRecipients.where((recipient) {
        final name = recipient['name']?.toString().toLowerCase() ?? '';
        return name.contains(lowercaseQuery);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: widget.iconBackgroundColor,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(vertical: 0.0, horizontal: 12.0),
              ),
            ),
          ),
          
          // Results
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Error: $_error', style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadRecipients,
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  )
                : _filteredRecipients.isEmpty
                  ? const Center(child: Text('No results found'))
                  : ListView.builder(
                      itemCount: _filteredRecipients.length,
                      itemBuilder: (context, index) {
                        final recipient = _filteredRecipients[index];
                        final id = recipient['_id'] ?? '';
                        final name = recipient['name'] ?? 'Unknown';
                        
                        // Additional info based on recipient type
                        String? additionalInfo;
                        if (widget.recipientType == 'student') {
                          additionalInfo = recipient['class_name'] ?? recipient['grade'] ?? '';
                        } else if (widget.recipientType == 'teacher') {
                          additionalInfo = recipient['subject'] ?? '';
                        } else if (widget.recipientType == 'parent') {
                          // Get children names if available
                          final children = recipient['children'] as List?;
                          if (children != null && children.isNotEmpty) {
                            additionalInfo = 'Parent of: ${children.map((c) => c['name'] ?? '').join(', ')}';
                          }
                        }
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: widget.iconBackgroundColor,
                              child: Icon(widget.icon, color: Colors.white),
                            ),
                            title: Text(name),
                            subtitle: additionalInfo != null ? Text(additionalInfo) : null,
                            onTap: () => widget.onRecipientSelected(id, name),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

// New screen for composing a message to a selected recipient
class MessageCompositionScreen extends StatefulWidget {
  final String recipientType;  final String recipientId;
  final String recipientName;
  final IconData iconData;
  final Color iconColor;
  final Function(String message) onSendMessage;

  const MessageCompositionScreen({
    Key? key,
    required this.recipientType,
    required this.recipientId,
    required this.recipientName,
    required this.iconData,
    required this.iconColor,
    required this.onSendMessage,
  }) : super(key: key);

  @override
  State<MessageCompositionScreen> createState() => _MessageCompositionScreenState();
}

class _MessageCompositionScreenState extends State<MessageCompositionScreen> {
  final TextEditingController _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Message to ${widget.recipientName}'),
        backgroundColor: widget.iconColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recipient info card
            Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: widget.iconColor.withValues(alpha: 0.5)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: widget.iconColor,
                      child: Icon(widget.iconData, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'To: ${widget.recipientName}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Type: ${widget.recipientType}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Message input
            Expanded(
              child: TextFormField(
                controller: _messageController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  labelText: 'Message',
                  hintText: 'Enter your message here...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            
            // Send button
            Container(
              margin: const EdgeInsets.only(top: 16),
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.iconColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  if (_messageController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a message')),
                    );
                    return;
                  }
                  
                  widget.onSendMessage(_messageController.text);
                  Navigator.pop(context);
                  Navigator.pop(context); // Pop twice to return to notification management screen
                },
                child: const Text(
                  'Send Message',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// New screen for selecting parents of students
class StudentWithParentsSelectionScreen extends StatefulWidget {
  final StudentService studentService;
  final Function(String id, String name) onParentSelected;

  const StudentWithParentsSelectionScreen({
    Key? key,
    required this.studentService,
    required this.onParentSelected,
  }) : super(key: key);

  @override
  State<StudentWithParentsSelectionScreen> createState() => _StudentWithParentsSelectionScreenState();
}

class _StudentWithParentsSelectionScreenState extends State<StudentWithParentsSelectionScreen> {
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  
  // Map to store parents for each student
  final Map<String, List<Map<String, dynamic>>> _parentsMap = {};
  // Map to track expanded state of each student card
  final Map<String, bool> _expandedMap = {};

  @override
  void initState() {
    super.initState();
    _loadStudents();
    
    _searchController.addListener(() {
      _filterStudents(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final students = await widget.studentService.getAllStudents();
      
      setState(() {
        _students = students;
        _filteredStudents = students;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadParentsForStudent(String studentId) async {
    if (_parentsMap.containsKey(studentId)) {
      return; // Parents already loaded
    }

    try {
      final parents = await widget.studentService.getParentsByStudentId(studentId);
      
      setState(() {
        _parentsMap[studentId] = parents;
      });
    } catch (e) {
      print('Error loading parents for student $studentId: $e');
      // Set empty array to avoid repeated failed requests
      _parentsMap[studentId] = [];
    }
  }

  void _filterStudents(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredStudents = _students;
      });
      return;
    }
    
    final lowercaseQuery = query.toLowerCase();
    
    setState(() {
      _filteredStudents = _students.where((student) {
        final name = student['name']?.toString().toLowerCase() ?? '';
        final studentId = student['studentId']?.toString().toLowerCase() ?? '';
        return name.contains(lowercaseQuery) || studentId.contains(lowercaseQuery);
      }).toList();
    });
  }

  void _toggleExpanded(String studentId) {
    setState(() {
      _expandedMap[studentId] = !(_expandedMap[studentId] ?? false);
    });

    if (_expandedMap[studentId] == true) {
      _loadParentsForStudent(studentId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Student\'s Parent'),
        backgroundColor: Colors.pinkAccent.shade200,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search students by name...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(vertical: 0.0, horizontal: 12.0),
              ),
            ),
          ),
          
          // Results
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Error: $_error', style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadStudents,
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  )
                : _filteredStudents.isEmpty
                  ? const Center(child: Text('No students found'))
                  : ListView.builder(
                      itemCount: _filteredStudents.length,
                      padding: const EdgeInsets.all(12),
                      itemBuilder: (context, index) {
                        final student = _filteredStudents[index];
                        final studentId = student['_id'] ?? '';
                        final studentName = student['name'] ?? 'Unknown';
                        final studentClass = student['classId'] is Map ? 
                            student['classId']['name'] ?? 'Unknown class' : 'Unknown class';
                        final isExpanded = _expandedMap[studentId] ?? false;
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          child: Column(
                            children: [
                              // Student information
                              ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.teal.shade300,
                                  child: const Icon(Icons.person, color: Colors.white),
                                ),
                                title: Text(studentName),
                                subtitle: Text('Class: $studentClass'),
                                trailing: IconButton(
                                  icon: Icon(
                                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                    color: Colors.pinkAccent.shade200,
                                  ),
                                  onPressed: () => _toggleExpanded(studentId),
                                ),
                              ),
                              
                              // Parents list (shown when expanded)
                              if (isExpanded)
                                _buildParentsList(studentId),
                            ],
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildParentsList(String studentId) {
    // Check if parents are loaded
    if (!_parentsMap.containsKey(studentId)) {
      _loadParentsForStudent(studentId);
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final parents = _parentsMap[studentId]!;
    
    if (parents.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No parents associated with this student'),
      );
    }

    return Container(
      color: Colors.grey.shade100,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 16.0, bottom: 8.0),
            child: Text(
              'Parents:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),          ...parents.map((parent) {
            // Ensure we have string values for id and name
            String parentId = parent['_id'] is String 
                ? parent['_id'] 
                : (parent['_id']?.toString() ?? '');
            
            String parentName = parent['name'] is String 
                ? parent['name'] 
                : (parent['name']?.toString() ?? 'Unknown Parent');

            String? phone = parent['phone'] is String 
                ? parent['phone'] 
                : (parent['phone']?.toString());
                
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.pinkAccent.shade200,
                child: const Icon(Icons.family_restroom, color: Colors.white, size: 20),
              ),            title: Text(parentName),
            subtitle: phone != null ? Text('Phone: $phone') : null,
            onTap: () {
              // Debug the actual value we're passing
              print('Selected parent ID: $parentId');
              widget.onParentSelected(parentId, parentName);
            },
            );
          }).toList(),
        ],
      ),
    );
  }
}

