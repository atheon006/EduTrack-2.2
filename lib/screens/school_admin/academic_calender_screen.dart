import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/calendar_service.dart';
import '../../utils/constants.dart'; 

class CalendarEvent {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final EventCategory category;
  final bool isFullDay;
  final String? startTime;
  final String? endTime;
  
  CalendarEvent({
    this.id = '',
    required this.title,
    required this.description,
    required this.date,
    required this.category,
    this.isFullDay = true,
    this.startTime,
    this.endTime,
  });
  
  // Factory constructor to create from API response
  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    // Parse category string to enum (API uses 'type' instead of 'category')
    final String categoryStr = json['type'] ?? json['category'] ?? 'other';
    EventCategory category = EventCategory.other;
    
    try {
      category = EventCategory.values.firstWhere(
        (e) => e.toString().split('.').last.toLowerCase() == categoryStr.toLowerCase(),
        orElse: () => EventCategory.other,
      );
    } catch (_) {}
    
    return CalendarEvent(
      id: json['_id'] ?? json['id'] ?? '',
      // API uses 'name' instead of 'title'
      title: json['name'] ?? json['title'] ?? '',
      description: json['description'] ?? '',
      date: json['date'] != null 
          ? DateTime.tryParse(json['date']) ?? DateTime.now() 
          : DateTime.now(),
      category: category,
      isFullDay: json['isFullDay'] ?? true,
      startTime: json['startTime'],
      endTime: json['endTime'],
    );
  }
  
  // Convert to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'name': title,  // Changed from 'title' to 'name'
      'description': description,
      'date': date.toIso8601String(),
      'year': date.year,  // Added year field required by API
      'type': category.toString().split('.').last.toLowerCase(),  // Changed from 'category' to 'type'
      'isFullDay': isFullDay,
      if (startTime != null) 'startTime': startTime,
      if (endTime != null) 'endTime': endTime,
    };
  }
}

enum EventCategory {
  holiday,
  exam,
  schoolEvent,
  academicActivity,
  other,
}

extension EventCategoryExtension on EventCategory {
  String get displayName {
    switch (this) {
      case EventCategory.holiday:
        return 'Holiday';
      case EventCategory.exam:
        return 'Exam';
      case EventCategory.schoolEvent:
        return 'School Event';
      case EventCategory.academicActivity:
        return 'Academic Activity';
      case EventCategory.other:
        return 'Other';
    }
  }

  Color get color {
    switch (this) {
      case EventCategory.holiday:
        return const Color(0xFF43A047); // Deeper green
      case EventCategory.exam:
        return const Color(0xFFE53935); // Deeper red
      case EventCategory.schoolEvent:
        return const Color(0xFF8E24AA); // Rich purple
      case EventCategory.academicActivity:
        return const Color(0xFF1E88E5); // Rich blue
      case EventCategory.other:
        return const Color(0xFF757575); // Darker grey
    }
  }

  IconData get icon {
    switch (this) {
      case EventCategory.holiday:
        return Icons.beach_access;
      case EventCategory.exam:
        return Icons.assignment;
      case EventCategory.schoolEvent:
        return Icons.event;
      case EventCategory.academicActivity:
        return Icons.school;
      case EventCategory.other:
        return Icons.category;
    }
  }
}

class AcademicCalenderScreen extends StatefulWidget {
  const AcademicCalenderScreen({Key? key}) : super(key: key);

  @override
  State<AcademicCalenderScreen> createState() => _AcademicCalenderScreenState();
}

class _AcademicCalenderScreenState extends State<AcademicCalenderScreen> {
  late final ValueNotifier<List<CalendarEvent>> _selectedEvents;
  final Set<EventCategory> _selectedCategories = Set.from(EventCategory.values);
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  // Calendar events map
  final Map<DateTime, List<CalendarEvent>> _events = {};
  
  // Loading state
  bool _isLoading = true;
  
