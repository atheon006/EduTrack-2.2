import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/notification_model.dart';
import '../../services/notification_service.dart';
import '../../services/student_service.dart';
import '../../services/parent_service.dart';
import '../../services/class_services.dart';
import '../../utils/constants.dart'; // Import constants for base URL

class TeacherNotificationsScreen extends StatefulWidget {
  final User user;

  const TeacherNotificationsScreen({Key? key, required this.user}) : super(key: key);

  @override
  _TeacherNotificationsScreenState createState() => _TeacherNotificationsScreenState();
}

class _TeacherNotificationsScreenState extends State<TeacherNotificationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _error;
  final List<NotificationModel> _notifications = [];
  
  // Services
  final NotificationService _notificationService = NotificationService();
  late StudentService _studentService;
  late ParentService _parentService;
  late ClassService _classService;
  
  // Light theme colors to match attendance screen
  final Color _primaryColor = const Color(0xFF5E63B6);
  final Color _backgroundColor = const Color(0xFFF5F7FA);
  final Color _cardColor = Colors.white;
  final Color _textPrimaryColor = const Color(0xFF333333);
  final Color _textSecondaryColor = const Color(0xFF717171);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _studentService = StudentService(baseUrl: Constants.apiBaseUrl);
    _parentService = ParentService(baseUrl: Constants.apiBaseUrl);
    _classService = ClassService(baseUrl: Constants.apiBaseUrl);
    _loadNotifications();
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
        // Filter notifications to only include ones relevant to this teacher
        _notifications.clear();
        for (var notification in allNotifications) {
          // Include notifications where:
          // 1. This teacher is the creator
          // 2. The notification type is 'Teacher' and the teacherId matches this teacher
          // 3. The notification type is 'Announcement'
          if (notification.createdBy == widget.user.id || 
              notification.type == 'Announcement' ||
              (notification.type == 'Teacher' && notification.teacherId == widget.user.id)) {
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

  // Get notifications created by the current teacher
  List<NotificationModel> _getMyNotifications() {
    return _notifications.where((notification) => 
      notification.createdBy == widget.user.id).toList();
  }
  
  // Get notifications sent to the current teacher
  List<NotificationModel> _getReceivedNotifications() {
    return _notifications.where((notification) => 
      notification.type == 'Announcement' || 
      (notification.type == 'Teacher' && notification.teacherId == widget.user.id)).toList();
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'info': return Icons.info;
      case 'success': return Icons.check_circle;
      case 'warning': return Icons.warning;
      case 'error': return Icons.error;
      case 'request': return Icons.question_answer;
      default: return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'info': return const Color(0xFF2196F3);
      case 'success': return const Color(0xFF43A047);
      case 'warning': return const Color(0xFFFF9800);
      case 'error': return const Color(0xFFE53935);
      case 'request': return const Color(0xFF5E63B6);
      default: return Colors.grey;
    }
  }

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
                      color: _textPrimaryColor,
                    ),
                  ),
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: Icon(Icons.group, color: Colors.blue.shade700),
                  ),
                  title: const Text('Send to Class'),
                  subtitle: const Text('Send a message to an entire class'),
                  onTap: () {
                    Navigator.pop(context);
                    _showSendToClassDialog();
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.shade100,
                    child: Icon(Icons.person, color: Colors.green.shade700),
                  ),
                  title: const Text('Send to Student'),
                  subtitle: const Text('Send a message to an individual student'),
                  onTap: () {
                    Navigator.pop(context);
                    _showSendToStudentDialog();
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange.shade100,
                    child: Icon(Icons.family_restroom, color: Colors.orange.shade700),
                  ),
                  title: const Text('Send to Parent'),
                  subtitle: const Text('Send a message to a parent'),
                  onTap: () {
                    Navigator.pop(context);
                    _showSendToParentDialog();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSendToClassDialog() async {
    final messageController = TextEditingController();
    String? selectedClassId;
    Map<String, String> classMap = {};
    bool isLoading = true;

    try {
      // Load classes
      final classes = await _classService.getAllClasses();
      for (var classData in classes) {
        if (classData.containsKey('_id') && classData.containsKey('name')) {
          classMap[classData['_id']] = classData['name'];
        }
      }
      isLoading = false;
    } catch (e) {
      print('Error loading classes: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading classes: $e')),
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
                  backgroundColor: Colors.purpleAccent.shade200,
                  child: const Icon(Icons.class_, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Text('Message to Class'),
              ],
            ),
            content: isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Select Class',
                            border: OutlineInputBorder(),
                          ),
                          hint: const Text('Choose a class'),
                          value: selectedClassId,
                          items: classMap.entries.map((entry) {
                            return DropdownMenuItem<String>(
                              value: entry.key,
                              child: Text(entry.value),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedClassId = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: messageController,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: 'Message',
                            hintText: 'Enter your message to the class',
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
                  backgroundColor: Colors.purpleAccent.shade200,
                ),
                onPressed: isLoading || selectedClassId == null
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
                          final success = await _notificationService.sendNotification(
                            type: 'Class',
                            message: messageController.text,
                            audience: [],
                            classId: selectedClassId,
                          );
                          
                          Navigator.pop(context); // Dismiss loading indicator
                          
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Message sent to class successfully')),
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
                child: const Text('Send to Class', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSendToStudentDialog() async {
    final messageController = TextEditingController();
    String? selectedStudentId;
    Map<String, String> studentMap = {};
    bool isLoading = true;

    try {
      // Load students
      final students = await _studentService.getAllStudents();
      for (var student in students) {
        if (student.containsKey('_id') && student.containsKey('name')) {
          studentMap[student['_id']] = student['name'];
        }
      }
      isLoading = false;
    } catch (e) {
      print('Error loading students: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading students: $e')),
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
                const SizedBox(width: 14),
                const Text('Message to Student'),
              ],
            ),
            content: isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Select Student',
                            border: OutlineInputBorder(),
                          ),
                          hint: const Text('Choose a student'),
                          value: selectedStudentId,
                          items: studentMap.entries.map((entry) {
                            return DropdownMenuItem<String>(
                              value: entry.key,
                              child: Text(entry.value),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedStudentId = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: messageController,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: 'Message',
                            hintText: 'Enter your message to the student',
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
                  backgroundColor: Colors.tealAccent.shade400,
                ),
                onPressed: isLoading || selectedStudentId == null
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
                        BuildContext dialogContext;
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (BuildContext context) {
                            dialogContext = context;
                            return const Center(child: CircularProgressIndicator());
                          },
                        );
                        
                        try {
                          final success = await _notificationService.sendStudentNotification(
                            type: 'Student', // Explicitly set the type
                            message: messageController.text,
                            studentId: selectedStudentId!,
                          );
                          

                          
                          // Show success message regardless of response content
                          // since a status code of 201 indicates success
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Message sent to student successfully')),
                          );
                          
                          // Refresh the notifications list
                          _loadNotifications();
                        } catch (e) {
               
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      },
                child: const Text('Send to Student', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSendToParentDialog() async {
    final messageController = TextEditingController();
    String? selectedParentId;
    Map<String, String> parentMap = {};
    bool isLoading = true;

    try {
      // Load parents
      final parents = await _parentService.getAllParents();
      for (var parent in parents) {
        if (parent.containsKey('_id') && parent.containsKey('name')) {
          parentMap[parent['_id']] = parent['name'];
        }
      }
      isLoading = false;
    } catch (e) {
      print('Error loading parents: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading parents: $e')),
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
                  backgroundColor: Colors.pinkAccent.shade200,
                  child: const Icon(Icons.family_restroom, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Text('Message to Parent'),
              ],
            ),
            content: isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Select Parent',
                            border: OutlineInputBorder(),
                          ),
                          hint: const Text('Choose a parent'),
                          value: selectedParentId,
                          items: parentMap.entries.map((entry) {
                            return DropdownMenuItem<String>(
                              value: entry.key,
                              child: Text(entry.value),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedParentId = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: messageController,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: 'Message',
                            hintText: 'Enter your message to the parent',
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
                  backgroundColor: Colors.pinkAccent.shade200,
                ),
                onPressed: isLoading || selectedParentId == null
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
                          final success = await _notificationService.sendNotification(
                            type: 'Parent',
                            message: messageController.text,
                            audience: [],
                            parentId: selectedParentId,
                          );
                          
                          Navigator.pop(context); // Dismiss loading indicator
                          
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Message sent to parent successfully')),
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
                child: const Text('Send to Parent', style: TextStyle(color: Colors.white)),
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
      backgroundColor: _backgroundColor,
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Received'),
            Tab(text: 'Sent'),
          ],
        ),
      ),
      body: _isLoading
        ? Center(child: CircularProgressIndicator(color: _primaryColor))
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
                _buildSentNotificationsTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'new_message',
        onPressed: _showSendMessageOptions,
        backgroundColor: const Color(0xFF43A047),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
        tooltip: 'Send New Message',
      ),
    );
  }
  
  Widget _buildReceivedNotificationsTab() {
    final receivedNotifications = _getReceivedNotifications();
    
    return receivedNotifications.isEmpty
      ? _buildEmptyState('No received notifications')
      : RefreshIndicator(
          onRefresh: _loadNotifications,
          child: ListView.separated(
            itemCount: receivedNotifications.length,
            separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFEEEEEE)),
            itemBuilder: (context, index) {
              return _buildNotificationCard(receivedNotifications[index]);
            },
          ),
        );
  }
  
  Widget _buildSentNotificationsTab() {
    final sentNotifications = _getMyNotifications();
    
    return sentNotifications.isEmpty
      ? _buildEmptyState('No sent notifications')
      : RefreshIndicator(
          onRefresh: _loadNotifications,
          child: ListView.separated(
            itemCount: sentNotifications.length,
            separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFEEEEEE)),
            itemBuilder: (context, index) {
              return _buildNotificationCard(sentNotifications[index]);
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
            color: _textSecondaryColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'re all caught up!',
            style: TextStyle(
              fontSize: 16,
              color: _textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildNotificationCard(NotificationModel notification) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0,
      color: _cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: notification.getTypeColor().withValues(alpha: 0.2),
          child: Icon(
            notification.getTypeIcon(),
            color: notification.getTypeColor(),
          ),
        ),
        title: Text(
          notification.type,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _textPrimaryColor,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _textSecondaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (notification.createdBy != null && notification.createdBy!.isNotEmpty)
                  Text(
                    'From: ${notification.createdBy}',
                    style: TextStyle(
                      fontSize: 12,
                      color: _textSecondaryColor,
                    ),
                  )
                else
                  Text(
                    notification.getRecipientDescription(),
                    style: TextStyle(
                      fontSize: 12,
                      color: _textSecondaryColor,
                    ),
                  ),
                const Spacer(),
                Text(
                  _getTimeText(notification.issuedAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: _textSecondaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () {
          _showNotificationDetails(notification);
        },
        onLongPress: () {
          _showNotificationActions(notification);
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
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            notification.type,
            style: TextStyle(color: _textPrimaryColor),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notification.message,
                style: TextStyle(color: _textPrimaryColor),
              ),
              const SizedBox(height: 16),
              if (notification.createdBy != null && notification.createdBy!.isNotEmpty)
                Text(
                  'From: ${notification.createdBy}',
                  style: TextStyle(
                    fontSize: 14,
                    color: _textSecondaryColor,
                  ),
                ),
              Text(
                'Received: ${notification.issuedAt.toString().split('.')[0]}',
                style: TextStyle(
                  fontSize: 14,
                  color: _textSecondaryColor,
                ),
              ),
              if (notification.getRecipientDescription().isNotEmpty)
                Text(
                  'To: ${notification.getRecipientDescription()}',
                  style: TextStyle(
                    fontSize: 14,
                    color: _textSecondaryColor,
                  ),
                ),
            ],
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
  
  void _showNotificationActions(NotificationModel notification) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (notification.createdBy == widget.user.id)
                ListTile(
                  leading: Icon(Icons.delete, color: Colors.red[700]),
                  title: Text(
                    'Delete',
                    style: TextStyle(color: _textPrimaryColor),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    
                    try {
                      // Show loading indicator
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(child: CircularProgressIndicator()),
                      );
                      
                      final success = await _notificationService.deleteNotification(notification.id);
                      
                      Navigator.pop(context); // Dismiss loading indicator
                      
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Notification deleted successfully')),
                        );
                        _loadNotifications(); // Refresh the list
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to delete notification')),
                        );
                      }
                    } catch (e) {
                      Navigator.pop(context); // Dismiss loading indicator
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  },
                ),
              if (notification.type == 'Student' || notification.type == 'Parent' || notification.type == 'Class')
                ListTile(
                  leading: Icon(Icons.reply, color: _primaryColor),
                  title: Text(
                    'Send Another Message',
                    style: TextStyle(color: _textPrimaryColor),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showSendMessageOptions();
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
