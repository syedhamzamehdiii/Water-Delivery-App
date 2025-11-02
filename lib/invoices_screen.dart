import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main.dart';
import 'models/invoice.dart';
import 'utils/responsive_helper.dart';

// ========== INVOICES SCREEN ==========

class InvoicesScreen extends StatelessWidget {
  const InvoicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return AppShell(
          title: 'Invoices',
          body: Column(
            children: [
              // Header with Add Invoice button
              Padding(
                padding: ResponsiveHelper.getResponsivePadding(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invoice Management',
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, 24),
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 12)),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showAddInvoiceDialog(context, appState),
                        icon: Icon(
                          Icons.add,
                          size: ResponsiveHelper.getResponsiveIconSize(context, 24),
                        ),
                        label: Text(
                          'Add Invoice',
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            vertical: ResponsiveHelper.getResponsiveSpacing(context, 12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Invoices List
              Expanded(
                child: appState.isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                        ),
                      )
                    : appState.invoices.isEmpty
                        ? Center(
                            child: Text(
                              'No invoices found. Add some invoices to get started.',
                              style: TextStyle(
                                fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16), 
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: ResponsiveHelper.getResponsivePadding(context),
                            itemCount: appState.invoices.length,
                            itemBuilder: (context, index) {
                              final invoice = appState.invoices[index];
                              return Card(
                                margin: EdgeInsets.only(bottom: ResponsiveHelper.getResponsiveSpacing(context, 12)),
                                elevation: 2,
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: _getStatusColor(invoice.status),
                                    radius: ResponsiveHelper.getResponsiveIconSize(context, 20),
                                    child: Text(
                                      invoice.customerName.isNotEmpty ? invoice.customerName[0].toUpperCase() : 'I',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    'Invoice #${invoice.id.substring(0, 8)}',
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
                                        'Customer: ${invoice.customerName} | Total: Rs.${invoice.total}',
                                        style: TextStyle(
                                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, 13),
                                        ),
                                      ),
                                      SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 2)),
                                      Text(
                                        'Tax: Rs.${invoice.salesTax} | Status: ${invoice.status.toUpperCase()}',
                                        style: TextStyle(
                                          color: _getStatusColor(invoice.status),
                                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, 12),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 2)),
                                      Text(
                                        'Due: ${_formatDate(invoice.dueDate)}',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, 11),
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (value) {
                                      switch (value) {
                                        case 'view':
                                          _showInvoiceDetails(context, invoice);
                                          break;
                                        case 'edit':
                                          _showEditInvoiceDialog(context, appState, invoice);
                                          break;
                                        case 'delete':
                                          _showDeleteConfirmation(context, appState, invoice);
                                          break;
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        value: 'view',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.visibility,
                                              size: ResponsiveHelper.getResponsiveIconSize(context, 20),
                                            ),
                                            SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, 8)),
                                            Text(
                                              'View',
                                              style: TextStyle(
                                                fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.edit,
                                              size: ResponsiveHelper.getResponsiveIconSize(context, 20),
                                            ),
                                            SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, 8)),
                                            Text(
                                              'Edit',
                                              style: TextStyle(
                                                fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.delete, 
                                              color: Colors.red,
                                              size: ResponsiveHelper.getResponsiveIconSize(context, 20),
                                            ),
                                            SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, 8)),
                                            Text(
                                              'Delete', 
                                              style: TextStyle(
                                                color: Colors.red,
                                                fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                                              ),
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
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'overdue':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showAddInvoiceDialog(BuildContext context, AppState appState) {
    final customerController = TextEditingController();
    final subtotalController = TextEditingController();
    final salesTaxRateController = TextEditingController(text: '15.0');
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Add New Invoice',
          style: TextStyle(
            fontSize: ResponsiveHelper.getResponsiveFontSize(context, 18),
          ),
        ),
        content: SizedBox(
          width: ResponsiveHelper.getResponsiveDialogWidth(context),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: customerController,
                    decoration: InputDecoration(
                      labelText: 'Customer Name',
                      border: const OutlineInputBorder(),
                      labelStyle: TextStyle(
                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                      ),
                    ),
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter customer name';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 16)),
                  TextFormField(
                    controller: subtotalController,
                    decoration: InputDecoration(
                      labelText: 'Subtotal (Rs.)',
                      border: const OutlineInputBorder(),
                      labelStyle: TextStyle(
                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                      ),
                    ),
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter subtotal';
                      }
                      if (int.tryParse(value) == null || int.parse(value) <= 0) {
                        return 'Please enter a valid amount';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 16)),
                  TextFormField(
                    controller: salesTaxRateController,
                    decoration: InputDecoration(
                      labelText: 'Sales Tax Rate (%)',
                      border: const OutlineInputBorder(),
                      labelStyle: TextStyle(
                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                      ),
                    ),
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter sales tax rate';
                      }
                      if (double.tryParse(value) == null || double.parse(value) < 0) {
                        return 'Please enter a valid rate';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 16)),
                  TextFormField(
                    controller: notesController,
                    decoration: InputDecoration(
                      labelText: 'Notes (Optional)',
                      border: const OutlineInputBorder(),
                      labelStyle: TextStyle(
                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                      ),
                    ),
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: appState.isLoading ? null : () async {
              if (formKey.currentState!.validate()) {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      'Creating invoice...',
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                      ),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
                
                try {
                  await appState.createInvoice(
                    customerId: 'manual_${DateTime.now().millisecondsSinceEpoch}',
                    customerName: customerController.text,
                    orderIds: [], // Manual invoice, no specific orders
                    subtotal: int.parse(subtotalController.text),
                    salesTaxRate: double.parse(salesTaxRateController.text) / 100, // Convert percentage to decimal
                    notes: notesController.text.isNotEmpty ? notesController.text : null,
                  );
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Invoice created successfully!',
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                        ),
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Error: $e',
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                        ),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: appState.isLoading 
                ? CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ) 
                : Text(
                    'Create',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showInvoiceDetails(BuildContext context, Invoice invoice) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Invoice #${invoice.id.substring(0, 8)}'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Customer', invoice.customerName),
              _buildDetailRow('Invoice Date', _formatDate(invoice.invoiceDate)),
              _buildDetailRow('Due Date', _formatDate(invoice.dueDate)),
              _buildDetailRow('Status', invoice.status.toUpperCase()),
              const SizedBox(height: 16),
              const Text(
                'Financial Details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildDetailRow('Subtotal', 'Rs. ${invoice.subtotal}'),
              _buildDetailRow('Sales Tax (${(invoice.salesTaxRate * 100).toStringAsFixed(1)}%)', 'Rs. ${invoice.salesTax}'),
              _buildDetailRow('Total', 'Rs. ${invoice.total}'),
              if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildDetailRow('Notes', invoice.notes!),
              ],
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _showEditInvoiceDialog(BuildContext context, AppState appState, Invoice invoice) {
    // Implementation for editing invoice
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Edit invoice functionality coming soon!'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, AppState appState, Invoice invoice) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Invoice'),
        content: Text('Are you sure you want to delete invoice #${invoice.id.substring(0, 8)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await appState.deleteInvoice(invoice.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Invoice deleted successfully!'),
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
