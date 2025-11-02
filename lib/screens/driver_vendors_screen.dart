import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/vendor.dart';
import '../utils/responsive_helper.dart';

class DriverVendorsScreen extends StatelessWidget {
  const DriverVendorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return AppShell(
          title: 'Vendors',
          body: appState.vendors.isEmpty
              ? Center(
                  child: Text(
                    'No vendors available',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
                      color: Colors.grey,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: ResponsiveHelper.getResponsivePadding(context),
                  itemCount: appState.vendors.length,
                  itemBuilder: (context, index) {
                    final vendor = appState.vendors[index];
                    return Card(
                      margin: EdgeInsets.only(bottom: ResponsiveHelper.getResponsiveSpacing(context, 12)),
                      elevation: 2,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: primaryColor,
                          radius: ResponsiveHelper.getResponsiveIconSize(context, 20),
                          child: Text(
                            vendor.name.isNotEmpty ? vendor.name[0].toUpperCase() : 'V',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
                            ),
                          ),
                        ),
                        title: Text(
                          vendor.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
                          ),
                        ),
                        subtitle: Text(
                          'Rate: Rs.${vendor.perBottleRate} per bottle',
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getResponsiveFontSize(context, 13),
                            color: Colors.grey,
                          ),
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_vert,
                            size: ResponsiveHelper.getResponsiveIconSize(context, 20),
                            color: Colors.grey,
                          ),
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'info',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info,
                                    size: ResponsiveHelper.getResponsiveIconSize(context, 20),
                                    color: Colors.blue,
                                  ),
                                  SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, 8)),
                                  Text('Info'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'pickup',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.add_shopping_cart,
                                    size: ResponsiveHelper.getResponsiveIconSize(context, 20),
                                    color: Colors.green,
                                  ),
                                  SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, 8)),
                                  Text('Pick Up Bottles'),
                                ],
                              ),
                            ),
                          ],
                          onSelected: (value) {
                            if (value == 'info') {
                              _showVendorInfo(context, appState, vendor);
                            } else if (value == 'pickup') {
                              _showPickupDialog(context, appState, vendor);
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  void _showPickupDialog(BuildContext context, AppState appState, Vendor vendor) {
    final bottlesController = TextEditingController();
    final amountPaidController = TextEditingController();

    // Calculate total amount
    int totalAmount = 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          void calculateAmount() {
            final bottles = int.tryParse(bottlesController.text) ?? 0;
            totalAmount = bottles * vendor.perBottleRate;
            setState(() {});
          }

          return AlertDialog(
            title: Text('Pick Up Bottles - ${vendor.name}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Rate: Rs.${vendor.perBottleRate} per bottle',
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: bottlesController,
                    decoration: const InputDecoration(
                      labelText: 'Bottles Picked Up',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => calculateAmount(),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[300]!),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Total Amount to Pay',
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getResponsiveFontSize(context, 12),
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Rs.$totalAmount',
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getResponsiveFontSize(context, 18),
                            fontWeight: FontWeight.bold,
                            color: Colors.green[900],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountPaidController,
                    decoration: const InputDecoration(
                      labelText: 'Amount Paid (Rs.)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
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
                onPressed: () {
                  if (bottlesController.text.isNotEmpty &&
                      int.tryParse(bottlesController.text) != null &&
                      amountPaidController.text.isNotEmpty &&
                      int.tryParse(amountPaidController.text) != null) {
                    appState.createVendorPickup(
                      vendorId: vendor.id,
                      vendorName: vendor.name,
                      bottlesPicked: int.parse(bottlesController.text),
                      perBottleRate: vendor.perBottleRate,
                      amountPaid: int.parse(amountPaidController.text),
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Bottles picked up successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter valid values'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: const Text('Record Pickup'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showVendorInfo(BuildContext context, AppState appState, Vendor vendor) {
    // Get current driver's ID
    final driverId = appState.currentUser?.uid ?? '';
    
    // Get all pickups for this vendor and driver
    final allPickups = appState.getVendorPickupsByVendor(vendor.id);
    final myPickups = allPickups.where((pickup) => pickup.driverId == driverId).toList();
    
    // Calculate total bottles picked and total amount
    final totalBottlesPicked = myPickups.fold<int>(0, (sum, pickup) => sum + pickup.bottlesPicked);
    final totalAmountPaid = myPickups.fold<int>(0, (sum, pickup) => sum + pickup.amountPaid);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${vendor.name} - My Pickups'),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vendor Info Summary
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rate: Rs.${vendor.perBottleRate} per bottle',
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 4)),
                    Text(
                      'Total Bottles Picked: $totalBottlesPicked',
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                      ),
                    ),
                    SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 4)),
                    Text(
                      'Total Amount Paid: Rs.$totalAmountPaid',
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 12)),
              
              // Pickup History
              Text(
                'Pickup History',
                style: TextStyle(
                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 8)),
              
              // Pickup List
              Expanded(
                child: myPickups.isEmpty
                    ? Center(
                        child: Text(
                          'No pickups yet',
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: myPickups.length,
                        itemBuilder: (context, index) {
                          final pickup = myPickups[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _formatDate(pickup.pickupDate),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green[100],
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '${pickup.bottlesPicked} bottles',
                                          style: TextStyle(
                                            color: Colors.green[900],
                                            fontWeight: FontWeight.bold,
                                            fontSize: ResponsiveHelper.getResponsiveFontSize(context, 12),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 4)),
                                  Text(
                                    'Rate: Rs.${pickup.perBottleRate} per bottle',
                                    style: TextStyle(
                                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, 13),
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 2)),
                                  Text(
                                    'Amount Paid: Rs.${pickup.amountPaid}',
                                    style: TextStyle(
                                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, 13),
                                      color: Colors.green[900],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

