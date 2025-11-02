import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main.dart';
import 'models/auto_order.dart';
import 'utils/pakistan_time.dart';
import 'utils/responsive_helper.dart';

class AutoOrdersScreen extends StatefulWidget {
  const AutoOrdersScreen({super.key});

  @override
  State<AutoOrdersScreen> createState() => _AutoOrdersScreenState();
}

class _AutoOrdersScreenState extends State<AutoOrdersScreen> {
  String _searchQuery = '';
  String _selectedDriverFilter = 'All';
  String _selectedDayFilter = 'All';

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        if (appState.currentUser == null) {
          return const Center(child: Text('Please log in'));
        }

        final autoOrders = appState.autoOrders;
        final filteredAutoOrders = autoOrders.where((autoOrder) {
          final matchesSearch = autoOrder.customerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              autoOrder.customerPhone.contains(_searchQuery) ||
              autoOrder.customerArea.toLowerCase().contains(_searchQuery.toLowerCase());
          
          final matchesDriver = _selectedDriverFilter == 'All' || 
              autoOrder.assignedDriver == _selectedDriverFilter;
          
          final matchesDay = _selectedDayFilter == 'All' || 
              autoOrder.dayOfWeek == _selectedDayFilter;
          
          return matchesSearch && matchesDriver && matchesDay && autoOrder.isActive;
        }).toList()
          ..sort((a, b) {
            // Sort by creation date (newest first) using PakistanTime
            final pakistanDateA = PakistanTime.toPakistanTime(a.createdAt);
            final pakistanDateB = PakistanTime.toPakistanTime(b.createdAt);
            return pakistanDateB.compareTo(pakistanDateA);
          });

