import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main.dart';
import 'utils/responsive_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _salesTaxController;

  @override
  void initState() {
    super.initState();
    _salesTaxController = TextEditingController();
  }

  @override
  void dispose() {
    _salesTaxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        // Initialize the controller with current value when settings are loaded
        if (_salesTaxController.text.isEmpty) {
          _salesTaxController.text = appState.getSalesTaxPercentage().toString();
        }

        return AppShell(
          title: 'Settings',
          body: SingleChildScrollView(
            child: ResponsiveContainer(
              child: Column(
                children: [
                  // User Profile Card
                  Container(
                    width: double.infinity,
                    margin: ResponsiveHelper.getResponsiveMargin(context),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context, 12)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: ResponsiveHelper.getResponsivePadding(context),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: ResponsiveHelper.getResponsiveIconSize(context, 30),
                            backgroundColor: primaryColor,
                            child: Text(
                              _getInitial(appState.currentUser?.name, appState.currentUser?.email ?? ''),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: ResponsiveHelper.getResponsiveFontSize(context, 24),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, 16)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  appState.currentUser?.name ?? 'User',
                                  style: TextStyle(
                                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, 20),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 4)),
                                Text(
                                  appState.currentUser?.email ?? '',
                                  style: TextStyle(
                                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                                    color: Colors.grey,
                                  ),
                                ),
                                SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 4)),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: ResponsiveHelper.getResponsiveSpacing(context, 8),
                                    vertical: ResponsiveHelper.getResponsiveSpacing(context, 2),
                                  ),
                                  decoration: BoxDecoration(
                                    color: primaryColor,
                                    borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context, 12)),
                                  ),
                                  child: Text(
                                    'Role: ${appState.isAdmin ? 'ADMIN' : appState.isDriver ? 'DRIVER' : 'EMPLOYEE'}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, 12),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // App Settings Section
                  Container(
                    width: double.infinity,
                    margin: ResponsiveHelper.getResponsiveMargin(context),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context, 12)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: ResponsiveHelper.getResponsivePadding(context),
                          child: Text(
                            'App Settings',
                            style: TextStyle(
                              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 18),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        
                        // Notifications Setting
                        ListTile(
                          leading: Icon(
                            Icons.notifications, 
                            color: primaryColor,
                            size: ResponsiveHelper.getResponsiveIconSize(context, 24),
                          ),
                          title: Text(
                            'Notifications',
                            style: TextStyle(
                              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
                            ),
                          ),
                          subtitle: Text(
                            'Manage notification preferences',
                            style: TextStyle(
                              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                            ),
                          ),
                          trailing: Text(
                            'System', 
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                            ),
                          ),
                          onTap: () {
                            // TODO: Implement notifications settings
                          },
                        ),
                        const Divider(height: 1),
                        
                        // Language Setting
                        ListTile(
                          leading: Icon(
                            Icons.language, 
                            color: primaryColor,
                            size: ResponsiveHelper.getResponsiveIconSize(context, 24),
                          ),
                          title: Text(
                            'Language',
                            style: TextStyle(
                              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
                            ),
                          ),
                          subtitle: Text(
                            'App language settings',
                            style: TextStyle(
                              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                            ),
                          ),
                          trailing: Text(
                            'English', 
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                            ),
                          ),
                          onTap: () {
                            // TODO: Implement language settings
                          },
                        ),
                        const Divider(height: 1),
                        
                        // Sales Tax Setting
                        ListTile(
                          leading: Icon(
                            Icons.percent, 
                            color: primaryColor,
                            size: ResponsiveHelper.getResponsiveIconSize(context, 24),
                          ),
                          title: Text(
                            'Sales Tax',
                            style: TextStyle(
                              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
                            ),
                          ),
                          subtitle: Text(
                            'Current: ${appState.getSalesTaxPercentage()}%',
                            style: TextStyle(
                              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                            ),
                          ),
                          trailing: Icon(
                            Icons.arrow_forward_ios, 
                            size: ResponsiveHelper.getResponsiveIconSize(context, 16), 
                            color: Colors.grey,
                          ),
                          onTap: () {
                            _showSalesTaxDialog(context, appState);
                          },
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 20)),

                  // Logout Button
                  Container(
                    width: double.infinity,
                    margin: ResponsiveHelper.getResponsiveMargin(context),
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        if (mounted) {
                          Navigator.of(context).pushReplacementNamed('/');
                        }
                      },
                      icon: Icon(
                        Icons.logout, 
                        color: Colors.white,
                        size: ResponsiveHelper.getResponsiveIconSize(context, 24),
                      ),
                      label: Text(
                        'Logout', 
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: EdgeInsets.symmetric(
                          vertical: ResponsiveHelper.getResponsiveSpacing(context, 16),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context, 12)),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 20)),

                  // Footer
                  Center(
                    child: Text(
                      'Powered by RathiSoft',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSalesTaxDialog(BuildContext context, AppState appState) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Sales Tax Configuration'),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _salesTaxController,
                  decoration: const InputDecoration(
                    labelText: 'Sales Tax Percentage (%)',
                    hintText: 'e.g., 15.0 for 15%',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.percent),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter sales tax percentage';
                    }
                    final percentage = double.tryParse(value);
                    if (percentage == null) {
                      return 'Please enter a valid number';
                    }
                    if (percentage < 0 || percentage > 100) {
                      return 'Percentage must be between 0 and 100';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'This percentage will be applied to all new orders and used for invoice generation.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
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
              onPressed: appState.isLoading ? null : () async {
                if (_formKey.currentState!.validate()) {
                  final percentage = double.parse(_salesTaxController.text);
                  await appState.updateSalesTaxPercentage(percentage);
                  
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Sales tax percentage updated to ${percentage}%'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  String _getInitial(String? name, String email) {
    if (name != null && name.isNotEmpty) {
      return name[0].toUpperCase();
    }
    if (email.isNotEmpty) {
      return email[0].toUpperCase();
    }
    return 'U';
  }

}
