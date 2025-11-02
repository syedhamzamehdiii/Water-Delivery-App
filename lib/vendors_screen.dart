import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main.dart';
import 'models/vendor.dart';
import 'utils/responsive_helper.dart';
import 'utils/pakistan_time.dart';

// ========== VENDORS SCREEN ==========

class VendorsScreen extends StatelessWidget {
  const VendorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return AppShell(
          title: 'Vendors',
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddVendorDialog(context),
            backgroundColor: primaryColor,
            child: Icon(
              Icons.add, 
              color: Colors.white,
              size: ResponsiveHelper.getResponsiveIconSize(context, 24),
            ),
          ),
          body: Column(
            children: [
              // Header
              Padding(
                padding: ResponsiveHelper.getResponsivePadding(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vendor Management',
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, 24),
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              // Vendor List
              Expanded(
                child: appState.vendors.isEmpty
                    ? Center(
                        child: Text(
                          'No vendors added yet',
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16), 
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : Builder(
                        builder: (context) {
                          // Sort vendors by creation date (newest first)
                          final sortedVendors = List<Vendor>.from(appState.vendors)
                            ..sort((a, b) {
                              // Use PakistanTime for consistent sorting (newest first)
                              final pakistanDateA = PakistanTime.toPakistanTime(a.createdAt);
                              final pakistanDateB = PakistanTime.toPakistanTime(b.createdAt);
                              return pakistanDateB.compareTo(pakistanDateA);
                            });
                          
                          return ListView.builder(
                            padding: ResponsiveHelper.getResponsivePadding(context),
                            itemCount: sortedVendors.length,
                            cacheExtent: 500,
                            itemBuilder: (context, index) {
                              final vendor = sortedVendors[index];
                          // Calculate totals from pickups for this vendor
                          final pickups = appState.getVendorPickupsByVendor(vendor.id);
                          final totalBottles = pickups.fold<int>(0, (sum, pickup) => sum + pickup.bottlesPicked);
                          final totalPaid = pickups.fold<int>(0, (sum, pickup) => sum + pickup.amountPaid);
                          return Card(
                            margin: EdgeInsets.only(bottom: ResponsiveHelper.getResponsiveSpacing(context, 12)),
                            elevation: 2,
                            child: InkWell(
                              onTap: () => _showVendorDetails(context, appState, vendor),
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
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Bottles: $totalBottles | Paid: Rs.$totalPaid',
                                      style: TextStyle(
                                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, 13),
                                      ),
                                    ),
                                    SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 2)),
                                    Text(
                                      'Rate: Rs.${vendor.perBottleRate} | Added: ${_formatDate(vendor.dateAdded)}',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, 12),
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.edit,
                                        color: Colors.blue,
                                        size: ResponsiveHelper.getResponsiveIconSize(context, 20),
                                      ),
                                      onPressed: () => _showFixRateDialog(context, appState, vendor),
                                      tooltip: 'Fix Rate',
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete, 
                                        color: Colors.red,
                                        size: ResponsiveHelper.getResponsiveIconSize(context, 20),
                                      ),
                                      onPressed: () => _showDeleteConfirmation(context, appState, vendor),
                                      tooltip: 'Delete',
                                    ),
                                  ],
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
        );
      },
    );
  }

  void _showAddVendorDialog(BuildContext context) {
    final nameController = TextEditingController();
    final perBottleRateController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Vendor'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Vendor Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: perBottleRateController,
                decoration: const InputDecoration(
                  labelText: 'Per Bottle Rate (Rs.)',
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
              if (nameController.text.isNotEmpty &&
                  perBottleRateController.text.isNotEmpty &&
                  int.tryParse(perBottleRateController.text) != null) {
                final appState = Provider.of<AppState>(context, listen: false);
                appState.createVendor(
                  name: nameController.text,
                  totalBottles: 0,
                  totalPrice: 0,
                  perBottleRate: int.parse(perBottleRateController.text),
                  dateAdded: DateTime.now(),
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vendor added successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill all required fields'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showFixRateDialog(BuildContext context, AppState appState, Vendor vendor) {
    final perBottleRateController = TextEditingController(text: vendor.perBottleRate.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Fix Rate - ${vendor.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: perBottleRateController,
                decoration: const InputDecoration(
                  labelText: 'Per Bottle Rate (Rs.)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                autofocus: true,
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
              if (perBottleRateController.text.isNotEmpty &&
                  int.tryParse(perBottleRateController.text) != null) {
                final updatedVendor = Vendor(
                  id: vendor.id,
                  name: vendor.name,
                  totalBottles: vendor.totalBottles,
                  totalPrice: vendor.totalPrice,
                  perBottleRate: int.parse(perBottleRateController.text),
                  dateAdded: vendor.dateAdded,
                  createdAt: vendor.createdAt,
                  updatedAt: DateTime.now(),
                  companyId: vendor.companyId,
                );
                
                appState.updateVendor(updatedVendor);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vendor rate updated successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid rate'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Update Rate'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, AppState appState, Vendor vendor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vendor'),
        content: Text('Are you sure you want to delete ${vendor.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await appState.deleteVendor(vendor.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vendor deleted successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showVendorDetails(BuildContext context, AppState appState, Vendor vendor) {
    final pickups = appState.getVendorPickupsByVendor(vendor.id);
    // Calculate totals from pickups
    final totalBottles = pickups.fold<int>(0, (sum, pickup) => sum + pickup.bottlesPicked);
    final totalPaid = pickups.fold<int>(0, (sum, pickup) => sum + pickup.amountPaid);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Vendor Details - ${vendor.name}'),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vendor Info
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vendor Information',
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 8)),
                    Text('Rate: Rs.${vendor.perBottleRate} per bottle'),
                    Text('Total Bottles: $totalBottles'),
                    Text('Total Paid: Rs.$totalPaid'),
                  ],
                ),
              ),
              const Divider(),
              
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
                child: pickups.isEmpty
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
                        itemCount: pickups.length,
                        itemBuilder: (context, index) {
                          final pickup = pickups[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue,
                                child: Text(
                                  pickup.driverName.isNotEmpty ? pickup.driverName[0].toUpperCase() : 'D',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                pickup.driverName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Bottles: ${pickup.bottlesPicked}'),
                                  Text('Amount to Pay: Rs.${pickup.calculatedAmount}'),
                                  Text('Amount Paid: Rs.${pickup.amountPaid}'),
                                  Text('Date: ${_formatDate(pickup.pickupDate)}'),
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