        return Column(
          children: [
              // Search Bar
              Padding(
                padding: ResponsiveHelper.getResponsivePadding(context),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by customer name, phone, or area...',
                    prefixIcon: Icon(Icons.search, size: ResponsiveHelper.getResponsiveIconSize(context, 24)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context, 12)),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: ResponsiveHelper.getResponsiveSpacing(context, 16),
                      vertical: ResponsiveHelper.getResponsiveSpacing(context, 12),
                    ),
                  ),
                  style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14)),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),

              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 16)),

              // Filter Row
              Padding(
                padding: ResponsiveHelper.getResponsivePadding(context),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Filter by Driver',
                              labelStyle: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, 12)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context, 8)),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: ResponsiveHelper.getResponsiveSpacing(context, 8),
                                vertical: ResponsiveHelper.getResponsiveSpacing(context, 8),
                              ),
                              isDense: true,
                            ),
                            value: _selectedDriverFilter,
                            items: [
                              'All',
                              ...appState.employees
                                  .where((emp) => emp.role == 'driver')
                                  .map((driver) => driver.name)
                                  .toSet()
                                  .toList(),
                            ].map((driver) {
                              return DropdownMenuItem(
                                value: driver,
                                child: Text(
                                  driver,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, 12)),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedDriverFilter = value!;
                              });
                            },
                          ),
                        ),
                        SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, 8)),
                        Expanded(
                          flex: 1,
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Filter by Day',
                              labelStyle: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, 12)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context, 8)),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: ResponsiveHelper.getResponsiveSpacing(context, 8),
                                vertical: ResponsiveHelper.getResponsiveSpacing(context, 8),
                              ),
                              isDense: true,
                            ),
                            value: _selectedDayFilter,
                            items: [
                              'All',
                              'Monday',
                              'Tuesday',
                              'Wednesday',
                              'Thursday',
                              'Friday',
                              'Saturday',
                              'Sunday',
                            ].map((day) {
                              return DropdownMenuItem(
                                value: day,
                                child: Text(
                                  day,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, 12)),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedDayFilter = value!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 16)),

              // Auto Orders List
              Expanded(
                child: filteredAutoOrders.isEmpty
                    ? SingleChildScrollView(
                        child: Container(
                          height: 300,
                          padding: ResponsiveHelper.getResponsivePadding(context),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.autorenew,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 16)),
                              Text(
                                'No auto orders found',
                                style: TextStyle(
                                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, 18),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 8)),
                              Text(
                                'Create orders with auto delivery enabled to see them here',
                                style: TextStyle(
                                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                                  color: Colors.grey[500],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: ResponsiveHelper.getResponsivePadding(context),
                        itemCount: filteredAutoOrders.length,
                        cacheExtent: 500,
                        itemBuilder: (context, index) {
                          final autoOrder = filteredAutoOrders[index];
                          final daysUntilNext = autoOrder.nextDeliveryDate.difference(DateTime.now()).inDays;
                          
                          return Card(
                            margin: EdgeInsets.only(bottom: ResponsiveHelper.getResponsiveSpacing(context, 12)),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context, 12)),
                            ),
                            child: Padding(
                              padding: ResponsiveHelper.getResponsivePadding(context),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: Colors.blue[100],
                                        child: Icon(
                                          Icons.person,
                                          color: Colors.blue[700],
                                        ),
                                      ),
                                      SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, 12)),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              autoOrder.customerName,
                                              style: TextStyle(
                                                fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              autoOrder.customerPhone,
                                              style: TextStyle(
                                                fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Chip(
                                        label: Text(autoOrder.dayOfWeek),
                                        backgroundColor: Colors.green[100],
                                        labelStyle: TextStyle(
                                          color: Colors.green[700],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Quantity: ${autoOrder.quantity} bottles',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w500,
                                                fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                                              ),
                                            ),
                                            Text(
                                              'Price: Rs. ${autoOrder.price}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w500,
                                                fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                                              ),
                                            ),
                                            Text(
                                              'Driver: ${autoOrder.assignedDriver}',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              'Next Delivery',
                                              style: TextStyle(
                                                fontSize: ResponsiveHelper.getResponsiveFontSize(context, 12),
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            Text(
                                              '${autoOrder.nextDeliveryDate.day}/${autoOrder.nextDeliveryDate.month}/${autoOrder.nextDeliveryDate.year}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                                              ),
                                            ),
                                            Text(
                                              daysUntilNext == 0 
                                                  ? 'Today' 
                                                  : daysUntilNext == 1 
                                                      ? 'Tomorrow' 
                                                      : '$daysUntilNext days',
                                              style: TextStyle(
                                                color: daysUntilNext <= 1 ? Colors.red : Colors.orange,
                                                fontWeight: FontWeight.bold,
                                                fontSize: ResponsiveHelper.getResponsiveFontSize(context, 12),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (autoOrder.notes != null && autoOrder.notes!.isNotEmpty) ...[
                                    SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 8)),
                                    Text(
                                      'Notes: ${autoOrder.notes}',
                                      style: TextStyle(
                                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, 12),
                                        color: Colors.grey[600],
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 12)),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () => _showEditDialog(context, appState, autoOrder),
                                          icon: const Icon(Icons.edit, size: 16),
                                          label: const Text('Edit'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.blue,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, 8)),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () => _showCancelDialog(context, appState, autoOrder),
                                          icon: const Icon(Icons.cancel, size: 16),
                                          label: const Text('Cancel'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.red,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
      },
    );
  }

  void _showEditDialog(BuildContext context, AppState appState, AutoOrder autoOrder) {
    final quantityController = TextEditingController(text: autoOrder.quantity.toString());
    final priceController = TextEditingController(text: autoOrder.price.toString());
    final notesController = TextEditingController(text: autoOrder.notes ?? '');
    String selectedDriver = autoOrder.assignedDriver;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Auto Order'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Assigned Driver',
                    border: OutlineInputBorder(),
                  ),
                  value: selectedDriver,
                  items: appState.employees
                      .where((emp) => emp.role == 'driver')
                      .map((driver) {
                    return DropdownMenuItem(
                      value: driver.name,
                      child: Text(driver.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedDriver = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: quantityController,
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: priceController,
                  decoration: const InputDecoration(
                    labelText: 'Price (Rs.)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
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
                try {
                  await appState.updateAutoOrder(
                    autoOrder.copyWith(
                      assignedDriver: selectedDriver,
                      quantity: int.parse(quantityController.text),
                      price: int.parse(priceController.text),
                      notes: notesController.text,
                      updatedAt: DateTime.now(),
                    ),
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Auto order updated successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error updating auto order: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelDialog(BuildContext context, AppState appState, AutoOrder autoOrder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Auto Order'),
        content: const Text('Are you sure you want to cancel this auto order? This will create a pending order instead.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await appState.cancelAutoOrder(autoOrder.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Auto order cancelled successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error cancelling auto order: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }
}

