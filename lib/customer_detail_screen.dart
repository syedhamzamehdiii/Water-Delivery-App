import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'main.dart';
import 'models/order.dart' as order_model;
import 'services/firebase_service.dart';
import 'utils/responsive_helper.dart';

class CustomerDetailScreen extends StatefulWidget {
  final Customer customer;

  const CustomerDetailScreen({
    super.key,
    required this.customer,
  });

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        // Get customer's orders
        final customerOrders = appState.orders
            .where((order) => order.customerId == widget.customer.id)
            .toList();

        // Get customer's payments (all payments for this customer's orders)
        final customerPayments = appState.payments
            .where((payment) => customerOrders.any((order) => order.id == payment.orderId))
            .toList();

        // Calculate totals
        // Total owed = sum of all order values (all orders - auto and on-demand)
        final totalOwed = customerOrders.fold<int>(0, (sum, order) => sum + ((order.price + (order.salesTax ?? 0)) * order.quantity));
        
        // Total paid = sum of all payments by customer (including all payments for all orders)
        final totalPaid = customerPayments.fold<int>(0, (sum, payment) => sum + payment.amount);
        
        // Calculate due amount or extra amount
        final difference = totalOwed - totalPaid;

        return AppShell(
          title: 'Customer Details',
          body: SingleChildScrollView(
            padding: ResponsiveHelper.getResponsivePadding(context),
            child: ResponsiveContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer Info Card
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: ResponsiveHelper.getResponsivePadding(context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: ResponsiveHelper.getResponsiveIconSize(context, 30),
                                backgroundColor: primaryColor,
                                child: Text(
                                  widget.customer.name[0].toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, 24),
                                  ),
                                ),
                              ),
                              SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, 16)),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.customer.name,
                                      style: TextStyle(
                                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, 24),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 4)),
                                    Text(
                                      widget.customer.phone,
                                      style: TextStyle(
                                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      widget.customer.area,
                                      style: TextStyle(
                                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 16)),
                          const Divider(),
                          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 16)),
                          ResponsiveGrid(
                            children: [
                              _buildStatCard('Total Paid', 'Rs. $totalPaid', Colors.orange),
                              _buildDueAmountCard(difference),
                            ],
                          ),
                          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 16)),
                          const Divider(),
                          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 16)),
                          // Customer Details Section
                          Text(
                            'Customer Details',
                            style: TextStyle(
                              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 12)),
                          _buildDetailRow('Address', widget.customer.address),
                          if (widget.customer.daysAssigned.isNotEmpty)
                            _buildDetailRow('Days Assigned', widget.customer.daysAssigned.join(', ')),
                          _buildDetailRow('Payment Mode', widget.customer.paymentMode),
                          if (widget.customer.bottleRate > 0)
                            _buildDetailRow('Bottle Rate', 'PKR ${widget.customer.bottleRate}'),
                          if (widget.customer.bottleDeposit > 0)
                            _buildDetailRow('Bottle Deposit', 'PKR ${widget.customer.bottleDeposit}'),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 20)),

                  // Action Buttons
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showGenerateInvoiceDialog(context, customerOrders),
                      icon: const Icon(Icons.receipt),
                      label: const Text('Generate Invoice'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: ResponsiveHelper.getResponsiveSpacing(context, 12)),
                      ),
                    ),
                  ),

                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 20)),

                  // Orders Section with Payments
                  _buildSectionHeader('Orders History', Icons.shopping_cart),
                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 12)),
                  if (customerOrders.isEmpty)
                    Card(
                      child: Padding(
                        padding: ResponsiveHelper.getResponsivePadding(context),
                        child: Center(
                          child: Text(
                            'No orders found for this customer.',
                            style: TextStyle(
                              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16), 
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    ...customerOrders.map((order) => _buildOrderCard(order, appState)),
                  
                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 20)),
                  
                  // Payment History Section (Separate from Orders)
                  _buildSectionHeader('Payment History', Icons.payment),
                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 12)),
                  if (customerPayments.isEmpty)
                    Card(
                      child: Padding(
                        padding: ResponsiveHelper.getResponsivePadding(context),
                        child: Center(
                          child: Text(
                            'No payments found for this customer.',
                            style: TextStyle(
                              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16), 
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    Builder(
                      builder: (BuildContext context) {
                        // Get all positive payments and sort by date
                        final positivePayments = customerPayments
                            .where((p) => p.amount > 0) // Only show actual payments, not credits
                            .toList();
                        positivePayments.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
                        
                        return Column(
                          children: positivePayments.map((payment) {
                            // Get the order for this payment
                            final order = customerOrders.firstWhere(
                              (o) => o.id == payment.orderId,
                              orElse: () => customerOrders.first,
                            );
                            return _buildPaymentHistoryCard(payment, order, appState);
                          }).toList(),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: ResponsiveHelper.getResponsivePadding(context),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context, 8)),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 18),
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 4)),
          Text(
            title,
            style: TextStyle(
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 12),
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDueAmountCard(int difference) {
    String title;
    String value;
    Color color;
    
    if (difference > 0) {
      // Customer owes money
      title = 'Due Amount';
      value = 'Rs. $difference';
      color = Colors.red;
    } else if (difference == 0) {
      // Fully paid
      title = 'Due Amount';
      value = 'Rs. 0';
      color = Colors.green;
    } else {
      // Customer has overpaid
      title = 'Extra Amount Given';
      value = 'Rs. ${difference.abs()}';
      color = Colors.blue;
    }
    
    return Container(
      padding: ResponsiveHelper.getResponsivePadding(context),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context, 8)),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 18),
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 4)),
          Text(
            title,
            style: TextStyle(
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 12),
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: ResponsiveHelper.getResponsiveSpacing(context, 4)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: ResponsiveHelper.isMobile(context) ? 80 : 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
                fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon, 
          color: primaryColor,
          size: ResponsiveHelper.getResponsiveIconSize(context, 24),
        ),
        SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, 8)),
        Text(
          title,
          style: TextStyle(
            fontSize: ResponsiveHelper.getResponsiveFontSize(context, 20),
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildOrderCard(order_model.OrderModel order, AppState appState) {
    return Card(
      margin: EdgeInsets.only(bottom: ResponsiveHelper.getResponsiveSpacing(context, 8)),
      child: Padding(
        padding: ResponsiveHelper.getResponsivePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Order #${order.id.substring(0, 8)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
                  ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 8)),
            Row(
              children: [
                Icon(
                  Icons.shopping_bag, 
                  size: ResponsiveHelper.getResponsiveIconSize(context, 16), 
                  color: Colors.grey[600],
                ),
                SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, 4)),
                Text(
                  'Quantity: ${order.quantity}',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                  ),
                ),
                SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, 16)),
                Icon(
                  Icons.attach_money, 
                  size: ResponsiveHelper.getResponsiveIconSize(context, 16), 
                  color: Colors.grey[600],
                ),
                SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, 4)),
                Text(
                  'Rs. ${(order.price + (order.salesTax ?? 0)) * order.quantity}',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                  ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 4)),
            Row(
              children: [
                Icon(
                  Icons.calendar_today, 
                  size: ResponsiveHelper.getResponsiveIconSize(context, 16), 
                  color: Colors.grey[600],
                ),
                SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, 4)),
                Text(
                  _formatDate(order.orderDate),
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                  ),
                ),
              ],
            ),
            if (order.notes != null && order.notes!.isNotEmpty) ...[
              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 4)),
              Text(
                'Notes: ${order.notes}',
                style: TextStyle(
                  color: Colors.grey[600], 
                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, 12),
                ),
              ),
            ],
            
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentHistoryCard(Payment payment, order_model.OrderModel order, AppState appState) {
    // Calculate order total
    final orderTotal = (order.price + (order.salesTax ?? 0)) * order.quantity;
    // Get all payments for this order
    final orderPayments = appState.payments.where((p) => p.orderId == order.id).toList();
    // Calculate total paid (only positive payments)
    final totalPaid = orderPayments.where((p) => p.amount > 0).fold<int>(0, (sum, p) => sum + p.amount);
    
    return Card(
      margin: EdgeInsets.only(bottom: ResponsiveHelper.getResponsiveSpacing(context, 8)),
      elevation: 2,
      child: Padding(
        padding: ResponsiveHelper.getResponsivePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order # and Amount
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.receipt_long,
                            size: ResponsiveHelper.getResponsiveIconSize(context, 18),
                            color: Colors.green,
                          ),
                          SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, 8)),
                          Text(
                            'Order #${order.id.substring(0, 8)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 8)),
                      Row(
                        children: [
                          Icon(
                            Icons.payment,
                            size: ResponsiveHelper.getResponsiveIconSize(context, 14),
                            color: Colors.grey[600],
                          ),
                          SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, 4)),
                          Text(
                            'Payment Method: ${payment.paymentMethod}',
                            style: TextStyle(
                              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 13),
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      if (payment.collectedBy != null && payment.collectedBy!.isNotEmpty) ...[
                        SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 4)),
                        Row(
                          children: [
                            Icon(
                              Icons.person,
                              size: ResponsiveHelper.getResponsiveIconSize(context, 14),
                              color: Colors.grey[600],
                            ),
                            SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, 4)),
                            Text(
                              'Collected by: ${payment.collectedBy}',
                              style: TextStyle(
                                fontSize: ResponsiveHelper.getResponsiveFontSize(context, 12),
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Rs. ${payment.amount}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, 18),
                        color: Colors.green,
                      ),
                    ),
                    SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 4)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: ResponsiveHelper.getResponsiveIconSize(context, 12),
                          color: Colors.grey[600],
                        ),
                        SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, 4)),
                        Text(
                          _formatDate(payment.paymentDate),
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getResponsiveFontSize(context, 12),
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            
            // Cash Received Summary for this Order
            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 12)),
            Container(
              padding: ResponsiveHelper.getResponsivePadding(context).copyWith(
                top: 8,
                bottom: 8,
              ),
              decoration: BoxDecoration(
                color: totalPaid >= orderTotal ? Colors.green[50] : Colors.orange[50],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: totalPaid >= orderTotal ? Colors.green[200]! : Colors.orange[200]!,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.payments,
                        size: ResponsiveHelper.getResponsiveIconSize(context, 16),
                        color: totalPaid >= orderTotal ? Colors.green[700] : Colors.orange[700],
                      ),
                      SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, 6)),
                      Text(
                        'Cash Received:',
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, 13),
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Rs. $totalPaid / Rs. $orderTotal',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                      fontWeight: FontWeight.bold,
                      color: totalPaid >= orderTotal ? Colors.green[700] : Colors.orange[700],
                    ),
                  ),
                ],
              ),
            ),
            
            if (payment.notes != null && payment.notes!.isNotEmpty) ...[
              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 8)),
              Container(
                padding: ResponsiveHelper.getResponsivePadding(context).copyWith(top: 8, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.note,
                      size: ResponsiveHelper.getResponsiveIconSize(context, 14),
                      color: Colors.grey[600],
                    ),
                    SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, 4)),
                    Expanded(
                      child: Text(
                        payment.notes!,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }


  void _showGenerateInvoiceDialog(BuildContext context, List<order_model.OrderModel> orders) {
    // Filter out pending orders - only show delivered and in-transit orders
    final availableOrders = orders.where((order) => 
      order.status.toLowerCase() != 'pending'
    ).toList();
    
    if (availableOrders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No completed orders available for invoicing'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Create a map to track selected orders
    Map<String, bool> selectedOrders = {};
    for (var order in availableOrders) {
      selectedOrders[order.id] = true; // Default to selected
    }
    bool includeSalesTax = false; // Default to false

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            'Generate Invoice',
            style: TextStyle(
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 18),
            ),
          ),
          content: SizedBox(
            width: ResponsiveHelper.getResponsiveDialogWidth(context),
            height: ResponsiveHelper.getResponsiveDialogHeight(context),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text('Select orders to include in the invoice:'),
                    ),
                    Text(
                      '${availableOrders.length} orders',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        ...availableOrders.map((order) => CheckboxListTile(
                          title: Text('Order #${order.id.substring(0, 8)}'),
                          subtitle: Text('Rs. ${order.price * order.quantity} - ${_formatDate(order.orderDate)}'),
                          value: selectedOrders[order.id] ?? true,
                          onChanged: (value) {
                            setState(() {
                              selectedOrders[order.id] = value ?? false;
                            });
                          },
                        )),
                        const Divider(),
                        CheckboxListTile(
                          title: const Text('Include Sales Tax'),
                          subtitle: const Text('Add sales tax calculations to the invoice'),
                          value: includeSalesTax,
                          onChanged: (value) {
                            setState(() {
                              includeSalesTax = value ?? false;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info, color: Colors.blue[600], size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Selected: ${selectedOrders.values.where((selected) => selected).length}/${availableOrders.length}',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
              onPressed: () {
                // Get only selected orders
                final selectedOrderIds = selectedOrders.entries
                    .where((entry) => entry.value)
                    .map((entry) => entry.key)
                    .toList();
                
                if (selectedOrderIds.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select at least one order')),
                  );
                  return;
                }
                
                final selectedOrdersList = availableOrders
                    .where((order) => selectedOrderIds.contains(order.id))
                    .toList();
                
                Navigator.pop(context);
                _generateInvoice(context, selectedOrdersList, includeSalesTax: includeSalesTax);
              },
              child: const Text('Generate PDF'),
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _generateInvoice(BuildContext context, List<order_model.OrderModel> orders, {bool includeSalesTax = false}) async {
    // Store all context-dependent references before async operations
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final appState = Provider.of<AppState>(context, listen: false);
    final salesTaxPercentage = appState.getSalesTaxPercentage();
    
    // Orders are already filtered in the dialog, no need to filter again
    final filteredOrders = orders;
    
    
    // Check if there are any orders to invoice
    if (filteredOrders.isEmpty) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('No orders found to generate invoice'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    
    try {
      final pdf = pw.Document();
      
      // Get company name before PDF generation
      final companyName = await _getCompanyName(appState);
      
      // Calculate how many orders can fit per page
      const int ordersPerPage = 10; // Reduced to ensure better fit
      final totalPages = (filteredOrders.length / ordersPerPage).ceil();
      
      for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
        final startIndex = pageIndex * ordersPerPage;
        final endIndex = (startIndex + ordersPerPage).clamp(0, filteredOrders.length);
        final pageOrders = filteredOrders.sublist(startIndex, endIndex);
        
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context pdfContext) {
            // Use a simple, reliable font approach to avoid Helvetica issues
            final simpleStyle = pw.TextStyle(fontSize: 10);
            final headerStyle = pw.TextStyle(fontSize: 14);
            final titleStyle = pw.TextStyle(fontSize: 18);
            final largeTitleStyle = pw.TextStyle(fontSize: 24);
            
            return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Header
                  pw.Center(
                    child: pw.Text(
                      '$companyName Water Delivery',
                      style: largeTitleStyle,
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Center(
                    child: pw.Text(
                      'Customer Invoice',
                      style: titleStyle,
                    ),
                  ),
                  if (totalPages > 1) ...[
                    pw.SizedBox(height: 10),
                    pw.Center(
                      child: pw.Text(
                        'Page ${pageIndex + 1} of $totalPages',
                        style: simpleStyle,
                      ),
                    ),
                  ],
                  pw.SizedBox(height: 30),
                  
                  // Customer Details (only on first page)
                  if (pageIndex == 0) ...[
                    pw.Text(
                      'Customer Details:',
                      style: headerStyle,
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text('Name: ${widget.customer.name}', style: simpleStyle),
                    pw.Text('Contact: ${widget.customer.phone}', style: simpleStyle),
                    pw.Text('Area: ${widget.customer.area}', style: simpleStyle),
                    pw.SizedBox(height: 20),
                    
                    // Invoice Details
                    pw.Text(
                      'Invoice Details:',
                      style: headerStyle,
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text('Invoice Date: ${_formatDate(DateTime.now())}', style: simpleStyle),
                    pw.Text('Period: ${_formatDate(filteredOrders.first.orderDate)} - ${_formatDate(filteredOrders.last.orderDate)}', style: simpleStyle),
                    pw.SizedBox(height: 20),
                  ],
                
                
                // Orders Table
                pw.Table(
                  border: pw.TableBorder.all(),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1.5),   // Order #
                    1: const pw.FlexColumnWidth(1.2),   // Date
                    2: const pw.FlexColumnWidth(2.0),   // Product
                    3: const pw.FlexColumnWidth(0.8),   // Qty
                    4: const pw.FlexColumnWidth(1.0),   // Rate
                    5: const pw.FlexColumnWidth(1.2),   // Price
                    6: const pw.FlexColumnWidth(1.3),   // Paid
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Order #', style: headerStyle),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Date', style: headerStyle),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Product', style: headerStyle),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Qty', style: headerStyle),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Rate', style: headerStyle),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Price', style: headerStyle),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Paid', style: headerStyle),
                        ),
                      ],
                    ),
                    ...pageOrders.map((order) {
                      
                      // Since OrderModel doesn't have productId, use a generic product name
                      // or derive it from customer's bottle rate
                      String productName = 'Water Bottle';
                      if (widget.customer.bottleRate > 0) {
                        productName = '${widget.customer.bottleRate}L Water Bottle';
                      }
                      
                      // Calculate paid amount for this order
                      final orderPayments = appState.payments.where((payment) => payment.orderId == order.id).toList();
                      final totalPaid = orderPayments
                          .where((payment) => payment.amount > 0)
                          .fold<int>(0, (sum, payment) => sum + payment.amount);
                      
                      // Calculate order total (price * quantity + sales tax if applicable)
                      final baseTotal = order.price * order.quantity;
                      final orderTotal = includeSalesTax && order.salesTax != null
                          ? (baseTotal + (order.salesTax! * order.quantity)).round()
                          : baseTotal;
                      
                      // Determine paid status text
                      String paidText;
                      if (totalPaid == orderTotal) {
                        paidText = 'Paid';
                      } else if (totalPaid > orderTotal) {
                        // Overpaid - show credit amount
                        final creditAmount = totalPaid - orderTotal;
                        paidText = '$creditAmount credit';
                      } else {
                        // Partially paid - show due amount
                        final dueAmount = orderTotal - totalPaid;
                        paidText = '$dueAmount due';
                      }
                      
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(order.id.substring(0, 8), style: simpleStyle),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(_formatDate(order.orderDate), style: simpleStyle),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(productName, style: simpleStyle),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(order.quantity.toString(), style: simpleStyle),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('Rs. ${order.price}', style: simpleStyle),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('Rs. ${order.price * order.quantity}', style: simpleStyle),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(paidText, style: simpleStyle),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
                  pw.SizedBox(height: 20),
                  
                  // Totals (only on last page)
                  if (pageIndex == totalPages - 1) ...[
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.end,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text(
                              'Subtotal: Rs. ${filteredOrders.fold<int>(0, (sum, order) => sum + (order.price * order.quantity))}',
                              style: headerStyle,
                            ),
                            if (includeSalesTax) ...[
                              pw.SizedBox(height: 4),
                              pw.Text(
                                'Sales Tax (${salesTaxPercentage.toInt()}%): Rs. ${(filteredOrders.fold<int>(0, (sum, order) => sum + (order.price * order.quantity)) * (salesTaxPercentage / 100)).round()}',
                                style: headerStyle,
                              ),
                            ],
                            pw.SizedBox(height: 8),
                            pw.Text(
                              'Total Amount: Rs. ${includeSalesTax ? (filteredOrders.fold<int>(0, (sum, order) => sum + (order.price * order.quantity)) * (1 + salesTaxPercentage / 100)).round() : filteredOrders.fold<int>(0, (sum, order) => sum + (order.price * order.quantity))}',
                              style: titleStyle,
                            ),
                            pw.SizedBox(height: 8),
                            pw.Text(
                              'Amount in Words: ${_numberToWords(includeSalesTax ? (filteredOrders.fold<int>(0, (sum, order) => sum + (order.price * order.quantity)) * (1 + salesTaxPercentage / 100)).round() : filteredOrders.fold<int>(0, (sum, order) => sum + (order.price * order.quantity)))} Rupees Only',
                              style: simpleStyle,
                            ),
                          ],
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 40),
                    
                    // Footer
                    pw.Center(
                      child: pw.Text(
                        'Powered by RathiSoft',
                        style: simpleStyle,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        );
      }
      
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error generating invoice: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String> _getCompanyName(AppState appState) async {
    // Get the company name from the current user's companyId
    if (!mounted) return 'Water Delivery Company';
    if (appState.currentUser != null) {
      try {
        // First try to get company name by companyId (works for both admin and employees)
        if (appState.currentUser!.companyId != null) {
          final companyName = await FirebaseService.getCompanyNameByCompanyId(appState.currentUser!.companyId);
          if (!mounted) return 'Water Delivery Company';
          if (companyName != null && companyName.isNotEmpty) {
            return companyName;
          }
        }
        
        // Fallback: try to get company admin by uid (for legacy admin users)
        final companyAdmin = await FirebaseService.getCompanyAdmin(appState.currentUser!.uid);
        if (!mounted) return 'Water Delivery Company';
        if (companyAdmin != null && companyAdmin.companyName != null) {
          return companyAdmin.companyName!;
        }
      } catch (e) {
        // Error getting company name, use fallback
      }
    }
    return 'Water Delivery Company'; // Fallback
  }


  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _numberToWords(int number) {
    if (number == 0) return 'Zero';
    
    final List<String> ones = [
      '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
      'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
      'Seventeen', 'Eighteen', 'Nineteen'
    ];
    
    final List<String> tens = [
      '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'
    ];
    
    String result = '';
    
    // Handle thousands
    if (number >= 1000) {
      int thousands = number ~/ 1000;
      result += _numberToWords(thousands) + ' Thousand ';
      number %= 1000;
    }
    
    // Handle hundreds
    if (number >= 100) {
      int hundreds = number ~/ 100;
      result += ones[hundreds] + ' Hundred ';
      number %= 100;
    }
    
    // Handle tens and ones
    if (number >= 20) {
      int ten = number ~/ 10;
      result += tens[ten] + ' ';
      number %= 10;
    }
    
    if (number > 0) {
      result += ones[number] + ' ';
    }
    
    return result.trim();
  }
}
