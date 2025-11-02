import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'main.dart';
import 'models/expense.dart';
import 'models/income.dart';
import 'services/firebase_service.dart';
import 'utils/date_grouping_utils.dart';

class RevenueScreen extends StatefulWidget {
  const RevenueScreen({super.key});

  @override
  State<RevenueScreen> createState() => _RevenueScreenState();
}

class _RevenueScreenState extends State<RevenueScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPeriod = 'Daily';
  final List<String> _periods = ['Daily', 'Monthly', 'Yearly'];
  
  // Date range for sales report
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    // Set default date range to current month
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return AppShell(
          title: 'Revenue Management',
          body: Column(
            children: [
              // Header with Period Selector
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Revenue Overview',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    DropdownButton<String>(
                      value: _selectedPeriod,
                      items: _periods.map((period) => DropdownMenuItem(
                        value: period,
                        child: Text(
                          period,
                          style: const TextStyle(
                            fontSize: 14,
                          ),
                        ),
                      )).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedPeriod = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),

              // Revenue Summary Cards
              _buildRevenueSummary(appState),

              // Tab Bar
              TabBar(
                controller: _tabController,
                labelColor: primaryColor,
                unselectedLabelColor: Colors.grey,
                labelStyle: const TextStyle(
                  fontSize: 14,
                ),
                tabs: [
                  Tab(
                    text: 'Income', 
                    icon: Icon(
                      Icons.trending_up,
                      size: 20,
                    ),
                  ),
                  Tab(
                    text: 'Expenses', 
                    icon: Icon(
                      Icons.trending_down,
                      size: 20,
                    ),
                  ),
                  Tab(
                    text: 'Sales Report', 
                    icon: Icon(
                      Icons.sell,
                      size: 20,
                    ),
                  ),
                  Tab(
                    text: 'Charts', 
                    icon: Icon(
                      Icons.bar_chart,
                      size: 20,
                    ),
                  ),
                ],
              ),

              // Tab Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildIncomeTab(appState),
                    _buildExpensesTab(appState),
                    _buildSalesReportTab(appState),
                    _buildChartsTab(appState),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRevenueSummary(AppState appState) {
    final totalIncome = appState.income.fold<int>(0, (sum, income) => sum + income.amount);
    final totalExpenses = appState.expenses.fold<int>(0, (sum, expense) => sum + expense.amount);
    final profit = totalIncome - totalExpenses;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              'Total Income',
              'Rs. ${totalIncome.toString()}',
              Colors.green,
              Icons.trending_up,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildSummaryCard(
              'Total Expenses',
              'Rs. ${totalExpenses.toString()}',
              Colors.red,
              Icons.trending_down,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildSummaryCard(
              'Profit/Loss',
              'Rs. ${profit.toString()}',
              profit >= 0 ? Colors.green : Colors.red,
              profit >= 0 ? Icons.thumb_up : Icons.thumb_down,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color, IconData icon) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              icon, 
              color: color, 
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomeTab(AppState appState) {
    return Column(
      children: [
        // Add Income Button
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Income Records',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddIncomeDialog(context, appState),
                icon: const Icon(Icons.add),
                label: const Text('Add Income'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),

        // Income List
        Expanded(
          child: appState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : appState.income.isEmpty
                  ? const Center(
                      child: Text(
                        'No income records found.',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : _buildGroupedIncomeList(appState.income),
        ),
      ],
    );
  }

  Widget _buildExpensesTab(AppState appState) {
    return Column(
      children: [
        // Add Expense Button
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Expense Records',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddExpenseDialog(context, appState),
                icon: const Icon(Icons.add),
                label: const Text('Add Expense'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),

        // Expenses List
        Expanded(
          child: appState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : appState.expenses.isEmpty
                  ? const Center(
                      child: Text(
                        'No expense records found.',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : _buildGroupedExpenseList(appState.expenses),
        ),
      ],
    );
  }

  Widget _buildSalesReportTab(AppState appState) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use scrollable layout for mobile, fixed layout for desktop
        if (constraints.maxWidth < 600) {
          // Mobile layout - scrollable
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Header with Date Range Selector and Generate Report Button
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Sales Report',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showDateRangePicker(context),
                              icon: const Icon(Icons.date_range, size: 18),
                              label: Text(
                                _startDate != null && _endDate != null 
                                    ? '${_formatDate(_startDate!)} - ${_formatDate(_endDate!)}'
                                    : 'Select Date Range',
                                style: const TextStyle(fontSize: 12),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _startDate != null && _endDate != null 
                                  ? () => _generateSalesReport(context, appState)
                                  : null,
                              icon: const Icon(Icons.picture_as_pdf, size: 18),
                              label: const Text(
                                'Generate Report',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Sales Summary Cards
                  _buildSalesSummaryCards(appState),
                  
                  const SizedBox(height: 20),
                  
                  // Sales Chart - Fixed height for mobile
                  Container(
                    height: 300,
                    child: _buildSalesChart(appState),
                  ),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        } else {
          // Desktop layout - current layout
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Header with Date Range Selector and Generate Report Button
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Sales Report',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showDateRangePicker(context),
                            icon: const Icon(Icons.date_range, size: 18),
                            label: Text(
                              _startDate != null && _endDate != null 
                                  ? '${_formatDate(_startDate!)} - ${_formatDate(_endDate!)}'
                                  : 'Select Date Range',
                              style: const TextStyle(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _startDate != null && _endDate != null 
                                ? () => _generateSalesReport(context, appState)
                                : null,
                            icon: const Icon(Icons.picture_as_pdf, size: 18),
                            label: const Text(
                              'Generate Report',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Sales Summary Cards
                _buildSalesSummaryCards(appState),
                
                const SizedBox(height: 20),
                
                // Sales Chart
                Expanded(
                  child: _buildSalesChart(appState),
                ),
              ],
            ),
          );
        }
      },
    );
  }

  Future<void> _generateSalesReport(BuildContext context, AppState appState) async {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a date range first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final pdf = pw.Document();
      
      // Get company name
      final companyName = await _getCompanyName(context);
      
      // Calculate sales data for selected date range
      final rangeOrders = appState.orders.where((order) => 
          order.orderDate.isAfter(_startDate!) && 
          order.orderDate.isBefore(_endDate!.add(const Duration(days: 1))) &&
          StatusUtils.normalizeStatus(order.status) == 'Delivered').toList();
      
      final totalSales = rangeOrders.fold<int>(0, (sum, order) => sum + (order.price * order.quantity));
      final totalBottles = rangeOrders.fold<int>(0, (sum, order) => sum + order.quantity);
      final totalOrders = rangeOrders.length;
      final averageOrderValue = totalOrders > 0 ? (totalSales / totalOrders).round() : 0;
      
      // Calculate additional metrics
      final orderValues = rangeOrders.map((order) => order.price * order.quantity).toList();
      final highestOrderValue = orderValues.isNotEmpty ? orderValues.reduce((a, b) => a > b ? a : b) : 0;
      final lowestOrderValue = orderValues.isNotEmpty ? orderValues.reduce((a, b) => a < b ? a : b) : 0;
      
      // Calculate customer metrics
      final customerOrderCounts = <String, int>{};
      for (final order in rangeOrders) {
        customerOrderCounts[order.customerId] = (customerOrderCounts[order.customerId] ?? 0) + 1;
      }
      final repeatCustomers = customerOrderCounts.values.where((count) => count > 1).length;
      final newCustomers = customerOrderCounts.values.where((count) => count == 1).length;
      
      // Calculate product type sales (using customer bottle rates as product sizes)
      final productSales = <String, Map<String, int>>{};
      for (final order in rangeOrders) {
        final customer = appState.customers.firstWhere(
          (c) => c.id == order.customerId,
          orElse: () => Customer(
            id: '',
            name: 'Unknown',
            phone: '',
            area: '',
            address: '',
            product: '',
            numberOfBottles: 0,
            daysAssigned: [],
            lastDelivery: DateTime.now(),
            paymentMode: 'Cash',
            bottleRate: 0,
            bottleDeposit: 0,
            createdAt: DateTime.now(),
          ),
        );
        final productSize = '${customer.bottleRate}L';
        if (!productSales.containsKey(productSize)) {
          productSales[productSize] = {'units': 0, 'revenue': 0};
        }
        productSales[productSize]!['units'] = productSales[productSize]!['units']! + order.quantity;
        productSales[productSize]!['revenue'] = productSales[productSize]!['revenue']! + (order.price * order.quantity);
      }
      
      // Calculate sales by channel (using customer payment mode as channel)
      final channelSales = <String, Map<String, int>>{};
      for (final order in rangeOrders) {
        final customer = appState.customers.firstWhere(
          (c) => c.id == order.customerId,
          orElse: () => Customer(
            id: '',
            name: 'Unknown',
            phone: '',
            area: '',
            address: '',
            product: '',
            numberOfBottles: 0,
            daysAssigned: [],
            lastDelivery: DateTime.now(),
            paymentMode: 'Cash',
            bottleRate: 0,
            bottleDeposit: 0,
            createdAt: DateTime.now(),
          ),
        );
        final channel = customer.paymentMode;
        if (!channelSales.containsKey(channel)) {
          channelSales[channel] = {'orders': 0, 'revenue': 0};
        }
        channelSales[channel]!['orders'] = channelSales[channel]!['orders']! + 1;
        channelSales[channel]!['revenue'] = channelSales[channel]!['revenue']! + (order.price * order.quantity);
      }
      

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context pdfContext) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Center(
                  child: pw.Text(
                    '$companyName Water Delivery',
                    style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Center(
                  child: pw.Text(
                    'Sales Report',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.SizedBox(height: 30),
                
                // Report Details
                pw.Text(
                  'Report Period:',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Text('From: ${_formatDate(_startDate!)}'),
                pw.Text('To: ${_formatDate(_endDate!)}'),
                pw.Text('Generated: ${_formatDate(DateTime.now())}'),
                pw.SizedBox(height: 20),
                
                // Sales Summary Table
                pw.Text(
                  'Sales Summary:',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(),
                  columnWidths: {
                    0: const pw.FixedColumnWidth(100),
                    1: const pw.FixedColumnWidth(80),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Metric', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Value', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Total Sales', style: pw.TextStyle(fontSize: 9)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Rs. $totalSales', style: pw.TextStyle(fontSize: 9)),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Bottles Sold', style: pw.TextStyle(fontSize: 9)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('$totalBottles', style: pw.TextStyle(fontSize: 9)),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Total Orders', style: pw.TextStyle(fontSize: 9)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('$totalOrders', style: pw.TextStyle(fontSize: 9)),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Avg. Order Value', style: pw.TextStyle(fontSize: 9)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Rs. $averageOrderValue', style: pw.TextStyle(fontSize: 9)),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Highest Order Value', style: pw.TextStyle(fontSize: 9)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Rs. $highestOrderValue', style: pw.TextStyle(fontSize: 9)),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Lowest Order Value', style: pw.TextStyle(fontSize: 9)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Rs. $lowestOrderValue', style: pw.TextStyle(fontSize: 9)),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Repeat Customers', style: pw.TextStyle(fontSize: 9)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('$repeatCustomers', style: pw.TextStyle(fontSize: 9)),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('New Customers', style: pw.TextStyle(fontSize: 9)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('$newCustomers', style: pw.TextStyle(fontSize: 9)),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                
                // Sales by Product Type Table
                pw.Text(
                  'Sales by Product Type:',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(),
                  columnWidths: {
                    0: const pw.FixedColumnWidth(80),
                    1: const pw.FixedColumnWidth(60),
                    2: const pw.FixedColumnWidth(80),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Product Size', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Units Sold', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Revenue (Rs.)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        ),
                      ],
                    ),
                    ...productSales.entries.map((entry) => pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(entry.key, style: pw.TextStyle(fontSize: 9)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('${entry.value['units']}', style: pw.TextStyle(fontSize: 9)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('${entry.value['revenue']}', style: pw.TextStyle(fontSize: 9)),
                        ),
                      ],
                    )),
                  ],
                ),
                pw.SizedBox(height: 20),
                
                // Sales by Channel Table
                pw.Text(
                  'Sales by Channel:',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(),
                  columnWidths: {
                    0: const pw.FixedColumnWidth(100),
                    1: const pw.FixedColumnWidth(60),
                    2: const pw.FixedColumnWidth(80),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Channel', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Orders', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Revenue (Rs.)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        ),
                      ],
                    ),
                    ...channelSales.entries.map((entry) => pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(entry.key, style: pw.TextStyle(fontSize: 9)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('${entry.value['orders']}', style: pw.TextStyle(fontSize: 9)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('${entry.value['revenue']}', style: pw.TextStyle(fontSize: 9)),
                        ),
                      ],
                    )),
                  ],
                ),
                pw.SizedBox(height: 30),
                
                // Footer
                pw.Center(
                  child: pw.Text(
                    'Powered by RathiSoft',
                    style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
                  ),
                ),
              ],
            );
          },
        ),
      );
      
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Sales_Report_${_formatDate(_startDate!)}_to_${_formatDate(_endDate!)}.pdf',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sales report generated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildSalesSummaryCards(AppState appState) {
    if (_startDate == null || _endDate == null) {
      return const Center(
        child: Text(
          'Please select a date range to view sales data',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }
    
    // Calculate sales data for selected date range
    final rangeOrders = appState.orders.where((order) => 
        order.orderDate.isAfter(_startDate!) && 
        order.orderDate.isBefore(_endDate!.add(const Duration(days: 1))) &&
        StatusUtils.normalizeStatus(order.status) == 'Delivered').toList();
    
    final totalSales = rangeOrders.fold<int>(0, (sum, order) => sum + (order.price * order.quantity));
    final totalBottles = rangeOrders.fold<int>(0, (sum, order) => sum + order.quantity);
    final totalOrders = rangeOrders.length;
    final averageOrderValue = totalOrders > 0 ? (totalSales / totalOrders).round() : 0;

    return Row(
      children: [
        Expanded(
          child: _buildSalesCard(
            'Total Sales',
            'Rs. $totalSales',
            Colors.green,
            Icons.attach_money,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSalesCard(
            'Bottles Sold',
            '$totalBottles',
            Colors.blue,
            Icons.local_drink,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSalesCard(
            'Total Orders',
            '$totalOrders',
            Colors.orange,
            Icons.shopping_cart,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSalesCard(
            'Avg. Order Value',
            'Rs. $averageOrderValue',
            Colors.purple,
            Icons.trending_up,
          ),
        ),
      ],
    );
  }

  Widget _buildSalesCard(String title, String value, Color color, IconData icon) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesChart(AppState appState) {
    if (_startDate == null || _endDate == null) {
      return const Center(
        child: Text(
          'Please select a date range to view sales chart',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }
    
    // Generate daily sales data for selected date range
    final daysDifference = _endDate!.difference(_startDate!).inDays + 1;
    final dailySalesData = List.generate(daysDifference, (index) {
      final date = _startDate!.add(Duration(days: index));
      return _getDailySales(date, appState);
    });

    if (dailySalesData.every((sales) => sales == 0)) {
      return const Center(
        child: Text(
          'No sales data available for selected date range',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    final maxValue = dailySalesData.reduce((a, b) => a > b ? a : b);
    final maxY = maxValue > 0 ? (maxValue.toDouble() * 1.2) : 1000.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
        children: [
          Text(
            'Daily Sales Trend - ${_formatDate(_startDate!)} to ${_formatDate(_endDate!)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const Text('');
                        return Text(
                          'Rs.${value.toInt()}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final dayIndex = value.toInt();
                        if (dayIndex < dailySalesData.length) {
                          final date = _startDate!.add(Duration(days: dayIndex));
                          // Show every 5th day or first/last day
                          if (dayIndex % 5 == 0 || dayIndex == 0 || dayIndex == dailySalesData.length - 1) {
                            return Text(
                              '${date.day}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            );
                          }
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 5,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withOpacity(0.2),
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    );
                  },
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                barGroups: dailySalesData.asMap().entries.map((entry) {
                  final value = entry.value;
                  final dayIndex = entry.key;
                  final date = _startDate!.add(Duration(days: dayIndex));
                  final isToday = date.day == DateTime.now().day && 
                                 date.month == DateTime.now().month && 
                                 date.year == DateTime.now().year;
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: value.toDouble(),
                        color: isToday ? Colors.green : Colors.green.withOpacity(0.7),
                        width: 12,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxY.toDouble(),
                          color: Colors.grey.withOpacity(0.1),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _getDailySales(DateTime date, AppState appState) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
    
    return appState.orders
        .where((order) => 
            order.orderDate.isAfter(startOfDay) && 
            order.orderDate.isBefore(endOfDay) &&
            StatusUtils.normalizeStatus(order.status) == 'Delivered')
        .fold(0, (sum, order) => sum + (order.price * order.quantity));
  }

  void _showDateRangePicker(BuildContext context) {
    DateTime? tempStartDate = _startDate;
    DateTime? tempEndDate = _endDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Select Date Range'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('Start Date'),
                  subtitle: Text(tempStartDate != null ? _formatDate(tempStartDate!) : 'Not selected'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: tempStartDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() {
                        tempStartDate = date;
                        // If end date is before start date, reset end date
                        if (tempEndDate != null && tempEndDate!.isBefore(date)) {
                          tempEndDate = null;
                        }
                      });
                    }
                  },
                ),
                ListTile(
                  title: const Text('End Date'),
                  subtitle: Text(tempEndDate != null ? _formatDate(tempEndDate!) : 'Not selected'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: tempEndDate ?? DateTime.now(),
                      firstDate: tempStartDate ?? DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() {
                        tempEndDate = date;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        final now = DateTime.now();
                        setState(() {
                          tempStartDate = DateTime(now.year, now.month, 1);
                          tempEndDate = DateTime(now.year, now.month + 1, 0);
                        });
                      },
                      child: const Text('This Month'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        final now = DateTime.now();
                        setState(() {
                          tempStartDate = DateTime(now.year, now.month - 1, 1);
                          tempEndDate = DateTime(now.year, now.month, 0);
                        });
                      },
                      child: const Text('Last Month'),
                    ),
                  ],
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
              onPressed: tempStartDate != null && tempEndDate != null ? () {
                setState(() {
                  _startDate = tempStartDate;
                  _endDate = tempEndDate;
                });
                Navigator.pop(context);
              } : null,
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartsTab(AppState appState) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Text(
            'Revenue Analytics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          // Period selector for charts
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildChartPeriodButton('Daily', _selectedPeriod == 'Daily'),
              _buildChartPeriodButton('Monthly', _selectedPeriod == 'Monthly'),
              _buildChartPeriodButton('Yearly', _selectedPeriod == 'Yearly'),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _selectedPeriod == 'Daily' 
                ? _buildDailyBarChart(appState)
                : _selectedPeriod == 'Monthly'
                    ? _buildMonthlyBarChart(appState)
                    : _buildYearlyBarChart(appState),
          ),
        ],
      ),
    );
  }

  Widget _buildChartPeriodButton(String period, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPeriod = period;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          period,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildDailyBarChart(AppState appState) {
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;
    
    // Generate data for current month (1-31 days)
    final daysInMonth = DateTime(currentYear, currentMonth + 1, 0).day;
    final monthlyData = List.generate(daysInMonth, (index) {
      final day = index + 1;
      final date = DateTime(currentYear, currentMonth, day);
      return _getDailyIncome(date, appState);
    });

    if (monthlyData.every((income) => income == 0)) {
      return const Center(
        child: Text(
          'No data available for this month',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    final maxValue = monthlyData.reduce((a, b) => a > b ? a : b);
    final maxY = maxValue > 0 ? (maxValue.toDouble() * 1.2) : 1000.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const Text('');
                  return Text(
                    'Rs.${value.toInt()}',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  final day = value.toInt() + 1;
                  if (day % 5 == 0 || day == 1 || day == daysInMonth) {
                    return Text(
                      '$day',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 5,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.withOpacity(0.2),
                strokeWidth: 1,
                dashArray: [5, 5],
              );
            },
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(
              color: Colors.grey.withOpacity(0.3),
              width: 1,
            ),
          ),
          barGroups: monthlyData.asMap().entries.map((entry) {
            final value = entry.value;
            final day = entry.key + 1;
            final isToday = day == now.day;
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: value.toDouble(),
                  color: isToday ? Colors.blue : Colors.blue.withOpacity(0.7),
                  width: 12,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxY.toDouble(),
                    color: Colors.grey.withOpacity(0.1),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMonthlyBarChart(AppState appState) {
    final now = DateTime.now();
    final currentYear = now.year;
    
    // Generate data for all 12 months of current year (1-12)
    final monthlyData = List.generate(12, (index) {
      final month = index + 1; // 1-12
      final date = DateTime(currentYear, month);
      return _getMonthlyIncome(date, appState);
    });

    if (monthlyData.every((income) => income == 0)) {
      return const Center(
        child: Text(
          'No data available for this year',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    final maxValue = monthlyData.reduce((a, b) => a > b ? a : b);
    final maxY = maxValue > 0 ? (maxValue.toDouble() * 1.2) : 1000.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const Text('');
                  return Text(
                    'Rs.${value.toInt()}',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  final month = value.toInt() + 1; // 1-12
                  final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                  if (month >= 1 && month <= 12) {
                    return Text(
                      monthNames[month - 1],
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 5,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.withOpacity(0.2),
                strokeWidth: 1,
                dashArray: [5, 5],
              );
            },
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(
              color: Colors.grey.withOpacity(0.3),
              width: 1,
            ),
          ),
          barGroups: monthlyData.asMap().entries.map((entry) {
            final value = entry.value;
            final index = entry.key;
            final month = index + 1; // 1-12
            
            // Check if this is the current month
            final isCurrentMonth = month == now.month;
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: value.toDouble(),
                  color: isCurrentMonth ? Colors.green : Colors.green.withOpacity(0.7),
                  width: 16,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxY.toDouble(),
                    color: Colors.grey.withOpacity(0.1),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildYearlyBarChart(AppState appState) {
    final now = DateTime.now();
    final years = <int>[];
    final yearlyData = <int>[];
    
    // Get all available years from income data
    final allYears = appState.income.map((income) => income.date.year).toSet().toList();
    allYears.sort();
    
    // If no data, show last 3 years
    if (allYears.isEmpty) {
      for (int i = 2; i >= 0; i--) {
        years.add(now.year - i);
        yearlyData.add(_getYearlyIncome(now.year - i, appState));
      }
    } else {
      years.addAll(allYears);
      for (int year in years) {
        yearlyData.add(_getYearlyIncome(year, appState));
      }
    }

    if (yearlyData.every((income) => income == 0)) {
      return const Center(
        child: Text(
          'No data available for yearly view',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    final maxValue = yearlyData.reduce((a, b) => a > b ? a : b);
    final maxY = maxValue > 0 ? (maxValue.toDouble() * 1.2) : 1000.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const Text('');
                  return Text(
                    'Rs.${value.toInt()}',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() < years.length) {
                    return Text(
                      years[value.toInt()].toString(),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 5,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.withOpacity(0.2),
                strokeWidth: 1,
                dashArray: [5, 5],
              );
            },
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(
              color: Colors.grey.withOpacity(0.3),
              width: 1,
            ),
          ),
          barGroups: yearlyData.asMap().entries.map((entry) {
            final value = entry.value;
            final isCurrentYear = years[entry.key] == now.year;
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: value.toDouble(),
                  color: isCurrentYear ? Colors.orange : Colors.orange.withOpacity(0.7),
                  width: 20,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxY.toDouble(),
                    color: Colors.grey.withOpacity(0.1),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  int _getDailyIncome(DateTime date, AppState appState) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
    
    return appState.income
        .where((income) => 
            income.date.isAfter(startOfDay) && 
            income.date.isBefore(endOfDay))
        .fold(0, (sum, income) => sum + income.amount);
  }

  int _getMonthlyIncome(DateTime date, AppState appState) {
    final startOfMonth = DateTime(date.year, date.month);
    final endOfMonth = DateTime(date.year, date.month + 1);
    
    return appState.income
        .where((income) => 
            income.date.isAfter(startOfMonth) && 
            income.date.isBefore(endOfMonth))
        .fold(0, (sum, income) => sum + income.amount);
  }

  int _getYearlyIncome(int year, AppState appState) {
    final startOfYear = DateTime(year);
    final endOfYear = DateTime(year + 1);
    
    return appState.income
        .where((income) => 
            income.date.isAfter(startOfYear) && 
            income.date.isBefore(endOfYear))
        .fold(0, (sum, income) => sum + income.amount);
  }


  void _showAddIncomeDialog(BuildContext context, AppState appState) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Manual Income'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount (Rs.)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter amount';
                    }
                    if (int.tryParse(value) == null || int.parse(value) <= 0) {
                      return 'Please enter a valid amount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Date'),
                  subtitle: Text(_formatDate(selectedDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() {
                        selectedDate = date;
                      });
                    }
                  },
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
                if (formKey.currentState!.validate()) {
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  Navigator.pop(context);
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Adding income...'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  
                  try {
                    await appState.createManualIncome(
                      title: titleController.text,
                      description: descriptionController.text,
                      amount: int.parse(amountController.text),
                      date: selectedDate,
                    );
                    await appState.setupAuthListener();
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('Income added successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: appState.isLoading ? const CircularProgressIndicator() : const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddExpenseDialog(BuildContext context, AppState appState) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    final categoryController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Expense'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount (Rs.)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter amount';
                    }
                    if (int.tryParse(value) == null || int.parse(value) <= 0) {
                      return 'Please enter a valid amount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter category';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Date'),
                  subtitle: Text(_formatDate(selectedDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() {
                        selectedDate = date;
                      });
                    }
                  },
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
                if (formKey.currentState!.validate()) {
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  Navigator.pop(context);
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Adding expense...'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  
                  try {
                    await appState.createExpense(
                      title: titleController.text,
                      description: descriptionController.text,
                      amount: int.parse(amountController.text),
                      category: categoryController.text,
                      date: selectedDate,
                    );
                    await appState.setupAuthListener();
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('Expense added successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: appState.isLoading ? const CircularProgressIndicator() : const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteIncomeConfirmation(BuildContext context, AppState appState, Income income) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Income'),
        content: Text('Are you sure you want to delete "${income.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await appState.deleteIncome(income.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Income deleted successfully!'),
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

  void _showDeleteExpenseConfirmation(BuildContext context, AppState appState, Expense expense) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text('Are you sure you want to delete "${expense.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await appState.deleteExpense(expense.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Expense deleted successfully!'),
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

  Future<void> _generateIncomeInvoice(BuildContext context, Income income, {bool includeSalesTax = false}) async {
    try {
      final pdf = pw.Document();
      
      // Get company name and sales tax percentage before PDF generation
      final companyName = await _getCompanyName(context);
      final appState = Provider.of<AppState>(context, listen: false);
      final salesTaxPercentage = appState.getSalesTaxPercentage();
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context pdfContext) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Center(
                  child: pw.Text(
                    '$companyName Water Delivery',
                    style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Center(
                  child: pw.Text(
                    'Income Receipt',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.SizedBox(height: 30),
                
                // Receipt Details
                pw.Text(
                  'Receipt Details:',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Text('Receipt ID: ${income.id.substring(0, 8)}'),
                pw.Text('Date: ${_formatDate(income.date)}'),
                pw.Text('Created: ${_formatDate(income.createdAt)}'),
                pw.SizedBox(height: 20),
                
                // Income Information
                pw.Text(
                  'Income Information:',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Text('Title: ${income.title}'),
                pw.Text('Description: ${income.description}'),
                pw.Text('Source: ${income.source == 'automatic' ? 'Automatic (Bottle Sales)' : 'Manual Entry'}'),
                pw.SizedBox(height: 20),
                
                // Amount Table
                pw.Table(
                  border: pw.TableBorder.all(),
                  columnWidths: {
                    0: const pw.FixedColumnWidth(150),
                    1: const pw.FixedColumnWidth(100),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(income.title),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Rs. ${income.amount}'),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                
                // Totals
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        if (includeSalesTax) ...[
                          pw.Text(
                            'Subtotal: Rs. ${(income.amount / (1 + (salesTaxPercentage / 100))).round()}',
                            style: pw.TextStyle(fontSize: 14),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Sales Tax (${salesTaxPercentage.toInt()}%): Rs. ${(income.amount - (income.amount / (1 + (salesTaxPercentage / 100))).round())}',
                            style: pw.TextStyle(fontSize: 14),
                          ),
                          pw.SizedBox(height: 8),
                        ],
                        pw.Text(
                          'Total Amount: Rs. ${income.amount}',
                          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
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
                    style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
                  ),
                ),
              ],
            );
          },
        ),
      );
      
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating invoice: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String> _getCompanyName(BuildContext context) async {
    // Get the company name from the current user's companyId
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.currentUser != null) {
      try {
        // First try to get company name by companyId (works for both admin and employees)
        if (appState.currentUser!.companyId != null) {
          final companyName = await FirebaseService.getCompanyNameByCompanyId(appState.currentUser!.companyId);
          if (companyName != null && companyName.isNotEmpty) {
            return companyName;
          }
        }
        
        // Fallback: try to get company admin by uid (for legacy admin users)
        final companyAdmin = await FirebaseService.getCompanyAdmin(appState.currentUser!.uid);
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

  // Build grouped income list with date grouping
  Widget _buildGroupedIncomeList(List<Income> incomeList) {
    final groupedIncome = DateGroupingUtils.groupItemsByDate(
      incomeList,
      (income) => income.date,
    );
    
    return ListView.builder(
      itemCount: DateGroupingUtils.getOrderedGroups().length,
      cacheExtent: 500,
      itemBuilder: (context, groupIndex) {
        final group = DateGroupingUtils.getOrderedGroups()[groupIndex];
        final incomeInGroup = groupedIncome[group]!;
        
        if (incomeInGroup.isEmpty) {
          return const SizedBox.shrink();
        }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: DateGroupingUtils.getDateGroupColor(group).withOpacity(0.1),
              child: Text(
                '${DateGroupingUtils.getDateGroupTitle(group)} (${incomeInGroup.length})',
                style: TextStyle(
                  color: DateGroupingUtils.getDateGroupColor(group),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            // Income items in this group
            ...incomeInGroup.map((income) => _buildIncomeCard(income)),
          ],
        );
      },
    );
  }

  // Build grouped expense list with date grouping
  Widget _buildGroupedExpenseList(List<Expense> expenseList) {
    final groupedExpenses = DateGroupingUtils.groupItemsByDate(
      expenseList,
      (expense) => expense.date,
    );
    
    return ListView.builder(
      itemCount: DateGroupingUtils.getOrderedGroups().length,
      cacheExtent: 500,
      itemBuilder: (context, groupIndex) {
        final group = DateGroupingUtils.getOrderedGroups()[groupIndex];
        final expensesInGroup = groupedExpenses[group]!;
        
        if (expensesInGroup.isEmpty) {
          return const SizedBox.shrink();
        }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: DateGroupingUtils.getDateGroupColor(group).withOpacity(0.1),
              child: Text(
                '${DateGroupingUtils.getDateGroupTitle(group)} (${expensesInGroup.length})',
                style: TextStyle(
                  color: DateGroupingUtils.getDateGroupColor(group),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            // Expense items in this group
            ...expensesInGroup.map((expense) => _buildExpenseCard(expense)),
          ],
        );
      },
    );
  }

  // Build individual income card
  Widget _buildIncomeCard(Income income) {
    // Determine if this is an on-demand delivery
    final isOnDemand = income.description.toLowerCase().contains('on demand') || 
                       income.description.toLowerCase().contains('on-demand');
    
    // Extract bottle count from description if available
    final bottleMatch = RegExp(r'(\d+)\s*bottles?').firstMatch(income.description);
    final bottleCount = bottleMatch != null ? int.tryParse(bottleMatch.group(1) ?? '') : null;
    
    // Determine customer display name
    final customerDisplayName = income.customerName?.isNotEmpty == true 
        ? income.customerName! 
        : (income.title.contains('Payment from ') 
            ? income.title.replaceFirst('Payment from ', '') 
            : income.title);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: income.source == 'automatic' ? Colors.blue : Colors.green,
          child: Icon(
            income.source == 'automatic' ? Icons.auto_awesome : Icons.add,
            color: Colors.white,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                customerDisplayName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (bottleCount != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Text(
                  '$bottleCount ${bottleCount == 1 ? 'Bottle' : 'Bottles'}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              income.description,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (isOnDemand)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.orange[300]!),
                    ),
                    child: Text(
                      'On-Demand',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: income.source == 'automatic' ? Colors.blue[50] : Colors.green[50],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    income.source == 'automatic' ? 'Automatic' : 'Manual',
                    style: TextStyle(
                      fontSize: 11,
                      color: income.source == 'automatic' ? Colors.blue[700] : Colors.green[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  DateGroupingUtils.formatDate(income.date),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        trailing: SizedBox(
          width: 120,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Rs. ${income.amount}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                income.source == 'automatic' ? 'Auto' : 'Manual',
                style: TextStyle(
                  fontSize: 10,
                  color: income.source == 'automatic' ? Colors.blue : Colors.green,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build individual expense card
  Widget _buildExpenseCard(Expense expense) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.red,
          child: const Icon(Icons.remove, color: Colors.white),
        ),
        title: Text(
          expense.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(expense.description),
            Text(
              'Category: ${expense.category}',
              style: const TextStyle(color: Colors.orange, fontSize: 12),
            ),
            Text(
              'Date: ${DateGroupingUtils.formatDate(expense.date)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: SizedBox(
          width: 80,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Rs. ${expense.amount}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 2),
              GestureDetector(
                onTap: () async {
                  try {
                    final appState = Provider.of<AppState>(context, listen: false);
                    await appState.deleteExpense(expense.id);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Expense deleted successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error deleting expense: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 10,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