  // Calendar service instance
  late CalendarService _calendarService;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));
    
    // Initialize calendar service with your API base URL
    _calendarService = CalendarService(baseUrl:  Constants.apiBaseUrl);
    
    // Load events from API
    _loadEvents();
  }

  @override
  void dispose() {
    _selectedEvents.dispose();
    super.dispose();
  }
  
  // Load events from API
  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _events.clear();
    });
    
    try {
      final calendarItems = await _calendarService.getAllCalendarItems();
      
      // Convert API data to CalendarEvent objects
      for (var item in calendarItems) {
        final event = CalendarEvent.fromJson(item);
        final DateTime dateKey = DateTime(event.date.year, event.date.month, event.date.day);
        
        if (_events[dateKey] == null) {
          _events[dateKey] = [];
        }
        
        _events[dateKey]!.add(event);
      }
      
      setState(() {
        _isLoading = false;
      });
      
      // Update selected events if we have a selected day
      if (_selectedDay != null) {
        _selectedEvents.value = _getEventsForDay(_selectedDay!);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading calendar events: $e')),
      );
      
      // Add some sample data if API fails
      _initializeSampleEvents();
    }
  }
  
  // Add a single event
  Future<void> _addEventToAPI(
    DateTime date,
    String title,
    String description,
    EventCategory category,
    {bool isFullDay = true, String? startTime, String? endTime}
  ) async {
    try {
      // Convert EventCategory enum to string for API
      final categoryStr = category.toString().split('.').last.toLowerCase();
      
      // Make API request to create the event
      final result = await _calendarService.createCalendarItem(
        title: title,
        description: description,
        date: date,
        category: categoryStr,
        isFullDay: isFullDay,
        startTime: startTime,
        endTime: endTime,
      );
      
      // Create CalendarEvent from API response
      final newEvent = CalendarEvent.fromJson(result);
      
      // Add to local events map
      final DateTime dateKey = DateTime(newEvent.date.year, newEvent.date.month, newEvent.date.day);
      
      setState(() {
        if (_events[dateKey] == null) {
          _events[dateKey] = [];
        }
        _events[dateKey]!.add(newEvent);
        
        // Update selected events if this is the selected day
        if (_selectedDay != null && 
            dateKey.year == _selectedDay!.year &&
            dateKey.month == _selectedDay!.month &&
            dateKey.day == _selectedDay!.day) {
          _selectedEvents.value = _getEventsForDay(_selectedDay!);
        }
      });
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[100]),
              const SizedBox(width: 12),
              const Text('Event added successfully'),
            ],
          ),
          backgroundColor: Theme.of(context).primaryColor,
        ),
      );
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding event: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Delete an event by ID
  Future<void> _deleteEvent(String eventId, DateTime date) async {
    try {
      // Make API request to delete the event
      await _calendarService.deleteCalendarItem(eventId);
      
      // Create date key for events map
      final DateTime dateKey = DateTime(date.year, date.month, date.day);
      
      // Remove from local events map
      setState(() {
        if (_events[dateKey] != null) {
          _events[dateKey] = _events[dateKey]!
            .where((event) => event.id != eventId).toList();
          
          // Update selected events if this is the selected day
          if (_selectedDay != null && 
              dateKey.year == _selectedDay!.year &&
              dateKey.month == _selectedDay!.month &&
              dateKey.day == _selectedDay!.day) {
            _selectedEvents.value = _getEventsForDay(_selectedDay!);
          }
        }
      });
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event deleted successfully')),
      );
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting event: $e')),
      );
    }
  }
  
  // Update an existing event
  Future<void> _updateEvent(
    String eventId, 
    String title, 
    String description, 
    DateTime date,
    EventCategory category,
    {bool isFullDay = true, String? startTime, String? endTime}
  ) async {
    try {
      // Convert EventCategory enum to string for API
      final categoryStr = category.toString().split('.').last.toLowerCase();
      
      // Make API request to update the event
      final result = await _calendarService.updateCalendarItem(
        calendarId: eventId,
        title: title,
        description: description,
        date: date,
        category: categoryStr,
        isFullDay: isFullDay,
        startTime: startTime,
        endTime: endTime,
      );
      
      // Create CalendarEvent from API response
      final updatedEvent = CalendarEvent.fromJson(result);
      
      // Find old event to remove
      late DateTime oldDateKey;
      CalendarEvent? oldEvent;
      
      for (final entry in _events.entries) {
        final foundEvent = entry.value.firstWhere(
          (e) => e.id == eventId, 
          orElse: () => CalendarEvent(
            title: '', description: '', date: DateTime.now(), category: EventCategory.other
          )
        );
        
        if (foundEvent.id == eventId) {
          oldDateKey = entry.key;
          oldEvent = foundEvent;
          break;
        }
      }
      
      // Create new date key for updated event
      final newDateKey = DateTime(updatedEvent.date.year, updatedEvent.date.month, updatedEvent.date.day);
      
      setState(() {
        // Remove from old date if found
        if (oldEvent != null) {
          _events[oldDateKey] = _events[oldDateKey]!
            .where((e) => e.id != eventId).toList();
        }
        
        // Add to new date
        if (_events[newDateKey] == null) {
          _events[newDateKey] = [];
        }
        _events[newDateKey]!.add(updatedEvent);
        
        // Update selected events if this is the selected day
        if (_selectedDay != null) {
          _selectedEvents.value = _getEventsForDay(_selectedDay!);
        }
      });
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event updated successfully')),
      );
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating event: $e')),
      );
    }
  }

  void _initializeSampleEvents() {
    // Current academic year
    final int currentYear = DateTime.now().year;
    
    // Some sample events for fallback
    _addEvent(
      DateTime(currentYear, 8, 15),
      'Independence Day',
      'National Holiday - School Closed',
      EventCategory.holiday,
    );
    
    _addEvent(
      DateTime(currentYear, 10, 2),
      'Gandhi Jayanti',
      'National Holiday - School Closed',
      EventCategory.holiday,
    );
    
    _addEvent(
      DateTime(currentYear, 12, 1),
      'Mid-Term Examination',
      'Mid-term examination for all classes',
      EventCategory.exam,
    );
  }

  void _addEvent(DateTime date, String title, String description, EventCategory category) {
    final DateTime dateKey = DateTime(date.year, date.month, date.day);
    
    if (_events[dateKey] == null) {
      _events[dateKey] = [];
    }
    
    _events[dateKey]!.add(
      CalendarEvent(
        title: title,
        description: description,
        date: date,
        category: category,
      ),
    );
  }

  List<CalendarEvent> _getEventsForDay(DateTime day) {
    final DateTime dateKey = DateTime(day.year, day.month, day.day);
    final events = _events[dateKey] ?? [];
    
    // Filter events based on selected categories
    return events.where((event) => _selectedCategories.contains(event.category)).toList();
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });

      _selectedEvents.value = _getEventsForDay(selectedDay);
    }
  }

  void _toggleCategory(EventCategory category) {
    setState(() {
      if (_selectedCategories.contains(category)) {
        _selectedCategories.remove(category);
      } else {
        _selectedCategories.add(category);
      }
      
      if (_selectedDay != null) {
        _selectedEvents.value = _getEventsForDay(_selectedDay!);
      }
    });
  }

  // Single implementation of the build method
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Academic Calendar'),
        elevation: 2.0,
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: theme.scaffoldBackgroundColor,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (context) => _buildCategoryFilters(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEvents,
            tooltip: 'Refresh Calendar',
          ),
        ],
      ),
      body: _isLoading 
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Loading calendar events...',
                    style: TextStyle(color: theme.primaryColor),
                  ),
                ],
              ),
            )
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [theme.primaryColor.withValues(alpha: 0.05), Colors.white],
                ),
              ),
              child: Column(
                children: [
                  Card(
                    elevation: 4,
                    margin: const EdgeInsets.all(8.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TableCalendar(
                        firstDay: DateTime.utc(DateTime.now().year - 1, 1, 1),
                        lastDay: DateTime.utc(DateTime.now().year + 2, 12, 31),
                        focusedDay: _focusedDay,
                        calendarFormat: _calendarFormat,
                        eventLoader: (day) => _getEventsForDay(day),
                        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                        onDaySelected: _onDaySelected,
                        onFormatChanged: (format) {
                          if (_calendarFormat != format) {
                            setState(() {
                              _calendarFormat = format;
                            });
                          }
                        },
                        onPageChanged: (focusedDay) {
                          _focusedDay = focusedDay;
                        },
                        calendarStyle: CalendarStyle(
                          markerDecoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          todayDecoration: BoxDecoration(
                            color: theme.primaryColor.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          selectedDecoration: BoxDecoration(
                            color: theme.primaryColor,
                            shape: BoxShape.circle,
                          ),
                          outsideDaysVisible: false,
                          markersMaxCount: 3,
                          weekendTextStyle: TextStyle(color: theme.primaryColor.withValues(alpha: 0.7)),
                          holidayTextStyle: const TextStyle(color: Color(0xFFE53935)),
                        ),
                        headerStyle: HeaderStyle(
                          titleCentered: true,
                          formatButtonDecoration: BoxDecoration(
                            color: theme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          formatButtonTextStyle: TextStyle(color: theme.primaryColor),
                          leftChevronIcon: Icon(Icons.chevron_left, color: theme.primaryColor),
                          rightChevronIcon: Icon(Icons.chevron_right, color: theme.primaryColor),
                        ),
                        calendarBuilders: CalendarBuilders(
                          markerBuilder: (context, date, events) {
                            if (events.isEmpty) return const SizedBox.shrink();
                            
                            // Group events by category for the markers
                            final Map<EventCategory, int> categoryCount = {};
                            for (final event in events as List<CalendarEvent>) {
                              categoryCount[event.category] = (categoryCount[event.category] ?? 0) + 1;
                            }
                            
                            // Show dots instead of circles with numbers
                            return Positioned(
                              bottom: 2,
                              right: 2,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: categoryCount.keys.take(3).map((category) {
                                  return Container(
                                    margin: const EdgeInsets.only(left: 1),
                                    height: 5,
                                    width: 5,
                                    decoration: BoxDecoration(
                                      color: category.color,
                                      shape: BoxShape.circle,
                                    ),
                                  );
                                }).toList(),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildCategoryLegend(),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Row(
                      children: [
                        Icon(Icons.event_note, color: theme.primaryColor, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _selectedDay != null 
                              ? 'Events on ${DateFormat('MMMM dd, yyyy').format(_selectedDay!)}'
                              : 'No date selected',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: theme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Divider(height: 1, thickness: 1),
                  Expanded(
                    child: ValueListenableBuilder<List<CalendarEvent>>(
                      valueListenable: _selectedEvents,
                      builder: (context, events, _) {
                        return events.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.event_busy,
                                      size: 48,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No events for this day',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(8),
                                itemCount: events.length,
                                itemBuilder: (context, index) {
                                  final event = events[index];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    child: Card(
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                          color: event.category.color.withValues(alpha: 0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () => _showEventDetails(event),
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: event.category.color.withValues(alpha: 0.1),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  event.category.icon,
                                                  color: event.category.color,
                                                  size: 24,
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      event.title,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      event.description,
                                                      style: TextStyle(
                                                        color: Colors.grey[600],
                                                        fontSize: 13,
                                                      ),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Row(
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: event.category.color.withValues(alpha: 0.1),
                                                            borderRadius: BorderRadius.circular(12),
                                                          ),
                                                          child: Text(
                                                            event.category.displayName,
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color: event.category.color,
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    DateFormat('MMM dd').format(event.date),
                                                    style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    DateFormat('EEEE').format(event.date),
                                                    style: TextStyle(
                                                      color: Colors.grey[500],
                                                      fontSize: 12,
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
                                },
                              );
                      },
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddEventDialog,
        backgroundColor: theme.primaryColor,
        elevation: 4,
        tooltip: 'Add Event',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCategoryLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: EventCategory.values.map((category) {
              final bool isSelected = _selectedCategories.contains(category);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  avatar: CircleAvatar(
                    backgroundColor: isSelected ? category.color : Colors.grey[300],
                    child: Icon(
                      category.icon,
                      color: isSelected ? Colors.white : Colors.grey,
                      size: 16,
                    ),
                  ),
                  label: Text(
                    category.displayName,
                    style: TextStyle(
                      color: isSelected ? category.color : Colors.grey[600],
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                  backgroundColor: isSelected ? category.color.withValues(alpha: 0.1) : Colors.grey[100],
                  selectedColor: category.color.withValues(alpha: 0.2),
                  checkmarkColor: category.color,
                  selected: isSelected,
                  onSelected: (selected) => _toggleCategory(category),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected ? category.color : Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilters() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filter by Category',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
              ),
              TextButton.icon(
                icon: Icon(
                  _selectedCategories.length == EventCategory.values.length
                      ? Icons.clear_all
                      : Icons.select_all,
                  color: theme.primaryColor,
                ),
                label: Text(
                  _selectedCategories.length == EventCategory.values.length
                      ? 'Deselect All'
                      : 'Select All',
                  style: TextStyle(color: theme.primaryColor),
                ),
                onPressed: () {
                  setState(() {
                    if (_selectedCategories.length == EventCategory.values.length) {
                      // Deselect all if all are selected
                      _selectedCategories.clear();
                    } else {
                      // Select all if not all are selected
                      _selectedCategories.clear();
                      _selectedCategories.addAll(EventCategory.values);
                    }
                    
                    if (_selectedDay != null) {
                      _selectedEvents.value = _getEventsForDay(_selectedDay!);
                    }
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Divider(),
          const SizedBox(height: 4),
          Column(
            children: EventCategory.values.map((category) {
              final bool isSelected = _selectedCategories.contains(category);
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: isSelected ? category.color.withValues(alpha: 0.1) : Colors.transparent,
                ),
                child: CheckboxListTile(
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: category.color.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(category.icon, color: category.color, size: 20),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        category.displayName,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  value: isSelected,
                  activeColor: category.color,
                  checkColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  onChanged: (bool? value) {
                    if (value != null) {
                      setState(() {
                        if (value) {
                          _selectedCategories.add(category);
                        } else {
                          _selectedCategories.remove(category);
                        }
                        
                        if (_selectedDay != null) {
                          _selectedEvents.value = _getEventsForDay(_selectedDay!);
                        }
                      });
                    }
                  },
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _showEventDetails(CalendarEvent event) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: event.category.color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(event.category.icon, color: event.category.color, size: 24),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: event.category.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        event.category.displayName,
                        style: TextStyle(
                          color: event.category.color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('EEEE, MMMM dd, yyyy').format(event.date),
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              event.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Description',
              style: TextStyle(
                fontWeight: FontWeight.bold, 
                fontSize: 16,
                color: theme.primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Text(
                event.description.isEmpty ? 'No description provided' : event.description,
                style: TextStyle(
                  height: 1.5,
                  color: Colors.grey[800],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.primaryColor,
                      side: BorderSide(color: theme.primaryColor),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _showEditEventDialog(event);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: event.id.isNotEmpty
                      ? ElevatedButton.icon(
                          icon: const Icon(Icons.delete, color: Colors.white),
                          label: const Text('Delete', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _showDeleteConfirmation(event);
                          },
                        )
                      : ElevatedButton.icon(
                          icon: const Icon(Icons.share, color: Colors.white),
                          label: const Text('Share', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            Share.share(
                              '${event.title}\nDate: ${DateFormat('MMM dd, yyyy').format(event.date)}\nCategory: ${event.category.displayName}\n\n${event.description}',
                            );
                          },
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  void _showDeleteConfirmation(CalendarEvent event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Are you sure you want to delete "${event.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (event.id.isNotEmpty) {
                _deleteEvent(event.id, event.date);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cannot delete this event')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }
  
  void _showEditEventDialog(CalendarEvent event) {
    final theme = Theme.of(context);
    final titleController = TextEditingController(text: event.title);
    final descriptionController = TextEditingController(text: event.description);
    DateTime selectedDate = event.date;
    EventCategory selectedCategory = event.category;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.edit, color: theme.primaryColor),
            const SizedBox(width: 8),
            const Text('Edit Calendar Event'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Event Title',
                  hintText: 'Enter event title',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.title),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'Enter event description',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.description),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[400]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  leading: const Icon(Icons.calendar_today),
                  title: Text('Date: ${DateFormat('MMM dd, yyyy').format(selectedDate)}'),
                  onTap: () async {
                    final DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(DateTime.now().year - 1),
                      lastDate: DateTime(DateTime.now().year + 2),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.light(
                              primary: theme.primaryColor,
                              onPrimary: Colors.white,
                              onSurface: Colors.black,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (pickedDate != null) {
                      setState(() {
                        selectedDate = pickedDate;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<EventCategory>(
                value: selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Event Category',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.category),
                ),
                items: EventCategory.values.map((category) {
                  return DropdownMenuItem<EventCategory>(
                    value: category,
                    child: Row(
                      children: [
                        Icon(category.icon, color: category.color, size: 20),
                        const SizedBox(width: 8),
                        Text(category.displayName),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    selectedCategory = value;
                  }
                },
              ),
            ],
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                if (event.id.isNotEmpty) {
                  _updateEvent(
                    event.id,
                    titleController.text,
                    descriptionController.text,
                    selectedDate,
                    selectedCategory,
                  );
                } else {
                  // This is a local event without an ID, so we need to add a new one
                  _addEventToAPI(
                    selectedDate,
                    titleController.text,
                    descriptionController.text,
                    selectedCategory,
                  );
                }
                Navigator.pop(context);
              } else {
                // Show validation error
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Event title is required'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('SAVE CHANGES'),
          ),
        ],
      ),
    );
  }

  void _showAddEventDialog() {
    final theme = Theme.of(context);
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime selectedDate = _selectedDay ?? DateTime.now();
    EventCategory selectedCategory = EventCategory.academicActivity;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.event_available, color: theme.primaryColor),
            const SizedBox(width: 8),
            const Text('Add Calendar Event'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Event Title',
                  hintText: 'Enter event title',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.title),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'Enter event description',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.description),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[400]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  leading: const Icon(Icons.calendar_today),
                  title: Text('Date: ${DateFormat('MMM dd, yyyy').format(selectedDate)}'),
                  onTap: () async {
                    final DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(DateTime.now().year - 1),
                      lastDate: DateTime(DateTime.now().year + 2),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.light(
                              primary: theme.primaryColor,
                              onPrimary: Colors.white,
                              onSurface: Colors.black,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (pickedDate != null) {
                      setState(() {
                        selectedDate = pickedDate;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<EventCategory>(
                value: selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Event Category',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.category),
                ),
                items: EventCategory.values.map((category) {
                  return DropdownMenuItem<EventCategory>(
                    value: category,
                    child: Row(
                      children: [
                        Icon(category.icon, color: category.color, size: 20),
                        const SizedBox(width: 8),
                        Text(category.displayName),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    selectedCategory = value;
                  }
                },
              ),
            ],
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                _addEventToAPI(
                  selectedDate,
                  titleController.text,
                  descriptionController.text,
                  selectedCategory,
                );
                
                Navigator.pop(context);
              } else {
                // Show validation error
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Event title is required'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('ADD EVENT'),
          ),
        ],
      ),
    );
  }
}
