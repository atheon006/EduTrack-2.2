import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../utils/app_theme.dart';
import 'package:intl/intl.dart';

class ParentFeeManagementScreen extends StatefulWidget {
  final User user;

  const ParentFeeManagementScreen({Key? key, required this.user}) : super(key: key);

  @override
  _ParentFeeManagementScreenState createState() => _ParentFeeManagementScreenState();
}

class _ParentFeeManagementScreenState extends State<ParentFeeManagementScreen> {
  bool _isLoading = true;
  late Color _primaryColor;
  late Color _accentColor;
  
  // Student data for the children of the parent
  List<Map<String, dynamic>> _studentsData = [];
  
  // Selected student for viewing fees
  Map<String, dynamic>? _selectedStudent;
  
  // Selected payment method
  String _selectedPaymentMethod = 'Credit Card';
  
  @override
  void initState() {
    super.initState();
    _loadThemeColors();
    _loadStudentsData();
    
    // Simulate loading delay
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_studentsData.isNotEmpty) {
            _selectedStudent = _studentsData[0];
          }
        });
      }
    });
  }
  
  void _loadThemeColors() {
    _primaryColor = AppTheme.getPrimaryColor(AppTheme.defaultTheme);
    _accentColor = AppTheme.getAccentColor(AppTheme.defaultTheme);
  }
  
  void _loadStudentsData() {
    // Simulated data for parent's children
    _studentsData = [
      {
        'name': 'John Smith',
        'grade': '10th Grade',
        'section': 'A',
        'rollNumber': '1023',
        'image': 'https://randomuser.me/api/portraits/children/1.jpg',
        'fees': {
          'status': 'Paid',
          'dueAmount': '0',
          'nextDueDate': 'Apr 15, 2023',
        },
        'feeRecords': [
          {
            'term': 'Term 1 2023',
            'amount': '500',
            'date': 'Jan 15, 2023',
            'status': 'Paid',
            'paymentMethod': 'Credit Card',
            'transactionId': 'TXN12345678',
            'color': Colors.green
          },
          {
            'term': 'Term 2 2023',
            'amount': '500',
            'date': 'Mar 15, 2023',
            'status': 'Paid',
            'paymentMethod': 'Bank Transfer',
            'transactionId': 'TXN87654321',
            'color': Colors.green
          },
          {
            'term': 'Term 3 2023',
            'amount': '500',
            'date': 'May 15, 2023',
            'status': 'Upcoming',
            'color': Colors.grey
          },
        ],
        'feeStructure': [
          {'item': 'Tuition Fee', 'amount': '400'},
          {'item': 'Library Fee', 'amount': '25'},
          {'item': 'Lab Fee', 'amount': '50'},
          {'item': 'Extra-curricular', 'amount': '25'},
        ]
      },
      {
        'name': 'Emily Smith',
        'grade': '7th Grade',
        'section': 'B',
        'rollNumber': '2045',
        'image': 'https://randomuser.me/api/portraits/children/2.jpg',
        'fees': {
          'status': 'Pending',
          'dueAmount': '125',
          'nextDueDate': 'Mar 30, 2023',
        },
        'feeRecords': [
          {
            'term': 'Term 1 2023',
            'amount': '450',
            'date': 'Jan 15, 2023',
            'status': 'Paid',
            'paymentMethod': 'Credit Card',
            'transactionId': 'TXN23456789',
            'color': Colors.green
          },
          {
            'term': 'Term 2 2023',
            'amount': '450',
            'date': 'Mar 15, 2023',
            'status': 'Pending',
            'color': Colors.orange
          },
          {
            'term': 'Term 3 2023',
            'amount': '450',
            'date': 'May 15, 2023',
            'status': 'Upcoming',
            'color': Colors.grey
          },
        ],
        'feeStructure': [
          {'item': 'Tuition Fee', 'amount': '350'},
          {'item': 'Library Fee', 'amount': '25'},
          {'item': 'Lab Fee', 'amount': '50'},
          {'item': 'Extra-curricular', 'amount': '25'},
        ]
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.getTheme(AppTheme.defaultTheme),
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Icon(Icons.payment, color: Colors.white),
              const SizedBox(width: 10),
              const Text('Fee Management', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _accentColor))
          : Column(
              children: [
                _buildStudentSelector(),
                Expanded(
                  child: _selectedStudent != null
                    ? _buildFeeDetails()
                    : Center(child: Text('No student selected')),
                ),
              ],
            ),
      ),
    );
  }
  
  Widget _buildStudentSelector() {
    return Container(
      height: 100,
      padding: const EdgeInsets.all(10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _studentsData.length,
        itemBuilder: (context, index) {
          final student = _studentsData[index];
          final isSelected = _selectedStudent == student;
          final fees = student['fees'] as Map<String, dynamic>;
          final feeStatus = fees['status'] as String;
          final isFeePending = feeStatus == 'Pending';
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedStudent = student;
              });
            },
            child: Container(
              width: 180,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isSelected ? _primaryColor.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.1),
                border: Border.all(
                  color: isSelected ? _primaryColor : Colors.transparent,
                  width: 2,
                ),
              ),
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: NetworkImage(student['image']),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          student['name'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? _primaryColor : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            Icon(
                              isFeePending ? Icons.warning : Icons.check_circle,
                              size: 12,
                              color: isFeePending ? Colors.orange : Colors.green,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              feeStatus,
                              style: TextStyle(
                                fontSize: 12,
                                color: isFeePending ? Colors.orange : Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
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
    );
  }
  
  Widget _buildFeeDetails() {
    if (_selectedStudent == null) return Container();
    
    final student = _selectedStudent!;
    final fees = student['fees'] as Map<String, dynamic>;
    final feeStatus = fees['status'] as String;
    final dueAmount = fees['dueAmount'] as String;
    final nextDueDate = fees['nextDueDate'] as String;
    final isFeePending = feeStatus == 'Pending';
    final feeRecords = student['feeRecords'] as List;
    final feeStructure = student['feeStructure'] as List;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fee Status Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: isFeePending ? Colors.orange.shade50 : Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        isFeePending ? Icons.warning_amber : Icons.check_circle,
                        color: isFeePending ? Colors.orange : Colors.green,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isFeePending ? 'Payment Pending' : 'All Fees Paid',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: isFeePending ? Colors.orange.shade800 : Colors.green.shade800,
                              ),
                            ),
                            Text(
                              isFeePending
                                  ? 'Due on $nextDueDate'
                                  : 'Next payment due on $nextDueDate',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (isFeePending) ...[
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        _showPaymentDialog(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.payment, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            'Pay Now \$${dueAmount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          // Payment History
          const SizedBox(height: 24),
          _buildSectionHeader('Payment History'),
          const SizedBox(height: 16),
          _buildPaymentHistory(feeRecords),
          
          // Fee Structure
          const SizedBox(height: 24),
          _buildSectionHeader('Fee Structure'),
          const SizedBox(height: 16),
          _buildFeeStructure(feeStructure),
          
          // Payment Methods
          const SizedBox(height: 24),
          _buildSectionHeader('Payment Methods'),
          const SizedBox(height: 16),
          _buildPaymentMethods(),
          
          const SizedBox(height: 40),
        ],
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
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
  
  Widget _buildPaymentHistory(List feeRecords) {
    if (feeRecords.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(16),
          height: 100,
          child: Center(
            child: Text(
              'No payment records available',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }
    
    return Column(
      children: [
        for (final record in feeRecords)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (record['color'] as Color).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      record['status'] == 'Paid'
                          ? Icons.receipt_long
                          : record['status'] == 'Pending'
                              ? Icons.pending
                              : Icons.schedule,
                      color: record['color'] as Color,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record['term'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Due: ${record['date']}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        if (record['status'] == 'Paid' && record['paymentMethod'] != null)
                          Text(
                            'Paid via: ${record['paymentMethod']}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${record['amount']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (record['color'] as Color).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          record['status'],
                          style: TextStyle(
                            color: record['color'] as Color,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (record['status'] == 'Paid' && record['transactionId'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'TXN ID: ${record['transactionId']}',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 10,
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
    );
  }
  
  Widget _buildFeeStructure(List feeStructure) {
    if (feeStructure.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(16),
          height: 100,
          child: Center(
            child: Text(
              'No fee structure available',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }
    
    // Calculate total
    num total = 0;
    for (var item in feeStructure) {
      total += num.tryParse(item['amount'] as String) ?? 0;
    }
    
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            for (var index = 0; index < feeStructure.length; index++) ...[
              _buildFeeItem(feeStructure[index]['item'], feeStructure[index]['amount']),
              if (index < feeStructure.length - 1) const Divider(),
            ],
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Per Term',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '\$$total',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFeeItem(String title, String amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title),
          Text('\$$amount'),
        ],
      ),
    );
  }
  
  Widget _buildPaymentMethods() {
    final paymentMethods = [
      {'name': 'Credit Card', 'icon': Icons.credit_card, 'color': Colors.blue},
      {'name': 'Debit Card', 'icon': Icons.credit_card, 'color': Colors.green},
      {'name': 'Bank Transfer', 'icon': Icons.account_balance, 'color': Colors.purple},
      {'name': 'Digital Wallet', 'icon': Icons.account_balance_wallet, 'color': Colors.orange},
    ];
    
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            for (final method in paymentMethods)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: (method['color'] as Color).withValues(alpha: 0.2),
                  child: Icon(method['icon'] as IconData, color: method['color'] as Color),
                ),
                title: Text(method['name'] as String),
                trailing: const Text('Set up'),
                onTap: () {
                  // Navigate to payment method setup
                },
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                // Add new payment method
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Payment Method'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _primaryColor,
                side: BorderSide(color: _primaryColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Update to void return type instead of Widget
  void _showPaymentDialog(BuildContext context) {
    if (_selectedStudent == null) return;
    
    final student = _selectedStudent!;
    final fees = student['fees'] as Map<String, dynamic>;
    final dueAmount = fees['dueAmount'] as String;
    final isFeePending = fees['status'] == 'Pending';
    
    if (!isFeePending) {
      // If there's no pending payment, show a different message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No pending fees for ${student['name']}'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Make Payment'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Payment for ${student['name']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Amount to Pay: \$$dueAmount',
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 16),
                    const Text('Select Payment Method:'),
                    const SizedBox(height: 8),
                    for (final method in ['Credit Card', 'Debit Card', 'Bank Transfer', 'Digital Wallet'])
                      RadioListTile<String>(
                        title: Text(method),
                        value: method,
                        groupValue: _selectedPaymentMethod,
                        onChanged: (value) {
                          setState(() {
                            _selectedPaymentMethod = value!;
                          });
                        },
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Cancel', style: TextStyle(color: _accentColor)),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Process payment
                    Navigator.of(context).pop();
                    _showPaymentSuccessDialog(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
                  child: const Text('Pay Now', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
  }
  
  void _showPaymentSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              const Text('Payment Successful'),
            ],
          ),
          content: const Text('Your payment has been processed successfully. A receipt has been sent to your email.'),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  // Update payment status
                  if (_selectedStudent != null) {
                    final fees = _selectedStudent!['fees'] as Map<String, dynamic>;
                    fees['status'] = 'Paid';
                    fees['dueAmount'] = '0';
                    
                    // Update the fee record
                    final feeRecords = _selectedStudent!['feeRecords'] as List;
                    for (int i = 0; i < feeRecords.length; i++) {
                      if (feeRecords[i]['status'] == 'Pending') {
                        feeRecords[i]['status'] = 'Paid';
                        feeRecords[i]['color'] = Colors.green;
                        feeRecords[i]['paymentMethod'] = _selectedPaymentMethod;
                        feeRecords[i]['transactionId'] = 'TXN${DateTime.now().millisecondsSinceEpoch}';
                      }
                    }
                  }
                });
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
