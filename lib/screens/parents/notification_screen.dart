import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/notification_model.dart';
import '../../services/notification_service.dart';
import '../../services/teacher_service.dart';
import '../../utils/app_theme.dart';
import '../../services/student_service.dart';
import '../../utils/constants.dart'; // Import constants for base URL

class ParentNotificationScreen extends StatefulWidget {
  final User user;

  const ParentNotificationScreen({super.key, required this.user});

  @override
  // ignore: library_private_types_in_public_api
  _ParentNotificationScreenState createState() => _ParentNotificationScreenState();
}

class _ParentNotificationScreenState extends State<ParentNotificationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _error;
  final List<NotificationModel> _notifications = [];
  
  // Services
  final NotificationService _notificationService = NotificationService();
  late TeacherService _teacherService;
  late StudentService _studentService;
  
  // Parent's children data
  List<Map<String, dynamic>> _childrenData = [];
  
  // Theme colors to match parent dashboard
  late Color _primaryColor;
  late Color _accentColor;
  late Color _tertiaryColor;
  late List<Color> _gradientColors;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _teacherService = TeacherService(baseUrl: Constants.apiBaseUrl);
    _studentService = StudentService(baseUrl: Constants.apiBaseUrl);
    
    // Load theme colors
    _loadThemeColors();
    
    // Fetch parent's children data first, then load notifications
    _fetchChildrenData();
  }
  
  void _loadThemeColors() {
    _primaryColor = AppTheme.getPrimaryColor(AppTheme.defaultTheme);
    _accentColor = AppTheme.getAccentColor(AppTheme.defaultTheme);
    _tertiaryColor = AppTheme.getTertiaryColor(AppTheme.defaultTheme);
    _gradientColors = AppTheme.getGradientColors(AppTheme.defaultTheme);
  }

  // Fetch all children data for this parent
  Future<void> _fetchChildrenData() async {
    try {
      final childrenList = await _studentService.getStudentsByParentId(widget.user.id);
      
      if (mounted) {
        setState(() {
          _childrenData = List<Map<String, dynamic>>.from(childrenList);
          print('👨‍👩‍👧‍👦 Fetched ${_childrenData.length} children for parent');
        });
        
        // Now load notifications
        _loadNotifications();
      }
    } catch (e) {
      print('👨‍👩‍👧‍👦 Error fetching children data: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load children data: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get all notifications from the service
      final allNotifications = await _notificationService.getNotifications();
      
      setState(() {
        // Filter notifications to only include ones relevant to this parent
        _notifications.clear();
        for (var notification in allNotifications) {
          // Include notifications where:
          // 1. The notification type is 'Announcement'
          // 2. The notification type is 'Parent' and the parentId matches this parent
          // 3. The notification type is 'Student' and the studentId matches one of parent's children
          // 4. The notification type is 'Class' and the classId matches one of parent's children's class
          // 5. This parent is the creator (if any)
          if (notification.type == 'Announcement' ||
              (notification.type == 'Parent' && notification.parentId == widget.user.id) ||
              _isNotificationForParentsChild(notification) ||
              notification.createdBy == widget.user.id) {
            _notifications.add(notification);
          }
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      print('Error loading notifications: $e');
    }
  }

  // Check if a notification is for one of the parent's children
  bool _isNotificationForParentsChild(NotificationModel notification) {
    // For student-specific notifications
    if (notification.type == 'Student' && notification.studentId != null) {
      return _childrenData.any((child) => child['_id'] == notification.studentId);
    }
    
    // For class notifications
    if (notification.type == 'Class' && notification.classId != null) {
      return _childrenData.any((child) {
        // Check if the child's classId matches the notification's classId
        if (child['classId'] is Map<String, dynamic>) {
          return child['classId']['_id'] == notification.classId;
        } else {
          return child['classId'] == notification.classId;
        }
      });
    }
    
    return false;
  }

  // Get notifications received by the current parent (including ones for their children)
  List<NotificationModel> _getReceivedNotifications() {
    return _notifications.where((notification) => 
      notification.type == 'Announcement' || 
      (notification.type == 'Parent' && notification.parentId == widget.user.id) ||
      _isNotificationForParentsChild(notification)).toList();
  }
  
  // Get notifications sent by the current parent (if any)
  // List<NotificationModel> _getSentNotifications() {
  //   return _notifications.where((notification) => 
  //     notification.createdBy == widget.user.id).toList();
  // }

  void _showSendMessageOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    'Send New Message',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _accentColor.withValues(alpha: 0.2),
                    child: Icon(Icons.person, color: _accentColor),
                  ),
                  title: const Text('Message to Teacher'),
                  subtitle: const Text('Send a message to your child\'s teacher'),
                  onTap: () {
                    Navigator.pop(context);
                    _showSendToTeacherDialog();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSendToTeacherDialog() async {
    final messageController = TextEditingController();
    String? selectedTeacherId;
    String? selectedChildId;
    Map<String, String> teacherMap = {};
    Map<String, String> childrenMap = {};
    bool isLoading = true;

    // Prepare children dropdown data
    for (var child in _childrenData) {
      if (child.containsKey('_id') && child.containsKey('name')) {
        childrenMap[child['_id']] = child['name'];
      }
    }

    try {
      // Load teachers
      final teachers = await _teacherService.getAllTeachers();
      for (var teacher in teachers) {
        if (teacher.containsKey('_id') && teacher.containsKey('name')) {
          teacherMap[teacher['_id']] = teacher['name'];
        }
      }
      isLoading = false;
    } catch (e) {
      print('Error loading teachers: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading teachers: $e')),
      );
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Row(
              children: [
                CircleAvatar(
                  backgroundColor: _accentColor.withValues(alpha: 0.2),
                  child: Icon(Icons.person, color: _accentColor),
                ),
                const SizedBox(width: 12),
                const Text('Message to Teacher'),
              ],
            ),
            content: isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (childrenMap.isNotEmpty) ...[
                          DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Regarding Child',
                              border: OutlineInputBorder(),
                            ),
                            hint: const Text('Choose a child'),
                            value: selectedChildId,
                            items: childrenMap.entries.map((entry) {
                              return DropdownMenuItem<String>(
                                value: entry.key,
                                child: Text(entry.value),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedChildId = value;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Select Teacher',
                            border: OutlineInputBorder(),
                          ),
                          hint: const Text('Choose a teacher'),
                          value: selectedTeacherId,
                          items: teacherMap.entries.map((entry) {
                            return DropdownMenuItem<String>(
                              value: entry.key,
                              child: Text(entry.value),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedTeacherId = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: messageController,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: 'Message',
                            hintText: 'Enter your message to the teacher',
                            border: OutlineInputBorder(),
                          ),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                ),
                onPressed: isLoading || selectedTeacherId == null
                    ? null
                    : () async {
                        if (messageController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a message')),
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
                          // Add child info to message if selected
                          String messageText = messageController.text;
                          if (selectedChildId != null && childrenMap.containsKey(selectedChildId)) {
                            messageText = "Regarding ${childrenMap[selectedChildId]}: $messageText";
                          }
                          
                          final success = await _notificationService.sendTeacherNotification(
                            teacherId: selectedTeacherId!,
                            message: messageText,
                          );
                          
                          Navigator.pop(context); // Dismiss loading indicator
                          
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Message sent to teacher successfully')),
                            );
                            _loadNotifications(); // Refresh notifications
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Failed to send message')),
                            );
                          }
                        } catch (e) {
                          Navigator.pop(context); // Dismiss loading indicator
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      },
                child: const Text('Send Message', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotifications,
            tooltip: 'Refresh Notifications',
          ),
        ],
        // bottom: TabBar(
        //   controller: _tabController,
        //   indicatorColor: Colors.white,
        //   tabs: const [
        //     Tab(text: 'Received'),
        //     // Tab(text: 'Sent'),
        //   ],
        // ),
      ),
      body: _isLoading
        ? Center(child: CircularProgressIndicator(color: _accentColor))
        : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: $_error', style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadNotifications,
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildReceivedNotificationsTab(),
                // _buildSentNotificationsTab(),
              ],
            ),
    );
  }
  
  Widget _buildReceivedNotificationsTab() {
    final receivedNotifications = _getReceivedNotifications();
    
    return receivedNotifications.isEmpty
      ? _buildEmptyState('No received notifications')
      : RefreshIndicator(
          onRefresh: _loadNotifications,
          color: _accentColor,
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: receivedNotifications.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              return _buildNotificationCard(receivedNotifications[index]);
            },
          ),
        );
  }

  
  
  Widget _buildEmptyState([String message = 'No Notifications']) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'re all caught up!',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildNotificationCard(NotificationModel notification) {
    // Try to get child name if this is a notification for a specific child
    String? childInfo;
    if (notification.type == 'Student' && notification.studentId != null) {
      final childData = _childrenData.firstWhere(
        (child) => child['_id'] == notification.studentId,
        orElse: () => <String, dynamic>{},
      );
      if (childData.isNotEmpty && childData.containsKey('name')) {
        childInfo = "About: ${childData['name']}";
      }
    }

    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: CircleAvatar(
          backgroundColor: notification.getTypeColor().withValues(alpha: 0.2),
          child: Icon(
            notification.getTypeIcon(),
            color: notification.getTypeColor(),
          ),
        ),
        title: Text(
          notification.type,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (childInfo != null) ...[
              Text(
                childInfo,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo[700],
                ),
              ),
              const SizedBox(height: 2),
            ],
            Text(
              notification.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (notification.createdBy != null && notification.createdBy!.isNotEmpty)
                  Text(
                    'From: ${notification.createdBy}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                const Spacer(),
                Text(
                  _getTimeText(notification.issuedAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () {
          _showNotificationDetails(notification);
        },
      ),
    );
  }
  
  String _getTimeText(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
  
  void _showNotificationDetails(NotificationModel notification) {
    // Try to get child name if this is a notification for a specific child
    String? childInfo;
    if (notification.type == 'Student' && notification.studentId != null) {
      final childData = _childrenData.firstWhere(
        (child) => child['_id'] == notification.studentId,
        orElse: () => <String, dynamic>{},
      );
      if (childData.isNotEmpty && childData.containsKey('name')) {
        childInfo = childData['name'];
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: notification.getTypeColor().withValues(alpha: 0.2),
                child: Icon(
                  notification.getTypeIcon(),
                  color: notification.getTypeColor(),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                notification.type,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (childInfo != null) ...[
                  _buildInfoRow(Icons.child_care, 'Regarding:', childInfo),
                  const SizedBox(height: 8),
                ],
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Text(
                    notification.message,
                    style: TextStyle(
                      color: Colors.grey[800],
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (notification.createdBy != null && notification.createdBy!.isNotEmpty)
                  _buildInfoRow(Icons.person, 'From:', notification.createdBy!),
                _buildInfoRow(
                  Icons.access_time, 
                  'Received:', 
                  '${notification.issuedAt.day}/${notification.issuedAt.month}/${notification.issuedAt.year} at ${notification.issuedAt.hour}:${notification.issuedAt.minute.toString().padLeft(2, '0')}'
                ),
                if (notification.getRecipientDescription().isNotEmpty)
                  _buildInfoRow(Icons.people, 'To:', notification.getRecipientDescription()),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Close', style: TextStyle(color: _primaryColor)),
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
