import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/form_model.dart';
import '../../services/form_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import 'package:intl/intl.dart';

class FormsScreen extends StatefulWidget {
  final User user;

  const FormsScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<FormsScreen> createState() => _FormsScreenState();
}

class _FormsScreenState extends State<FormsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  bool _isFormsLoaded = false;
  List<Map<String, dynamic>> _submittedForms = [];
  List<FormType> _formTypesList = [];
  
  // Services
  final FormService _formService = FormService(baseUrl: Constants.apiBaseUrl);
  
  // Theme colors
  late Color _accentColor;
  late List<Color> _gradientColors;
  
  // Form types mapping - display name to code
  final Map<String, String> _formTypeMapping = {
    'Leave Request': 'leave_request',
    'Event Participation': 'event_participation',
    'Feedback': 'feedback',
    'Other Request': 'other'
  };
  
  // Form fields
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedFormType = 'Leave Request';
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  List<String> _formTypes = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadThemeColors();
    
    // Initialize form types from the predefined mapping
    _initializeFormTypes();
    
    // Delay adding the listener to prevent it from firing immediately on initialization
    Future.microtask(() {
      _tabController.addListener(_handleTabChange);
    });
  }
  
  // Initialize form types locally instead of calling the API
  void _initializeFormTypes() {
    // Use the form type mapping keys to populate the dropdown
    _formTypes = _formTypeMapping.keys.toList();
    
    // Set default selected form type
    if (_formTypes.isNotEmpty) {
      _selectedFormType = _formTypes[0];
    }
    
    // Create FormType objects for internal use
    _formTypesList = _formTypes.map((type) => FormType(
      id: '${_formTypes.indexOf(type) + 1}',
      name: type,
      code: _formTypeMapping[type] ?? 'other',
      description: 'Request',
    )).toList();
  }
  
  void _handleTabChange() {
    // Only load forms when the user explicitly switches to the My Forms tab
    if (_tabController.index == 1 && !_isFormsLoaded && _tabController.indexIsChanging) {
      // Only load forms when the user clicks on "My Forms" tab
      _loadStudentForms();
    }
  }

  void _loadThemeColors() {
    _accentColor = AppTheme.getAccentColor(AppTheme.defaultTheme);
    _gradientColors = AppTheme.getGradientColors(AppTheme.defaultTheme);
  }
  
  
  Future<void> _loadStudentForms() async {
    setState(() {
      _isLoading = true;
      _isFormsLoaded = true; // Mark forms as loaded to prevent duplicate requests
    });
    
    print('📋 Loading forms for student: ${widget.user.id}');
    
    try {
      final response = await _formService.getStudentForms(widget.user.id);
      
      if (response.success && response.data != null) {
        final List<dynamic> formsJson = response.data;
        print('📋 Received ${formsJson.length} forms from API');
        
        final List<FormData> forms = [];
        
        // Process each form with error handling
        for (var json in formsJson) {
          try {
            final form = FormData.fromJson(json);
            forms.add(form);
            print('📋 Parsed form: ${form.id} - ${form.type} - ${form.status}');
          } catch (e) {
            print('Error parsing form data: $e');
            // Continue processing other forms even if one fails
          }
        }
        
        // Convert FormData objects to the UI format
        _submittedForms = [];
        for (var form in forms) {
          try {
            final uiMap = form.toUIMap();
            _submittedForms.add(uiMap);
            print('📋 Added form to UI: ${uiMap['id']} - ${uiMap['status']}');
          } catch (e) {
            print('Error converting form to UI map: $e');
            // Continue processing other forms
          }
        }
        
        print('📋 Total forms for UI: ${_submittedForms.length}');
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load forms: ${response.message}'),
            backgroundColor: Colors.red,
          ),
        );
        
        // Use empty list if API fails
        _submittedForms = [];
      }
    } catch (e) {
      // Handle error
      print('Error loading student forms: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading forms: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      
      // Use empty list if API fails
      _submittedForms = [];
    }
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      // Show loading indicator
      setState(() {
        _isLoading = true;
      });
      
      // Get the form type code from mapping or from API response
      String formTypeCode;
      
      // First try to get code from API response
      if (_formTypesList.isNotEmpty) {
        final selectedType = _formTypesList.firstWhere(
          (type) => type.name == _selectedFormType,
          orElse: () => FormType(
            id: '1', 
            name: _selectedFormType, 
            code: _formTypeMapping[_selectedFormType] ?? 'other',
            description: 'Request',
          ),
        );
        formTypeCode = selectedType.code;
      } else {
        // If API hasn't provided types, use our mapping
        formTypeCode = _formTypeMapping[_selectedFormType] ?? 'other';
      }
      
      // Prepare form data based on type
      Map<String, dynamic> formData = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
      };
      
      // Additional fields based on form type
      if (formTypeCode == 'leave_request') {
        formData['reason'] = _titleController.text;
        formData['startDate'] = DateFormat('yyyy-MM-dd').format(_selectedDate);
        formData['endDate'] = DateFormat('yyyy-MM-dd').format(
          _selectedDate.add(const Duration(days: 1))
        );
      }
      
      try {
        final response = await _formService.submitForm(
          studentId: widget.user.id,
          type: formTypeCode,
          data: formData,
        );
        
        if (response.success && response.data != null) {
          // Reset the forms loaded flag so we fetch fresh data next time
          _isFormsLoaded = false;
          
          try {
            // Create new form from response
            final newFormData = FormData.fromJson(response.data);
            
            // Check if FormData was created successfully
            if (newFormData != null) {
              final newForm = newFormData.toUIMap();
              
              setState(() {
                // Only add form if it's valid
                if (newForm.containsKey('id') && newForm['id'] != null) {
                  _submittedForms.add(newForm);
                }
                _isLoading = false;
                
                // Reset form fields
                _titleController.clear();
                _descriptionController.clear();
                _selectedFormType = _formTypes.isNotEmpty ? _formTypes[0] : 'Leave Request';
                _selectedDate = DateTime.now().add(const Duration(days: 1));
                
                // Switch to My Forms tab
                _tabController.animateTo(1);
                
                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Form submitted successfully!'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              });
            } else {
              setState(() {
                _isLoading = false;
              });
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Error processing form data. Please try again.'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          } catch (parseError) {
            print('Error parsing form data: $parseError');
            setState(() {
              _isLoading = false;
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error processing form: ${parseError.toString()}'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          
          // Load the forms after submission with a small delay to ensure database update
          Future.delayed(const Duration(milliseconds: 500), () {
            _loadStudentForms();
          });
        } else {
          setState(() {
            _isLoading = false;
          });
          
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to submit form: ${response.message}'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.getTheme(AppTheme.defaultTheme),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Forms & Requests', style: TextStyle(fontWeight: FontWeight.bold)),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            tabs: const [
              Tab(text: 'Submit Form'),
              Tab(text: 'My Forms'),  // Renamed from "Request Status" to "My Forms"
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // First tab - Submit Form
            _isLoading && _tabController.index == 0
              ? Center(child: CircularProgressIndicator(color: _accentColor))
              : _buildSubmitFormTab(),
            
            // Second tab - My Forms
            _isLoading && _tabController.index == 1
              ? Center(child: CircularProgressIndicator(color: _accentColor))
              : _buildRequestStatusTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitFormTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('New Request Form'),
            const SizedBox(height: 16),
            
            // Form type dropdown
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Form Type',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _selectedFormType,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                        ),
                        items: _formTypes.map((String type) {
                          return DropdownMenuItem<String>(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedFormType = newValue;
                            });
                          }
                        },
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    const Text(
                      'Title',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        hintText: 'Enter a title for your request',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    const Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        hintText: 'Provide details about your request',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a description';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    const Text(
                      'Date',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null && picked != _selectedDate) {
                          setState(() {
                            _selectedDate = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Submit Request',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestStatusTab() {
    // Only try to load forms if we're actively viewing this tab
    if (!_isFormsLoaded && _tabController.index == 1) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.refresh,
              size: 60,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Tap to load your forms',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadStudentForms,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                'Load Forms',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      );
    }
    
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: _accentColor),
      );
    }
    
    print('📋 Forms to display: ${_submittedForms.length}');
    
    if (_submittedForms.isEmpty) {
      // Show empty state when no forms are found
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No forms submitted yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Submit a form to see it here',
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    _tabController.animateTo(0); // Switch to Submit Form tab
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text(
                    'Create New Form',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _loadStudentForms,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Show list of forms
    return RefreshIndicator(
      onRefresh: _loadStudentForms,
      color: _accentColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _submittedForms.length,
        itemBuilder: (context, index) {
          final form = _submittedForms[index];
          return _buildRequestCard(form);
        },
      ),
      );
  }
  
  Widget _buildRequestCard(Map<String, dynamic> form) {
    Color statusColor;
    IconData statusIcon;
    
    switch (form['status']) {
      case 'Approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'Rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _showFormDetails(form);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      form['id'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          form['status'],
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                form['title'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                form['type'],
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Submitted: ${DateFormat('MMM d, yyyy').format(form['submissionDate'])}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.event, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Requested: ${DateFormat('MMM d, yyyy').format(form['requestedDate'])}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              if (form['status'] == 'Approved' || form['status'] == 'Rejected')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 24),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: statusColor.withValues(alpha: 0.2),
                          child: Icon(
                            form['status'] == 'Approved' ? Icons.person : Icons.person_outline,
                            color: statusColor,
                            size: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          form['responder'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
      );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
              color: _accentColor,
              borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
  
  void _showFormDetails(Map<String, dynamic> form) {
    Color statusColor;
    IconData statusIcon;
    
    switch (form['status']) {
      case 'Approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'Rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Request Details',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(statusIcon, color: statusColor, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                form['status'],
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    _detailItem('Request ID', form['id']),
                    _detailItem('Type', form['type']),
                    _detailItem('Title', form['title']),
                    _detailItem('Description', form['description'], isMultiLine: true),
                    _detailItem('Submission Date', DateFormat('MMMM d, yyyy').format(form['submissionDate'])),
                    _detailItem('Requested Date', DateFormat('MMMM d, yyyy').format(form['requestedDate'])),
                    if (form['status'] != 'Pending') ...[
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.comment, color: statusColor),
                                const SizedBox(width: 8),
                                Text(
                                  'Response',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: statusColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              form['responseMessage'],
                              style: const TextStyle(fontSize: 15),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: statusColor.withValues(alpha: 0.2),
                                  child: Icon(
                                    Icons.person,
                                    color: statusColor,
                                    size: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Responded by: ${form['responder']}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    if (form['status'] == 'Pending')
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            _cancelForm(form);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Cancel Request',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    if (form['status'] != 'Pending')
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            _submitAgain(form);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accentColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Submit Again',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              );
          },
        );
      },
    );
  }
  
  Widget _detailItem(String label, String value, {bool isMultiLine = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _cancelForm(Map<String, dynamic> form) async {
    try {
      Navigator.pop(context);
      setState(() {
        _isLoading = true;
      });
      
      // Get form ID from the form map
      final String formId = form['id'];
      
      // Call API to update form status to cancelled
      final response = await _formService.updateFormStatus(
        formId: formId,
        status: 'cancelled',
        reviewComment: 'Cancelled by student',
      );
      
      setState(() {
        _isLoading = false;
      });
      
      if (response.success) {
        // Mark forms as not loaded to force a refresh
        _isFormsLoaded = false;
        
        // Update the local state
        setState(() {
          final index = _submittedForms.indexWhere((f) => f['id'] == formId);
          if (index != -1) {
            _submittedForms.removeAt(index);
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request cancelled successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Refresh forms list
        _loadStudentForms();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel request: ${response.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cancelling request: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _submitAgain(Map<String, dynamic> form) async {
    try {
      Navigator.pop(context);
      setState(() {
        _isLoading = true;
      });
      
      // Get form type code from mapping or from existing form
      String formTypeCode;
      
      // First try to get code from API response
      if (_formTypesList.isNotEmpty) {
        final selectedType = _formTypesList.firstWhere(
          (type) => type.name == form['type'],
          orElse: () => FormType(
            id: '1', 
            name: form['type'], 
            code: _formTypeMapping[form['type']] ?? 'other',
            description: 'Request',
          ),
        );
        formTypeCode = selectedType.code;
      } else {
        // If API hasn't provided types, use our mapping
        formTypeCode = _formTypeMapping[form['type']] ?? 'other';
      }
      
      // Prepare form data based on existing form
      Map<String, dynamic> formData = {
        'title': form['title'],
        'description': form['description'],
        'date': DateFormat('yyyy-MM-dd').format(form['requestedDate']),
      };
      
      // Additional fields based on form type
      if (formTypeCode == 'leave_request') {
        formData['reason'] = form['title'];
        formData['startDate'] = DateFormat('yyyy-MM-dd').format(form['requestedDate']);
        formData['endDate'] = DateFormat('yyyy-MM-dd').format(
          form['requestedDate'].add(const Duration(days: 1))
        );
      }
      
      // Submit new form with the same data
      final response = await _formService.submitForm(
        studentId: widget.user.id,
        type: formTypeCode,
        data: formData,
      );
      
      setState(() {
        _isLoading = false;
      });
      
      if (response.success) {
        // Mark forms as not loaded to force a refresh
        _isFormsLoaded = false;
        
        // Create new form from response
        final newFormData = FormData.fromJson(response.data);
        final newForm = newFormData.toUIMap();
        
        setState(() {
          _submittedForms.add(newForm);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request submitted again successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Refresh forms list
        _loadStudentForms();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit request: ${response.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting request: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
