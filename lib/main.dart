import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'firebase_options.dart';
import 'services/firebase_service.dart';
import 'models/product.dart';
import 'models/vendor.dart';
import 'models/vendor_pickup.dart';
import 'models/order.dart';
import 'models/expense.dart';
import 'models/income.dart';
import 'models/invoice.dart';
import 'models/settings.dart';
import 'models/auto_order.dart';
import 'models/attendance.dart';
import 'utils/responsive_helper.dart';
import 'utils/date_grouping_utils.dart';
import 'utils/pakistan_time.dart';
import 'customer_detail_screen.dart';
import 'revenue_screen.dart';
import 'settings_screen.dart';
import 'vendors_screen.dart';
import 'screens/driver_vendors_screen.dart';
import 'auto_orders_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Pakistan timezone
  await PakistanTime.initialize();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    ChangeNotifierProvider(
      create: (context) => AppState(),
      child: const WaterDeliveryApp(),
    ),
  );
}

/// Theme Colors - Enhanced color scheme
const Color primaryColor = Color(0xFF1565C0); // Blue
const Color primaryDark = Color(0xFF0D47A1);
const Color secondaryColor = Color(0xFFFFFFFF); // White
const Color accentColor = Color(0xFF43A047); // Green
const Color backgroundColor = Color(0xFFF5F5F5);
const Color surfaceColor = Color(0xFFFFFFFF);
const Color errorColor = Color(0xFFE53935);
const Color successColor = Color(0xFF4CAF50);
const Color warningColor = Color(0xFFFF9800);

/// ======== DATA MODELS ========

class UserAccount {
  final String uid;
  final String email;
  final String password;
  final String name;
  final String role; // 'admin', 'driver'
  final String? companyId; // For company-specific data isolation
  final DateTime createdAt;
  final String? assignedRoute; // For drivers
  final List<String>? assignedAreas; // For drivers
  final bool isActive;
  final String? phone;
  final String? address;
  // Additional driver/employee fields
  final String? cnic;
  final String? contactNumber;
  final String? driverAddress;
  final String? salary;
  final String? designation;
  final String? salaryType; // 'Monthly', 'Weekly', 'Daily', 'Hourly'

  UserAccount({
    required this.uid,
    required this.email,
    required this.password,
    required this.name,
    required this.role,
    this.companyId,
    required this.createdAt,
    this.assignedRoute,
    this.assignedAreas,
    this.isActive = true,
    this.phone,
    this.address,
    this.cnic,
    this.contactNumber,
    this.driverAddress,
    this.salary,
    this.designation,
    this.salaryType,
  });

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'email': email,
    'password': password,
    'name': name,
    'role': role,
    'companyId': companyId,
    'createdAt': createdAt.toIso8601String(),
    'assignedRoute': assignedRoute,
    'assignedAreas': assignedAreas,
    'isActive': isActive,
    'phone': phone,
    'address': address,
    'cnic': cnic,
    'contactNumber': contactNumber,
    'driverAddress': driverAddress,
    'salary': salary,
    'designation': designation,
    'salaryType': salaryType,
  };

  factory UserAccount.fromJson(Map<String, dynamic> json) => UserAccount(
    uid: json['uid'] ?? json['id'] ?? '',
    email: json['email'] ?? '',
    password: json['password'] ?? '',
    name: json['name'] ?? '',
    role: json['role'] ?? '',
    companyId: json['companyId'],
    createdAt: json['createdAt'] != null
        ? (json['createdAt'] is String
            ? DateTime.parse(json['createdAt'])
            : (json['createdAt'] as Timestamp).toDate())
        : DateTime.now(),
    assignedRoute: json['assignedRoute'],
    assignedAreas: json['assignedAreas']?.cast<String>(),
    isActive: json['isActive'] ?? true,
    phone: json['phone'],
    address: json['address'],
    cnic: json['cnic'],
    contactNumber: json['contactNumber'],
    driverAddress: json['driverAddress'],
    salary: json['salary'],
    designation: json['designation'],
    salaryType: json['salaryType'],
  );

  // Helper method to determine if employee has login credentials
  // Note: Password is not stored in Firestore for security reasons
  // So we only check if email is provided (non-empty)
  bool get hasLoginCredentials => 
      email.isNotEmpty;
}

class Customer {
  final String id;
  final String name;
  final String phone;
  final String address;
  final String area; // Route Assigned
  final String product; // Product type
  final int numberOfBottles; // Number of bottles per delivery
  final List<String> daysAssigned; // Days of week assigned for delivery
  final String paymentMode; // Payment mode (Cash/Credit)
  final int bottleRate; // Rate per bottle in PKR
  final int bottleDeposit; // Deposit amount for bottles in PKR
  final int bottlesDelivered;
  final int bottlesReturned;
  final DateTime lastDelivery;
  final String? assignedDriver;
  final DateTime? createdAt;
  final String? companyId; // For company-specific data isolation

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.area,
    required this.product,
    required this.numberOfBottles,
    required this.daysAssigned,
    required this.paymentMode,
    required this.bottleRate,
    required this.bottleDeposit,
    this.bottlesDelivered = 0,
    this.bottlesReturned = 0,
    required this.lastDelivery,
    this.assignedDriver,
    this.createdAt,
    this.companyId,
  });

  Customer copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    String? area,
    String? product,
    int? numberOfBottles,
    List<String>? daysAssigned,
    String? paymentMode,
    int? bottleRate,
    int? bottleDeposit,
    int? bottlesDelivered,
    int? bottlesReturned,
    DateTime? lastDelivery,
    String? assignedDriver,
    DateTime? createdAt,
    String? companyId,
  }) => Customer(
    id: id ?? this.id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    address: address ?? this.address,
    area: area ?? this.area,
    product: product ?? this.product,
    numberOfBottles: numberOfBottles ?? this.numberOfBottles,
    daysAssigned: daysAssigned ?? this.daysAssigned,
    paymentMode: paymentMode ?? this.paymentMode,
    bottleRate: bottleRate ?? this.bottleRate,
    bottleDeposit: bottleDeposit ?? this.bottleDeposit,
    bottlesDelivered: bottlesDelivered ?? this.bottlesDelivered,
    bottlesReturned: bottlesReturned ?? this.bottlesReturned,
    lastDelivery: lastDelivery ?? this.lastDelivery,
    assignedDriver: assignedDriver ?? this.assignedDriver,
    createdAt: createdAt ?? this.createdAt,
    companyId: companyId ?? this.companyId,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'address': address,
    'area': area,
    'product': product,
    'numberOfBottles': numberOfBottles,
    'daysAssigned': daysAssigned,
    'paymentMode': paymentMode,
    'bottleRate': bottleRate,
    'bottleDeposit': bottleDeposit,
    'bottlesDelivered': bottlesDelivered,
    'bottlesReturned': bottlesReturned,
    'lastDelivery': lastDelivery.toIso8601String(),
    'assignedDriver': assignedDriver,
    'createdAt': createdAt?.toIso8601String(),
    'companyId': companyId,
  };

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    phone: json['phone'] ?? '',
    address: json['address'] ?? '',
    area: json['area'] ?? '',
    product: json['product'] ?? '',
    numberOfBottles: json['numberOfBottles'] ?? 0,
    daysAssigned: List<String>.from(json['daysAssigned'] ?? []),
    paymentMode: json['paymentMode'] ?? 'Cash',
    bottleRate: json['bottleRate'] ?? 0,
    bottleDeposit: json['bottleDeposit'] ?? 0,
    bottlesDelivered: json['bottlesDelivered'] ?? 0,
    bottlesReturned: json['bottlesReturned'] ?? 0,
    lastDelivery: json['lastDelivery'] != null 
        ? (json['lastDelivery'] is Timestamp 
            ? (json['lastDelivery'] as Timestamp).toDate()
            : DateTime.parse(json['lastDelivery']))
        : DateTime.now(),
    assignedDriver: json['assignedDriver'],
    createdAt: json['createdAt'] != null 
        ? (json['createdAt'] is Timestamp 
            ? (json['createdAt'] as Timestamp).toDate()
            : DateTime.parse(json['createdAt']))
        : null,
    companyId: json['companyId'],
  );
}


class Payment {
  final String id;
  final String orderId;
  final int amount;
  final DateTime paymentDate;
  final String? collectedBy;
  final String? notes;
  final String paymentMethod; // 'Cash', 'Bank Transfer', 'Card', 'Online'

  Payment({
    required this.id,
    required this.orderId,
    required this.amount,
    required this.paymentDate,
    this.collectedBy,
    this.notes,
    this.paymentMethod = 'Cash',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'orderId': orderId,
    'amount': amount,
    'paymentDate': paymentDate.toIso8601String(),
    'collectedBy': collectedBy,
    'notes': notes,
    'paymentMethod': paymentMethod,
  };

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
    id: json['id'] ?? '',
    orderId: json['orderId'] ?? '',
    amount: json['amount'] ?? 0,
    paymentDate: json['paymentDate'] != null
        ? (json['paymentDate'] is Timestamp 
            ? (json['paymentDate'] as Timestamp).toDate()
            : DateTime.parse(json['paymentDate']))
        : DateTime.now(),
    collectedBy: json['collectedBy'] ?? '',
    notes: json['notes'] ?? '',
    paymentMethod: json['paymentMethod'] ?? 'Cash',
  );
}

class RoutePlan {
  final List<String> days; // Changed from single day to multiple days
  final List<String> areas;
  final String? assignedDriver;
  final DateTime createdAt;

  RoutePlan({
    required this.days, // Changed from day to days
    required this.areas,
    this.assignedDriver,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'days': days, // Changed from day to days
    'areas': areas,
    'assignedDriver': assignedDriver,
    'createdAt': createdAt.toIso8601String(),
  };

  factory RoutePlan.fromJson(Map<String, dynamic> json) {
    try {
      return RoutePlan(
        days: (json['days'] as List<dynamic>?)?.cast<String>() ?? 
              (json['day'] != null ? [json['day']] : []), // Support both old and new format
    areas: (json['areas'] as List<dynamic>?)?.cast<String>() ?? [],
    assignedDriver: json['assignedDriver'],
    createdAt: json['createdAt'] != null 
        ? (json['createdAt'] is Timestamp 
            ? (json['createdAt'] as Timestamp).toDate()
            : DateTime.parse(json['createdAt']))
        : DateTime.now(),
  );
    } catch (e) {
      // Return a default RoutePlan if parsing fails
      return RoutePlan(
        days: [],
        areas: [],
        assignedDriver: null,
        createdAt: PakistanTime.now(),
      );
    }
  }
}


/// ======== APP STATE MANAGEMENT ========

class AppState extends ChangeNotifier {
  // final FirebaseService _firebaseService = FirebaseService();
  
  UserAccount? _currentUser;
  List<UserAccount> _employees = [];
  List<Customer> _customers = [];
  List<OrderModel> _orders = [];
  List<Payment> _payments = [];
  List<Product> _products = [];
  List<Vendor> _vendors = [];
  List<VendorPickup> _vendorPickups = [];
  List<Expense> _expenses = [];
  List<Income> _income = [];
  List<Invoice> _invoices = [];
  List<AutoOrder> _autoOrders = [];
  List<Attendance> _attendance = [];
  Map<String, RoutePlan> _routes = {}; // Key will be route ID instead of day
  Map<String, dynamic> _todayBottleSells = {};
  AppSettings? _settings;
  bool _isLoading = false;
  String? _error;
  bool _isCreatingEmployee = false; // Flag to prevent loading employee profile during creation

  // Getters
  UserAccount? get currentUser => _currentUser;
  List<UserAccount> get employees => _employees;
  List<Customer> get customers => _customers;
  List<OrderModel> get orders => _orders;
  List<Payment> get payments => _payments;
  List<Product> get products => _products;
  List<Vendor> get vendors => _vendors;
  List<VendorPickup> get vendorPickups => _vendorPickups;
  List<Expense> get expenses => _expenses;
  List<Income> get income => _income;
  List get driverLoads => [];
  List<Invoice> get invoices => _invoices;
  List<AutoOrder> get autoOrders => _autoOrders;
  List<Attendance> get attendance => _attendance;
  Map<String, RoutePlan> get routes => _routes;
  Map<String, dynamic> get todayBottleSells => _todayBottleSells;
  AppSettings? get settings => _settings;
  bool get isLoading => _isLoading;
  String? get error => _error;


  bool get isAdmin => _currentUser?.role == 'admin';
  bool get isDriver => _currentUser?.role == 'driver';

  AppState() {
    setupAuthListener();
  }

  Future<void> setupAuthListener() async {
    _setLoading(true);
    try {
      // Set up auth state listener
      FirebaseAuth.instance.authStateChanges().listen((user) async {
        if (user != null) {
          // If we're creating an employee, don't load the profile (it will be the employee, not admin)
          if (_isCreatingEmployee) {
            // Sign out immediately if we're in the middle of employee creation
            await FirebaseAuth.instance.signOut();
            _currentUser = null;
            notifyListeners();
            return;
          }
          _loadUserProfile(user.uid);
        } else {
          _currentUser = null;
          notifyListeners();
        }
      });
    } catch (e) {
      _setError('Failed to initialize Firebase: $e');
    } finally {
      _setLoading(false);
    }
  }

  void _setupRealtimeListeners() {
    // Check if user has companyId to determine data source
    if (_currentUser?.companyId != null) {
      // Use company-specific data for new company admins
      _setupCompanySpecificListeners();
    } else {
      // Use global data for legacy admin (admin@rathisoft.pk)
      _setupGlobalListeners();
    }
  }

  void _setupCompanySpecificListeners() {
    // Company-specific Products listener
    FirebaseService.getCompanyProductsStream().listen((products) {
      _products = products;
      notifyListeners();
    });

    // Company-specific Customers listener
    FirebaseService.getCompanyCustomersStream().listen((customers) {
      _customers = customers.map((c) => Customer.fromJson(c)).toList();
      notifyListeners();
      
      // NOTE: Removed automatic validation to prevent flickering.
      // Customers are assigned via routes, and that assignment should persist.
      // Only run validateAndCleanupDriverAssignments() manually when needed.
    });

    // Company-specific Orders listener
    FirebaseService.getCompanyOrdersStream().listen((orders) {
      _orders = orders.map((o) => OrderModel.fromJson(o)).toList();
      notifyListeners();
    });

    // Company-specific Employees listener - only set up for admins
    // Check if current user is admin before setting up listener
    if (_currentUser?.role == 'admin') {
      FirebaseService.getCompanyEmployeesStream().listen(
        (employees) {
          // Only update if we're still an admin (prevent employees from seeing this data)
          if (_currentUser?.role == 'admin') {
            _employees = employees.map((e) => UserAccount.fromJson(e)).toList();
            notifyListeners();
          }
        },
        onError: (error) {
          // Handle errors gracefully - log but don't break the app
          print('Error in employee stream listener: $error');
          // Optionally, you could set an error state here
        },
        cancelOnError: false, // Keep listening even if there's an error
      );
    }

    // Company-specific Payments listener
    FirebaseService.getCompanyPaymentsStream().listen((payments) {
      _payments = payments.map((p) => Payment.fromJson(p)).toList();
      notifyListeners();
    });

    // Company-specific Settings listener
    FirebaseService.getSettingsStream().listen((settings) {
      _settings = settings;
      notifyListeners();
    });

    // Company-specific Vendors listener
    FirebaseService.getVendorsStream().listen((vendors) {
      _vendors = vendors;
      notifyListeners();
    });

    // Vendor Pickups listener
    FirebaseService.getVendorPickupsStream().listen((pickups) {
      _vendorPickups = pickups;
      notifyListeners();
    });

    // Company-specific Expenses listener
    FirebaseService.getExpensesStream().listen((expenses) {
      _expenses = expenses;
      notifyListeners();
    });

    // Company-specific Income listener
    FirebaseService.getIncomeStream().listen((income) {
      _income = income;
      notifyListeners();
    });

    // Company-specific Invoice listener
    FirebaseService.getInvoicesStream().listen((invoices) {
      _invoices = invoices;
      notifyListeners();
    });

    // Company-specific Auto Orders listener
    FirebaseService.getAutoOrdersStream(_currentUser?.companyId).listen((autoOrders) {
      _autoOrders = autoOrders;
      notifyListeners();
    });

    // Company-specific Attendance listener
    FirebaseService.getCompanyAttendanceStream().listen((attendance) {
      _attendance = attendance;
      notifyListeners();
    });


    // Company-specific Routes listener
    FirebaseService.getCompanyRoutesStream().listen((routes) {
      try {
        
        final validRoutes = <MapEntry<String, RoutePlan>>[];
        
        for (final r in routes) {
          try {
            // Skip null or empty routes
            if (r == null || r.isEmpty) {
              continue;
            }
            
            // Validate route data structure
            if (!r.containsKey('days') && !r.containsKey('day')) {
              continue;
            }
            
            final routeId = r['id']?.toString() ?? 
                           r['day']?.toString() ?? 
                           DateTime.now().millisecondsSinceEpoch.toString();
            
            // Try to create RoutePlan with error handling
            final routePlan = RoutePlan.fromJson(r);
            validRoutes.add(MapEntry(routeId, routePlan));
            
          } catch (e) {
            // Skip this route and continue with others
            continue;
          }
        }
        
        _routes = Map.fromEntries(validRoutes);
      notifyListeners();
        
      } catch (e) {
        // Keep existing routes if there's an error
      }
    });
  }

  void _setupGlobalListeners() {
    // Products listener
    FirebaseService.getProductsStream().listen((products) {
      _products = products;
      notifyListeners();
    });

    // Customers listener
    FirebaseService.getCustomersStream().listen((customers) {
      _customers = customers.map((c) => Customer.fromJson(c)).toList();
      notifyListeners();
    });

    // Orders listener
    FirebaseService.getOrdersStream().listen((orders) {
      _orders = orders.map((o) => OrderModel.fromJson(o)).toList();
      notifyListeners();
    });

    // Payments listener
    FirebaseService.getPaymentsStream().listen((payments) {
      _payments = payments.map((p) => Payment.fromJson(p)).toList();
      notifyListeners();
    });

    // Routes listener
    FirebaseService.getRoutesStream().listen((routes) {
      try {
        
        final validRoutes = <MapEntry<String, RoutePlan>>[];
        
        for (final r in routes) {
          try {
            // Skip null or empty routes
            if (r == null || r.isEmpty) {
              continue;
            }
            
            // Validate route data structure
            if (!r.containsKey('days') && !r.containsKey('day')) {
              continue;
            }
            
            final routeId = r['id']?.toString() ?? 
                           r['day']?.toString() ?? 
                           DateTime.now().millisecondsSinceEpoch.toString();
            
            // Try to create RoutePlan with error handling
            final routePlan = RoutePlan.fromJson(r);
            validRoutes.add(MapEntry(routeId, routePlan));
            
          } catch (e) {
            // Skip this route and continue with others
            continue;
          }
        }
        
        _routes = Map.fromEntries(validRoutes);
      notifyListeners();
        
      } catch (e) {
        // Keep existing routes if there's an error
      }
    });

    // Today bottle sells listener
    FirebaseService.getTodayBottleSellsStream().listen((data) {
      _todayBottleSells = data;
      notifyListeners();
    });

    // Settings listener
    FirebaseService.getSettingsStream().listen((settings) {
      _settings = settings;
      notifyListeners();
    });

    // Auto Orders listener
    FirebaseService.getAutoOrdersStream(_currentUser?.companyId).listen((autoOrders) {
      _autoOrders = autoOrders;
      notifyListeners();
    });
  }

  Future<void> _loadUserProfile(String uid) async {
    try {
      
      // Ensure company admin profile is synced if needed
      await FirebaseService.ensureCompanyAdminSynced(uid);
      
      final userProfile = await FirebaseService.getUserProfile(uid);
      if (userProfile != null) {
        _currentUser = UserAccount.fromJson(userProfile);
        notifyListeners();
        
        // Set up listeners after user profile is loaded
        _setupRealtimeListeners();
        
        // Check and process auto orders automatically
        _checkAndProcessAutoOrdersOnStartup();
      } else {
        _setError('No user profile found. Please contact support.');
      }
    } catch (e) {
      _setError('Failed to load user profile: $e');
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  // Authentication methods
  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _setError(null);
    try {
      final user = await FirebaseService.signInWithEmailAndPassword(email: email, password: password);
      if (user != null) {
        await _loadUserProfile(user.user!.uid);
        return true;
      }
      return false;
    } catch (e) {
      _setError('Login failed: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> registerCompanyAdmin({
    required String email,
    required String password,
    String? companyName,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final user = await FirebaseService.registerCompanyAdmin(
        email: email,
        password: password,
        companyName: companyName,
      );
      if (user != null) {
        await _loadUserProfile(user.user!.uid);
        return true;
      }
      return false;
    } catch (e) {
      _setError('Registration failed: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    await FirebaseService.signOut();
    _currentUser = null;
    notifyListeners();
  }


  Future<void> createEmployee({
    required String name,
    String? email,
    String? password,
    required String role,
    String? phone,
    String? address,
    String? cnic,
    String? contactNumber,
    String? driverAddress,
    String? salary,
    String? designation,
    String? salaryType,
  }) async {
    if (!isAdmin) throw Exception('Only admin can create employees');
    
    _setLoading(true);
    _isCreatingEmployee = true; // Set flag to prevent auth listener from loading employee profile
    // Clear employees list to prevent flashing of old data
    _employees = [];
    notifyListeners();
    
    // Store admin UID before creating employee (since createUserWithEmailAndPassword signs in as new user)
    final adminUidBefore = _currentUser?.uid;
    
    try {
      final returnedAdminUid = await FirebaseService.createEmployee(
        name: name,
        email: email,
        password: password,
        role: role,
        phone: phone,
        address: address,
        cnic: cnic,
        contactNumber: contactNumber,
        driverAddress: driverAddress,
        salary: salary,
        designation: designation,
        salaryType: salaryType,
      );
      
      // Wait longer for sign out to complete and auth state to stabilize
      await Future.delayed(const Duration(milliseconds: 1000));
      
      // Ensure we're signed out (the auth listener should have handled this, but verify)
      final currentAuthUser = FirebaseAuth.instance.currentUser;
      if (currentAuthUser != null && currentAuthUser.uid != adminUidBefore && currentAuthUser.uid != returnedAdminUid) {
        // Still signed in as employee - force sign out
        await FirebaseAuth.instance.signOut();
        await Future.delayed(const Duration(milliseconds: 300));
      }
      
      // Clear the flag
      _isCreatingEmployee = false;
      
      // Verify final auth state
      final finalAuthUser = FirebaseAuth.instance.currentUser;
      if (finalAuthUser == null) {
        // Expected - admin was signed out
        _currentUser = null;
        notifyListeners();
        throw Exception('Employee created successfully. Please sign in again as admin to continue.');
      } else if (finalAuthUser.uid == adminUidBefore || finalAuthUser.uid == returnedAdminUid) {
        // Admin is still signed in (unlikely but possible) - reload profile
        await _loadUserProfile(finalAuthUser.uid);
      } else {
        // Unknown state - force sign out
        await FirebaseAuth.instance.signOut();
        _currentUser = null;
        notifyListeners();
        throw Exception('Employee created successfully. Please sign in again as admin to continue.');
      }
      
    } catch (e) {
      // Clear flag on error
      _isCreatingEmployee = false;
      
      // If there's an authentication error, clear the current user
      if (e.toString().contains('re-authenticate') || 
          e.toString().contains('log in again') ||
          e.toString().contains('email-already-in-use')) {
        _currentUser = null;
        notifyListeners();
      }
      rethrow; // Re-throw the error so the UI can handle it
    } finally {
      _isCreatingEmployee = false; // Always clear flag
      _setLoading(false);
    }
  }

  Future<void> deleteEmployee(String uid) async {
    if (!isAdmin) throw Exception('Only admin can delete employees');
    
    _setLoading(true);
    try {
    await FirebaseService.deleteEmployee(uid);
    
    // Manually remove the employee from local state to ensure immediate UI update
    _employees.removeWhere((employee) => employee.uid == uid);
    notifyListeners();
    
      // Force refresh the auth listener to ensure we get the latest data from Firebase
      await setupAuthListener();
      
    } catch (e) {
      _setError('Failed to delete employee: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Utility method to clean up orphaned employees
  Future<void> cleanupOrphanedEmployees() async {
    if (!isAdmin) throw Exception('Only admin can cleanup orphaned employees');
    
    _setLoading(true);
    try {
      await FirebaseService.cleanupOrphanedEmployees();
      await setupAuthListener(); // Refresh the data
    } catch (e) {
      _setError('Failed to cleanup orphaned employees: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Vendor Management Methods
  Future<void> createVendor({
    required String name,
    required int totalBottles,
    required int totalPrice,
    required int perBottleRate,
    required DateTime dateAdded,
  }) async {
    if (!isAdmin) throw Exception('Only admin can create vendors');
    
    _setLoading(true);
    _vendors = [];
    notifyListeners();
    
    try {
      final vendor = Vendor(
        id: PakistanTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        totalBottles: totalBottles,
        totalPrice: totalPrice,
        perBottleRate: perBottleRate,
        dateAdded: dateAdded,
        createdAt: PakistanTime.now(),
        updatedAt: PakistanTime.now(),
        companyId: _currentUser?.companyId,
      );
      
      await FirebaseService.createVendor(vendor);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteVendor(String vendorId) async {
    if (!isAdmin) throw Exception('Only admin can delete vendors');
    
    await FirebaseService.deleteVendor(vendorId);
  }

  Future<void> updateVendor(Vendor vendor) async {
    if (!isAdmin) throw Exception('Only admin can update vendors');
    
    _setLoading(true);
    _vendors = [];
    notifyListeners();
    
    try {
      final updatedVendor = Vendor(
        id: vendor.id,
        name: vendor.name,
        totalBottles: vendor.totalBottles,
        totalPrice: vendor.totalPrice,
        perBottleRate: vendor.perBottleRate,
        dateAdded: vendor.dateAdded,
        createdAt: vendor.createdAt,
        updatedAt: PakistanTime.now(),
        companyId: _currentUser?.companyId,
      );
      
      await FirebaseService.updateVendor(updatedVendor);
    } finally {
      _setLoading(false);
    }
  }

  // Vendor Pickup Management Methods
  Future<void> createVendorPickup({
    required String vendorId,
    required String vendorName,
    required int bottlesPicked,
    required int perBottleRate,
    required int amountPaid,
  }) async {
    if (!isDriver) throw Exception('Only drivers can create vendor pickups');
    
    _setLoading(true);
    _vendorPickups = [];
    notifyListeners();
    
    try {
      final pickup = VendorPickup(
        id: PakistanTime.now().millisecondsSinceEpoch.toString(),
        vendorId: vendorId,
        vendorName: vendorName,
        driverId: _currentUser?.uid ?? '',
        driverName: _currentUser?.name ?? '',
        bottlesPicked: bottlesPicked,
        perBottleRate: perBottleRate,
        calculatedAmount: bottlesPicked * perBottleRate,
        amountPaid: amountPaid,
        pickupDate: PakistanTime.now(),
        createdAt: PakistanTime.now(),
        companyId: _currentUser?.companyId,
      );
      
      await FirebaseService.createVendorPickup(pickup);
      
      // Add pickup to local list temporarily for immediate calculation
      // (the stream will update it properly later)
      _vendorPickups.add(pickup);
      
      // Update vendor totals after creating pickup
      await _updateVendorTotalsFromPickups(vendorId);
    } finally {
      _setLoading(false);
    }
  }

  // Update vendor totals based on all pickups for that vendor
  Future<void> _updateVendorTotalsFromPickups(String vendorId) async {
    if (!isAdmin && !isDriver) return; // Only admin or driver can update
    
    try {
      // Find the vendor
      final vendor = _vendors.firstWhere((v) => v.id == vendorId, orElse: () => throw Exception('Vendor not found'));
      
      // Calculate totals from all pickups for this vendor
      final pickups = _vendorPickups.where((p) => p.vendorId == vendorId).toList();
      final totalBottles = pickups.fold<int>(0, (sum, pickup) => sum + pickup.bottlesPicked);
      final totalPaid = pickups.fold<int>(0, (sum, pickup) => sum + pickup.amountPaid);
      
      // Update vendor with new totals
      final updatedVendor = Vendor(
        id: vendor.id,
        name: vendor.name,
        totalBottles: totalBottles,
        totalPrice: totalPaid,
        perBottleRate: vendor.perBottleRate,
        dateAdded: vendor.dateAdded,
        createdAt: vendor.createdAt,
        updatedAt: PakistanTime.now(),
        companyId: vendor.companyId,
      );
      
      await FirebaseService.updateVendor(updatedVendor);
    } catch (e) {
      // Don't throw - this is a background update
    }
  }

  List<VendorPickup> getVendorPickupsByVendor(String vendorId) {
    return _vendorPickups.where((pickup) => pickup.vendorId == vendorId).toList();
  }

  List<VendorPickup> getVendorPickupsByDriver(String driverId) {
    return _vendorPickups.where((pickup) => pickup.driverId == driverId).toList();
  }

  // Expense Management Methods
  Future<void> createExpense({
    required String title,
    required String description,
    required int amount,
    required String category,
    required DateTime date,
  }) async {
    if (!isAdmin) throw Exception('Only admin can create expenses');
    
    _setLoading(true);
    _expenses = [];
    notifyListeners();
    
    try {
      final expense = Expense(
        id: PakistanTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        description: description,
        amount: amount,
        category: category,
        date: date,
        createdAt: PakistanTime.now(),
        companyId: _currentUser?.companyId,
      );
      
      await FirebaseService.createExpense(expense);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteExpense(String expenseId) async {
    if (!isAdmin) throw Exception('Only admin can delete expenses');
    
    await FirebaseService.deleteExpense(expenseId);
  }

  // Income Management Methods
  Future<void> createManualIncome({
    required String title,
    required String description,
    required int amount,
    required DateTime date,
  }) async {
    if (!isAdmin) throw Exception('Only admin can create income');
    
    _setLoading(true);
    _income = [];
    notifyListeners();
    
    try {
      final income = Income(
        id: PakistanTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        description: description,
        amount: amount,
        source: 'manual',
        date: date,
        createdAt: PakistanTime.now(),
        companyId: _currentUser?.companyId,
      );
      
      await FirebaseService.createIncome(income);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteIncome(String incomeId) async {
    if (!isAdmin) throw Exception('Only admin can delete income');
    
    await FirebaseService.deleteIncome(incomeId);
  }

  // Invoice Management Methods
  Future<void> createInvoice({
    required String customerId,
    required String customerName,
    required List<String> orderIds,
    required int subtotal,
    required double salesTaxRate,
    String? notes,
  }) async {
    if (!isAdmin) throw Exception('Only admin can create invoices');
    
    _setLoading(true);
    _invoices = [];
    notifyListeners();
    
    try {
      final salesTax = Invoice.calculateSalesTax(subtotal, salesTaxRate);
      final total = Invoice.calculateTotal(subtotal, salesTaxRate);
      
      final invoice = Invoice(
        id: PakistanTime.now().millisecondsSinceEpoch.toString(),
        customerId: customerId,
        customerName: customerName,
        orderIds: orderIds,
        subtotal: subtotal,
        salesTax: salesTax,
        salesTaxRate: salesTaxRate,
        total: total,
        invoiceDate: DateTime.now(),
        dueDate: DateTime.now().add(const Duration(days: 30)),
        status: 'pending',
        notes: notes,
        createdAt: PakistanTime.now(),
        updatedAt: PakistanTime.now(),
        companyId: _currentUser?.companyId,
      );
      
      await FirebaseService.createInvoice(invoice);
      await setupAuthListener();
    } catch (e) {
      _setError('Failed to create invoice: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteInvoice(String invoiceId) async {
    if (!isAdmin) throw Exception('Only admin can delete invoices');
    
    await FirebaseService.deleteInvoice(invoiceId);
  }

  // Attendance Management Methods
  Future<void> saveAttendance(Attendance attendance) async {
    if (!isAdmin) throw Exception('Only admin can save attendance');
    
    await FirebaseService.saveAttendance(attendance);
  }

  Future<void> deleteAttendance(String attendanceId) async {
    if (!isAdmin) throw Exception('Only admin can delete attendance');
    
    await FirebaseService.deleteAttendance(attendanceId);
  }

  List<Attendance> getEmployeeAttendance(String employeeId) {
    return _attendance.where((attendance) => attendance.employeeId == employeeId).toList();
  }

  List<Attendance> getAttendanceForDate(DateTime date) {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return _attendance.where((attendance) {
      final attendanceDateStr = '${attendance.date.year}-${attendance.date.month.toString().padLeft(2, '0')}-${attendance.date.day.toString().padLeft(2, '0')}';
      return attendanceDateStr == dateStr;
    }).toList();
  }

  // Auto Order Management Methods
  Future<void> createAutoOrder({
    required String customerId,
    required String customerName,
    required String customerPhone,
    required String customerArea,
    required int quantity,
    required int price,
    int? salesTax,
    required String assignedDriver,
    required String dayOfWeek,
    String? notes,
  }) async {
    if (!isAdmin) throw Exception('Only admin can create auto orders');
    
    _setLoading(true);
    notifyListeners();
    
    try {
      final autoOrder = AutoOrder(
        id: PakistanTime.now().millisecondsSinceEpoch.toString(),
        customerId: customerId,
        customerName: customerName,
        customerPhone: customerPhone,
        customerArea: customerArea,
        quantity: quantity,
        price: price,
        salesTax: salesTax,
        assignedDriver: assignedDriver,
        dayOfWeek: dayOfWeek,
        isActive: true,
        nextDeliveryDate: AutoOrder.getNextDeliveryDate(dayOfWeek),
        createdAt: PakistanTime.now(),
        updatedAt: PakistanTime.now(),
        notes: notes,
        companyId: _currentUser?.companyId,
      );
      
      await FirebaseService.createAutoOrder(autoOrder);
      await setupAuthListener();
    } catch (e) {
      _setError('Failed to create auto order: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateAutoOrder(AutoOrder autoOrder) async {
    if (!isAdmin) throw Exception('Only admin can update auto orders');
    
    await FirebaseService.updateAutoOrder(autoOrder.id, autoOrder.toJson());
  }

  Future<void> cancelAutoOrder(String autoOrderId) async {
    if (!isAdmin) throw Exception('Only admin can cancel auto orders');
    
    _setLoading(true);
    notifyListeners();
    
    try {
      await FirebaseService.cancelAutoOrderAndCreatePending(autoOrderId);
      await setupAuthListener();
    } catch (e) {
      _setError('Failed to cancel auto order: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteAutoOrder(String autoOrderId) async {
    if (!isAdmin) throw Exception('Only admin can delete auto orders');
    
    await FirebaseService.deleteAutoOrder(autoOrderId);
  }

  Future<void> processAutoOrdersForToday() async {
    if (!isAdmin) throw Exception('Only admin can process auto orders');
    
    await FirebaseService.processAutoOrdersForToday(_currentUser?.companyId);
  }

  // Automatic processing of auto orders
  Future<void> _processAutoOrdersAutomatically() async {
      try {
        await FirebaseService.processAutoOrdersForToday(_currentUser?.companyId);
      } catch (e) {
        // Don't throw error to avoid breaking the app
      }
  }

  // Check and process auto orders on app startup
  Future<void> _checkAndProcessAutoOrdersOnStartup() async {
    if (_currentUser == null) return;
    
    try {
      // Check if we've already processed auto orders today
      final today = DateTime.now();
      final todayKey = '${today.year}-${today.month}-${today.day}';
      final lastProcessedDate = await _getLastAutoOrderProcessedDate();
      
      if (lastProcessedDate != todayKey) {
        await _processAutoOrdersAutomatically();
        await _setLastAutoOrderProcessedDate(todayKey);
      }
      
      // Set up periodic checking (every hour)
      _setupPeriodicAutoOrderCheck();
    } catch (e) {
    }
  }

  // Set up periodic checking for auto orders
  void _setupPeriodicAutoOrderCheck() {
    Timer.periodic(const Duration(hours: 1), (timer) async {
      if (_currentUser == null) {
        timer.cancel();
        return;
      }
      
      try {
        final today = DateTime.now();
        final todayKey = '${today.year}-${today.month}-${today.day}';
        final lastProcessedDate = await _getLastAutoOrderProcessedDate();
        
        if (lastProcessedDate != todayKey) {
          await _processAutoOrdersAutomatically();
          await _setLastAutoOrderProcessedDate(todayKey);
        }
      } catch (e) {
      }
    });
  }

  // Get last processed date from local storage
  Future<String?> _getLastAutoOrderProcessedDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('last_auto_order_processed_date');
    } catch (e) {
      return null;
    }
  }

  // Set last processed date in local storage
  Future<void> _setLastAutoOrderProcessedDate(String date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_auto_order_processed_date', date);
    } catch (e) {
    }
  }


  // NOTE: All driver load management methods removed - simplified delivery flow

  // Route management methods  
  Future<void> addRoute(RoutePlan route, String routeId) async {
    if (!isAdmin) throw Exception('Only admin can add routes');
    
    await FirebaseService.createRoute(routeId, route.toJson());
  }

  // Get driver's total bottles sold (all time) - calculated from completed orders
  int getDriverTotalBottlesSold() {
    if (_currentUser == null || !isDriver) return 0;
    
    return _orders
        .where((order) => 
            order.assignedDriver == _currentUser!.name &&
            StatusUtils.normalizeStatus(order.status) == 'Delivered')
        .fold(0, (sum, order) => sum + order.quantity);
  }

  // Get driver's total cash collected (all time) - calculated from cash payments
  int getDriverTotalCashCollected() {
    if (_currentUser == null || !isDriver) return 0;
    
    return _payments
        .where((payment) => 
            payment.collectedBy == _currentUser!.name &&
            payment.paymentMethod.toLowerCase() == 'cash')
        .fold(0, (sum, payment) => sum + payment.amount);
  }

  // Get driver's cash collected today - calculated from today's cash payments
  int getDriverTodayCashCollected() {
    if (_currentUser == null || !isDriver) return 0;
    
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    
    return _payments
        .where((payment) => 
            payment.collectedBy == _currentUser!.name &&
            payment.paymentMethod.toLowerCase() == 'cash' &&
            payment.paymentDate.isAfter(todayStart) &&
            payment.paymentDate.isBefore(todayEnd))
        .fold(0, (sum, payment) => sum + payment.amount);
  }

  // Settings methods
  Future<void> updateSalesTaxPercentage(double percentage) async {
    try {
      if (_settings == null) {
        // Create new settings if none exist
        _settings = AppSettings(
          id: 'app_settings',
          salesTaxPercentage: percentage,
          companyId: _currentUser?.companyId,
          createdAt: PakistanTime.now(),
          updatedAt: PakistanTime.now(),
        );
      } else {
        // Update existing settings
        _settings = _settings!.copyWith(
          salesTaxPercentage: percentage,
          updatedAt: PakistanTime.now(),
        );
      }
      
      await FirebaseService.updateSettings(_settings!);
      notifyListeners();
    } catch (e) {
      _setError('Failed to update sales tax percentage: $e');
    }
  }

  double getSalesTaxPercentage() {
    return _settings?.salesTaxPercentage ?? 15.0; // Default to 15% if no settings
  }

  // Get total bottles loaded for any driver (admin view) - NOTE: Returns 0 since driver loads removed
  int getDriverTotalBottlesLoaded(String driverId) {
    return 0; // Driver load tracking removed
  }

  // Get total bottles delivered for any driver (admin view) - NOTE: Returns 0 since driver loads removed
  int getDriverTotalBottlesDelivered(String driverId) {
    return 0; // Driver load tracking removed
  }

  // Get total bottles sold for any driver (admin view) - calculated from completed orders
  int getDriverTotalBottlesSoldById(String driverId) {
    final driver = _employees.firstWhere(
      (emp) => emp.uid == driverId,
      orElse: () => UserAccount(
        uid: '',
        email: '',
        name: '',
        role: 'driver',
        password: '',
        isActive: true,
        createdAt: PakistanTime.now(),
        companyId: '',
      ),
    );
    
    if (driver.uid.isEmpty) return 0; // Driver not found
    
    return _orders
        .where((order) => 
            order.assignedDriver != null &&
            order.assignedDriver!.toLowerCase().trim() == driver.name.toLowerCase().trim() &&
            StatusUtils.normalizeStatus(order.status) == 'Delivered')
        .fold(0, (sum, order) => sum + order.quantity);
  }

  // Get total cash collected for any driver (admin view) - calculated from cash payments
  int getDriverTotalCashCollectedById(String driverId) {
    final driver = _employees.firstWhere(
      (emp) => emp.uid == driverId,
      orElse: () => UserAccount(
        uid: '',
        email: '',
        name: '',
        role: 'driver',
        password: '',
        isActive: true,
        createdAt: PakistanTime.now(),
        companyId: '',
      ),
    );
    
    if (driver.uid.isEmpty) return 0; // Driver not found
    
    return _payments
        .where((payment) => 
            payment.collectedBy != null &&
            payment.collectedBy!.toLowerCase().trim() == driver.name.toLowerCase().trim() &&
            payment.paymentMethod.toLowerCase() == 'cash')
        .fold(0, (sum, payment) => sum + payment.amount);
  }

  // Route management methods
  Future<void> deleteRoute(String routeId) async {
    if (!isAdmin) throw Exception('Only admin can delete routes');
    
    // Get the route data before deleting to know which areas to unassign
    final route = _routes[routeId];
    if (route != null) {
      // Unassign customers from this route's areas and delete their auto orders
      // Pass route days directly to avoid inefficient lookup
      await _unassignCustomersFromRoute(route.areas, route.assignedDriver, route.days);
    }
    
    await FirebaseService.deleteRoute(routeId);
  }

  // Method to unassign customers from a deleted route's areas (day-specific)
  Future<void> _unassignCustomersFromRoute(List<String> areas, String? driverName, List<String> routeDays) async {
    try {
      // Find all customers in the specified areas that are assigned to this driver AND match the route days
      // Use case-insensitive, trimmed comparison for driver names
      final customersToUnassign = _customers.where((customer) {
        // Check area match
        final areaMatches = areas.any((area) => 
          customer.area.trim().toLowerCase() == area.trim().toLowerCase()
        );
        if (!areaMatches) return false;
        
        // Check driver match (case-insensitive, trimmed)
        final driverMatches = driverName != null && customer.assignedDriver != null
          ? driverName.trim().toLowerCase() == customer.assignedDriver!.trim().toLowerCase()
          : driverName == customer.assignedDriver; // Both null or both empty
        if (!driverMatches) return false;
        
        // Check day match
        final dayMatches = routeDays.any((routeDay) => customer.daysAssigned.contains(routeDay));
        return dayMatches;
      }).toList();
      
      
      int unassignedCount = 0;
      
      // Update customers and delete auto & pending orders in batch to avoid triggering multiple listeners
      final List<Future> futures = [];
      
      for (final customer in customersToUnassign) {
        // Delete auto orders for this customer
        final activeAutoOrders = _autoOrders.where((ao) => 
          ao.customerId == customer.id && 
          ao.isActive
        ).toList();
        
        for (final autoOrder in activeAutoOrders) {
          futures.add(FirebaseService.deleteAutoOrder(autoOrder.id));
        }
        
        // Delete pending orders for this customer assigned to this driver (keep Delivered only)
        final pendingOrders = _orders.where((o) =>
          o.customerId == customer.id &&
          StatusUtils.normalizeStatus(o.status) == 'Pending' &&
          (o.assignedDriver == driverName)
        ).toList();
        for (final order in pendingOrders) {
          futures.add(FirebaseService.deleteOrder(order.id));
        }

        // Update customer assignment (legacy field)
        futures.add(FirebaseService.updateCustomer(customer.id, {
          'assignedDriver': null,
        }));
            
        unassignedCount++;
      }
      
      // Execute all updates in parallel for better performance
      await Future.wait(futures);
      
      
      // Update local state immediately
      for (final customer in customersToUnassign) {
        final index = _customers.indexWhere((c) => c.id == customer.id);
        if (index != -1) {
          _customers[index] = Customer(
            id: customer.id,
            name: customer.name,
            phone: customer.phone,
            address: customer.address,
            area: customer.area,
            product: customer.product,
            numberOfBottles: customer.numberOfBottles,
            daysAssigned: customer.daysAssigned,
            paymentMode: customer.paymentMode,
            bottleRate: customer.bottleRate,
            bottleDeposit: customer.bottleDeposit,
            bottlesDelivered: customer.bottlesDelivered,
            bottlesReturned: customer.bottlesReturned,
            lastDelivery: customer.lastDelivery,
            assignedDriver: null, // Set to null
            createdAt: customer.createdAt,
            companyId: customer.companyId,
          );
        }
      }
      
      notifyListeners();
      
    } catch (e) {
    }
  }

  // Helper method for strict area matching (case-insensitive, trimmed)
  bool _isAreaMatch(String customerArea, String routeArea) {
    return customerArea.trim().toLowerCase() == routeArea.trim().toLowerCase();
  }

  // NOTE: Removed validateAndCleanupDriverAssignments() method 
  // as it was causing customers to flicker and disappear/reappear.
  // The route management system properly handles assignment and unassignment.

  // Product management methods
  Future<bool> addProduct(Product product) async {
    try {
      await FirebaseService.createProduct(product);
      return true;
    } catch (e) {
      _setError('Failed to add product: $e');
      return false;
    }
  }

  Future<bool> updateProduct(Product product) async {
    try {
      await FirebaseService.updateProduct(product);
      return true;
    } catch (e) {
      _setError('Failed to update product: $e');
      return false;
    }
  }

  Future<bool> deleteProduct(String productId) async {
    try {
      await FirebaseService.deleteProduct(productId);
      return true;
    } catch (e) {
      _setError('Failed to delete product: $e');
      return false;
    }
  }

  // Employee management methods
  Future<bool> addEmployee(UserAccount employee) async {
    try {
      await FirebaseService.createUserProfile(
        uid: employee.email,
        email: employee.email,
        name: employee.name,
        role: employee.role,
      );
      return true;
    } catch (e) {
      _setError('Failed to add employee: $e');
      return false;
    }
  }

  Future<bool> updateEmployee(UserAccount employee) async {
    try {
      await FirebaseService.updateUserProfile(
        uid: employee.email,
        name: employee.name,
        isActive: employee.isActive,
      );
      return true;
    } catch (e) {
      _setError('Failed to update employee: $e');
      return false;
    }
  }


  // Customer management methods
  Future<bool> addCustomer(Customer customer) async {
    try {
      await FirebaseService.createCustomer(customer.toJson());
      return true;
    } catch (e) {
      _setError('Failed to add customer: $e');
      return false;
    }
  }

  Future<bool> updateCustomer(Customer customer) async {
    try {
      await FirebaseService.updateCustomer(customer.id, customer.toJson());
      return true;
    } catch (e) {
      _setError('Failed to update customer: $e');
      return false;
    }
  }

  Future<bool> deleteCustomer(String customerId) async {
    try {
      await FirebaseService.deleteCustomer(customerId);
      return true;
    } catch (e) {
      _setError('Failed to delete customer: $e');
      return false;
    }
  }

  // Order management methods
  Future<bool> addOrder(OrderModel order) async {
    try {
      await FirebaseService.createOrder(order.toJson());
      return true;
    } catch (e) {
      _setError('Failed to add order: $e');
      return false;
    }
  }

  Future<bool> updateOrder(OrderModel order) async {
    try {
      await FirebaseService.updateOrder(order.id, order.toJson());
      return true;
    } catch (e) {
      _setError('Failed to update order: $e');
      return false;
    }
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      await FirebaseService.updateOrderStatus(orderId, status);
      // Update local state
      final orderIndex = _orders.indexWhere((order) => order.id == orderId);
      if (orderIndex != -1) {
        _orders[orderIndex] = _orders[orderIndex].copyWith(
          status: status,
          updatedAt: PakistanTime.now(),
        );
        notifyListeners();
      }
    } catch (e) {
      _setError('Failed to update order status: $e');
    }
  }

  // Payment management methods
  Future<bool> addPayment(Payment payment) async {
    try {
      // Find the order to get its details
      final order = _orders.firstWhere((o) => o.id == payment.orderId);
      
      await FirebaseService.createPaymentWithOrder(
        orderId: payment.orderId,
        amount: payment.amount,
        paymentMethod: payment.paymentMethod,
        customerId: order.customerId,
        quantity: order.quantity,
        price: order.price + (order.salesTax ?? 0),
        collectedBy: payment.collectedBy,
        notes: payment.notes,
        customerName: order.customerName,
      );
      return true;
    } catch (e) {
      _setError('Failed to add payment: $e');
      return false;
    }
  }

  // Route management methods
  Future<bool> updateRoutes(Map<String, RoutePlan> routes) async {
    try {
      // Note: FirebaseService doesn't have updateRoutes method
      // This would need to be implemented
      return true;
    } catch (e) {
      _setError('Failed to update routes: $e');
      return false;
    }
  }

  // Utility methods
  String nextOrderId() {
    return 'ORD${DateTime.now().millisecondsSinceEpoch}';
  }

  String nextCustomerId() {
    return 'CUST${DateTime.now().millisecondsSinceEpoch}';
  }

  Customer? getCustomerById(String id) {
    try {
      return _customers.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  // Find customer by name
  Customer? getCustomerByName(String name) {
    try {
      return _customers.firstWhere((c) => c.name.toLowerCase() == name.toLowerCase());
    } catch (e) {
      return null;
    }
  }

  // Calculate actual delivered bottles for a customer
  int getCustomerDeliveredBottles(String customerId) {
    final customer = getCustomerById(customerId);
    if (customer == null) return 0;
    
    // Try exact customer ID match first
    var deliveredOrders = _orders
        .where((order) => 
            order.customerId == customer.id && 
            StatusUtils.normalizeStatus(order.status) == 'Delivered')
        .toList();
    
    // If no exact match, try by customer name in order notes
    if (deliveredOrders.isEmpty) {
      deliveredOrders = _orders
          .where((order) => 
              StatusUtils.normalizeStatus(order.status) == 'Delivered' &&
              order.notes?.toLowerCase().contains(customer.name.toLowerCase()) == true)
          .toList();
    }
    
    // If still no match, try by customer name in customer ID field
    if (deliveredOrders.isEmpty) {
      deliveredOrders = _orders
          .where((order) => 
              StatusUtils.normalizeStatus(order.status) == 'Delivered' &&
              order.customerId.toLowerCase().contains(customer.name.toLowerCase()))
          .toList();
    }
    
    // If still no match, try by phone number
    if (deliveredOrders.isEmpty) {
      deliveredOrders = _orders
          .where((order) => 
              StatusUtils.normalizeStatus(order.status) == 'Delivered' &&
              (order.notes?.contains(customer.phone) == true ||
               order.customerId.contains(customer.phone)))
          .toList();
    }
    
    // If still no match, try by area
    if (deliveredOrders.isEmpty) {
      deliveredOrders = _orders
          .where((order) => 
              StatusUtils.normalizeStatus(order.status) == 'Delivered' &&
              (order.notes?.toLowerCase().contains(customer.area.toLowerCase()) == true ||
               order.customerId.toLowerCase().contains(customer.area.toLowerCase())))
          .toList();
    }
    
    return deliveredOrders.fold(0, (sum, order) => sum + order.quantity);
  }

  // Helper method to check if an order belongs to a customer
  bool _isOrderForCustomer(OrderModel order, Customer customer) {
    // First try exact customer ID match
    if (order.customerId == customer.id) return true;
    
    // Then try to find by customer name in various fields
    final customerName = customer.name.toLowerCase();
    
    // Check if customer name appears in notes
    if (order.notes?.toLowerCase().contains(customerName) == true) return true;
    
    // Check if customer name appears in customer ID (fallback)
    if (order.customerId.toLowerCase().contains(customerName)) return true;
    
    return false;
  }

  // Calculate actual returned bottles for a customer
  int getCustomerReturnedBottles(String customerId) {
    final customer = getCustomerById(customerId);
    if (customer == null) return 0;
    
    // Use the same comprehensive matching strategy as delivered bottles
    // Strategy 1: Try exact customer ID match
    var returnedOrders = _orders
        .where((order) => 
            order.customerId == customer.id && 
            StatusUtils.normalizeStatus(order.status) == 'Returned')
        .toList();
    
    // Strategy 2: If no exact match, try by customer name in order notes
    if (returnedOrders.isEmpty) {
      returnedOrders = _orders
          .where((order) => 
              StatusUtils.normalizeStatus(order.status) == 'Returned' &&
              order.notes?.toLowerCase().contains(customer.name.toLowerCase()) == true)
          .toList();
    }
    
    // Strategy 3: If still no match, try by customer name in customer ID field
    if (returnedOrders.isEmpty) {
      returnedOrders = _orders
          .where((order) => 
              StatusUtils.normalizeStatus(order.status) == 'Returned' &&
              order.customerId.toLowerCase().contains(customer.name.toLowerCase()))
          .toList();
    }
    
    // Strategy 4: If still no match, try by phone number
    if (returnedOrders.isEmpty) {
      returnedOrders = _orders
          .where((order) => 
              StatusUtils.normalizeStatus(order.status) == 'Returned' &&
              (order.notes?.contains(customer.phone) == true ||
               order.customerId.contains(customer.phone)))
          .toList();
    }
    
    // Strategy 5: If still no match, try by area
    if (returnedOrders.isEmpty) {
      returnedOrders = _orders
          .where((order) => 
              StatusUtils.normalizeStatus(order.status) == 'Returned' &&
              (order.notes?.toLowerCase().contains(customer.area.toLowerCase()) == true ||
               order.customerId.toLowerCase().contains(customer.area.toLowerCase())))
          .toList();
    }
    
    return returnedOrders.fold(0, (sum, order) => sum + order.quantity);
  }

  UserAccount? getEmployeeByEmail(String email) {
    try {
      return _employees.firstWhere((e) => e.email == email);
    } catch (e) {
      return null;
    }
  }

  List<OrderModel> getOrdersByStatus(String status) {
    return _orders.where((o) => o.status == status).toList();
  }

  List<OrderModel> getOrdersByCustomer(String customerId) {
    return _orders.where((o) => o.customerId == customerId).toList();
  }

  List<OrderModel> getTodayOrdersForDriver(UserAccount driver) {
    final today = DateTime.now();
    return _orders.where((o) {
      final orderDate = o.orderDate;
      return orderDate.year == today.year &&
          orderDate.month == today.month &&
          orderDate.day == today.day &&
          o.assignedDriver == driver.name;
    }).toList();
  }

  List<OrderModel> getOrdersForDriver(UserAccount driver) {
    return _orders.where((o) => o.assignedDriver == driver.name).toList();
  }

  List<Customer> getCustomersForDriver(UserAccount driver) {
    return _customers.where((c) => c.assignedDriver == driver.name).toList();
  }

  List<Customer> searchCustomers(String query) {
    if (query.isEmpty) return _customers;
    return _customers.where((c) =>
        c.name.toLowerCase().contains(query.toLowerCase()) ||
        c.phone.contains(query) ||
        c.area.toLowerCase().contains(query.toLowerCase())).toList();
  }

  int dailyCash(DateTime date) {
    return _payments.where((p) {
      final paymentDate = p.paymentDate;
      return paymentDate.year == date.year &&
          paymentDate.month == date.month &&
          paymentDate.day == date.day;
    }).fold(0, (sum, p) => sum + p.amount);
  }

  List<OrderModel> ordersForMonth(DateTime month) {
    return _orders.where((o) {
      final orderDate = o.orderDate;
      return orderDate.year == month.year && orderDate.month == month.month;
    }).toList();
  }

  int totalPaidForMonth(DateTime month) {
    return _payments.where((p) {
      final paymentDate = p.paymentDate;
      return paymentDate.year == month.year && paymentDate.month == month.month;
    }).fold(0, (sum, p) => sum + p.amount);
  }

  Future<bool> markReturnedBottles(String customerId, int count) async {
    try {
      final customer = getCustomerById(customerId);
      if (customer != null) {
        final updatedCustomer = customer.copyWith(
          bottlesReturned: customer.bottlesReturned + count,
        );
        await updateCustomer(updatedCustomer);
        return true;
      }
      return false;
    } catch (e) {
      _setError('Failed to mark returned bottles: $e');
      return false;
    }
  }

  Future<bool> receivePayment(String orderId, int amount, String collectedBy) async {
    try {
      // Find the order to get its details
      final order = _orders.firstWhere((o) => o.id == orderId);
      
      await FirebaseService.createPaymentWithOrder(
        orderId: orderId,
        amount: amount,
        paymentMethod: 'Cash',
        customerId: order.customerId,
        quantity: order.quantity,
        price: order.price + (order.salesTax ?? 0),
        collectedBy: collectedBy,
        notes: 'Payment received via cash collection',
        customerName: order.customerName,
      );
      return true;
    } catch (e) {
      _setError('Failed to receive payment: $e');
      return false;
    }
  }

}

/// ======== MAIN APP ========

class WaterDeliveryApp extends StatelessWidget {
  const WaterDeliveryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Water Delivery Management',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: primaryColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
          ),
        ),
        ),
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// ======== SPLASH SCREEN ========

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToAuth();
  }

  Future<void> _navigateToAuth() async {
    await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
      Navigator.pushReplacement(
        context,
          MaterialPageRoute(builder: (_) => const AuthScreen()),
        );
      }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, primaryDark],
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
              Icon(
                Icons.water_drop,
                size: 80,
                color: Colors.white,
              ),
            SizedBox(height: 24),
            Text(
                'Water Delivery',
              style: TextStyle(
                fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
                'Management System',
              style: TextStyle(
                fontSize: 16,
                  color: Colors.white70,
              ),
            ),
              SizedBox(height: 48),
            CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

/// ======== AUTHENTICATION SCREEN ========

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmPassCtrl = TextEditingController();
  final companyNameCtrl = TextEditingController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    confirmPassCtrl.dispose();
    companyNameCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_loginFormKey.currentState!.validate()) return;

    final appState = Provider.of<AppState>(context, listen: false);
    bool success = await appState.login(emailCtrl.text.trim(), passCtrl.text);
    if (success && mounted) {
      // Navigate to appropriate screen based on role
      Widget homeScreen;
      if (appState.isDriver) {
        homeScreen = const DriverDashboardScreen();
      } else {
        homeScreen = const DashboardScreen();
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => homeScreen),
      );
    }

    if (!success && appState.error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(appState.error!),
          backgroundColor: errorColor,
        ),
      );
    }
  }

  Future<void> _register() async {
    if (!_registerFormKey.currentState!.validate()) return;

    final appState = Provider.of<AppState>(context, listen: false);
    bool success = await appState.registerCompanyAdmin(
      email: emailCtrl.text.trim(),
      password: passCtrl.text,
      companyName: companyNameCtrl.text.trim().isEmpty ? null : companyNameCtrl.text.trim(),
    );
    
    if (success && mounted) {
      // Navigate to dashboard for newly registered admin
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    }

    if (!success && appState.error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(appState.error!),
          backgroundColor: errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
    return Scaffold(
          body: Column(
            children: [
              Expanded(
                child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [primaryColor, primaryDark],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                                // Header
                            const Icon(
                              Icons.water_drop,
                              size: 64,
                              color: primaryColor,
                            ),
                      const SizedBox(height: 16),
                      const Text(
                              'Water Delivery',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                              'Management System',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 32),
                                
                                // Tab Bar
                                TabBar(
                                  controller: _tabController,
                                  tabs: const [
                                    Tab(text: 'Login'),
                                    Tab(text: 'Register'),
                                  ],
                                  labelColor: primaryColor,
                                  unselectedLabelColor: Colors.grey,
                                  indicatorColor: primaryColor,
                                ),
                                
                                const SizedBox(height: 24),
                                
                                // Tab Content
                                SizedBox(
                                  height: 400, // Fixed height for consistent layout
                                  child: TabBarView(
                                    controller: _tabController,
                                    children: [
                                      _buildLoginForm(appState),
                                      _buildRegisterForm(appState),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _buildAuthFooter(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAuthFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F5),
        border: Border(
          top: BorderSide(
            color: Color(0xFFE0E0E0),
            width: 1,
          ),
        ),
      ),
      child: const Text(
        'Powered by RathiSoft',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          color: Color(0xFF666666),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildLoginForm(AppState appState) {
    return Form(
      key: _loginFormKey,
      child: Column(
        children: [
                            TextFormField(
                              controller: emailCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email),
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!value.contains('@')) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: passCtrl,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock),
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                              ),
                              ),
                              obscureText: _obscurePassword,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: appState.isLoading ? null : _login,
                                child: appState.isLoading
                                    ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                                    : const Text('Login'),
                              ),
                ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm(AppState appState) {
    return Form(
      key: _registerFormKey,
      child: Column(
        children: [
          TextFormField(
            controller: companyNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Company Name (Optional)',
              prefixIcon: Icon(Icons.business),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              // Company name is optional, no validation needed
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: emailCtrl,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              if (!value.contains('@')) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: passCtrl,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
            obscureText: _obscurePassword,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: confirmPassCtrl,
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              prefixIcon: const Icon(Icons.lock_outline),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
              ),
            ),
            obscureText: _obscureConfirmPassword,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your password';
              }
              if (value != passCtrl.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: appState.isLoading ? null : _register,
              child: appState.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Register as Company Admin'),
            ),
          ),
        ],
      ),
    );
  }

}

/// ======== DASHBOARD SCREENS ========

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final currentUser = appState.currentUser;
        if (currentUser == null) {
          return const AppShell(
            title: 'Dashboard',
            body: Center(child: Text('Please log in')),
          );
        }

        return AppShell(
          title: 'Dashboard',
          body: appState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : appState.error != null
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                          Icon(Icons.error, size: 64, color: errorColor),
                const SizedBox(height: 16),
                Text(
                            appState.error!,
                            style: const TextStyle(fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                        onPressed: () => appState.setupAuthListener(),
                            child: const Text('Retry'),
                ),
              ],
            ),
          )
                      : RefreshIndicator(
                  onRefresh: () => appState.setupAuthListener(),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width > 1200 ? 1200 : double.infinity,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Welcome Section
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundColor: primaryColor,
                                  child: Text(
                                    StatusUtils.getInitial(
                                        currentUser.name.isNotEmpty ? currentUser.name : currentUser.email,
                                        fallback: 'U'
                                    ),
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Welcome back, ${_getCompanyName(appState.currentUser)}!',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Times New Roman',
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${_getCurrentDay()}, ${_getCurrentDate()}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                          fontFamily: 'Times New Roman',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Today's Overview Section
                        const Text(
                          "Today's Overview",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            fontFamily: 'Times New Roman',
                          ),
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            // Determine number of columns based on screen width
                            int crossAxisCount = 2;
                            double childAspectRatio = 1.2;
                            
                            if (constraints.maxWidth < 600) {
                              // Mobile: 2 columns (2x2 grid)
                              crossAxisCount = 2;
                              childAspectRatio = 1.2;
                            } else if (constraints.maxWidth < 900) {
                              // Tablet: 2 columns
                              crossAxisCount = 2;
                              childAspectRatio = 1.5;
                            } else {
                              // Desktop: 4 columns
                              crossAxisCount = 4;
                              childAspectRatio = 1.2;
                            }
                            
                            return GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: childAspectRatio,
                              children: [
                                _buildFinancialCard(
                                  'Total Bottles Sold',
                                  '${_calculateTodayBottlesSold(appState.orders)}',
                                  Icons.local_drink,
                                  Colors.blue,
                                ),
                                _buildFinancialCard(
                                  'Cash Collected Today',
                                  'PKR ${_calculateTodayCollectedCash(appState.payments, appState.orders)}',
                                  Icons.money,
                                  Colors.green,
                                ),
                                _buildFinancialCard(
                                  'Total Balance',
                                  'PKR ${_calculateTotalBalance(appState.orders, appState.payments)}',
                                  Icons.account_balance_wallet,
                                  Colors.green,
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        // Operations Section
                        const Text(
                          'Operations',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Times New Roman',
                          ),
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            // Determine number of columns based on screen width
                            int crossAxisCount = 2;
                            double childAspectRatio = 1.2;
                            
                            if (constraints.maxWidth < 600) {
                              // Mobile: 2 columns (2x2 grid)
                              crossAxisCount = 2;
                              childAspectRatio = 1.2;
                            } else if (constraints.maxWidth < 900) {
                              // Tablet: 2 columns
                              crossAxisCount = 2;
                              childAspectRatio = 1.5;
                            } else {
                              // Desktop: 4 columns
                              crossAxisCount = 4;
                              childAspectRatio = 1.2;
                            }
                            
                            return GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: childAspectRatio,
                              children: [
                                _buildOperationCard(
                                  'Total Customers',
                                  '${appState.customers.length}',
                                  Icons.people,
                                  Colors.blue,
                                ),
                                _buildOperationCard(
                                  'Total Purchased',
                                  '${_calculateCurrentMonthBottlesSold(appState.orders)} bottles',
                                  Icons.shopping_cart,
                                  Colors.orange,
                                ),
                                _buildOperationCard(
                                  'Total Orders',
                                  '${appState.orders.length}',
                                  Icons.shopping_cart,
                                  Colors.blue,
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        // Today's Insights Section
                        const Text(
                          "Today's Insights",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Times New Roman',
                          ),
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            // Determine number of columns based on screen width
                            int crossAxisCount = 2;
                            double childAspectRatio = 1.2;
                            
                            if (constraints.maxWidth < 600) {
                              // Mobile: 2 columns - more vertical space needed
                              crossAxisCount = 2;
                              childAspectRatio = 1.2;
                            } else if (constraints.maxWidth < 900) {
                              // Tablet: 2 columns
                              crossAxisCount = 2;
                              childAspectRatio = 1.3;
                            } else {
                              // Desktop: 4 columns
                              crossAxisCount = 4;
                              childAspectRatio = 1.2;
                            }
                            
                            final routesAssigned = appState.routes.length;
                            final totalVendors = appState.vendors.length;
                            
                            return GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: childAspectRatio,
                              children: [
                                _buildInsightCard(
                                  'Routes Assigned',
                                  '$routesAssigned',
                                  Icons.map,
                                  Colors.blue,
                                  subtitle: routesAssigned > 0 ? 'Active routes' : 'No routes',
                                ),
                                _buildInsightCard(
                                  'Total Vendors',
                                  '$totalVendors',
                                  Icons.business,
                                  Colors.purple,
                                  subtitle: 'Vendors registered',
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
          ),
        );
      },
    );
  }

  Widget _buildFinancialCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon at the top
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            // Label in the middle
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Times New Roman',
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            // Value at the bottom
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                fontFamily: 'Times New Roman',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon at the top
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            // Label in the middle
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Times New Roman',
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            // Value at the bottom
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                fontFamily: 'Times New Roman',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightCard(String title, String value, IconData icon, Color color, {String? subtitle}) {
    return Card(
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Icon and Value row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(icon, color: color, size: 14),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontFamily: 'Times New Roman',
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Title and subtitle column
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Times New Roman',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 7,
                      color: Colors.grey[600],
                      fontFamily: 'Times New Roman',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getCurrentDay() {
    final now = DateTime.now();
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[now.weekday - 1];
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    final months = ['January', 'February', 'March', 'April', 'May', 'June',
                   'July', 'August', 'September', 'October', 'November', 'December'];
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  String _getCompanyName(UserAccount? currentUser) {
    if (currentUser == null) return 'Admin';
    
    // For legacy admin without companyId, show company name from email
    if (currentUser.companyId == null) {
      final emailPrefix = currentUser.email.split('@').first;
      return emailPrefix.replaceAll('.', ' ').replaceAll('_', ' ').split(' ').map((word) => 
        word.isNotEmpty ? word[0].toUpperCase() + word.substring(1).toLowerCase() : ''
      ).join(' ');
    }
    
    // For new company admins, try to get a meaningful name
    // First try to use the user's name if it's not empty
    if (currentUser.name.isNotEmpty && currentUser.name != 'Admin') {
      return currentUser.name;
    }
    
    // Otherwise, return a formatted version of their email prefix
    final emailPrefix = currentUser.email.split('@').first;
    return emailPrefix.replaceAll('.', ' ').replaceAll('_', ' ').split(' ').map((word) => 
      word.isNotEmpty ? word[0].toUpperCase() + word.substring(1).toLowerCase() : ''
    ).join(' ');
  }

  int _calculateMonthlyOutstanding(List<OrderModel> orders) {
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    final nextMonth = DateTime(now.year, now.month + 1);
    
    return orders
        .where((order) => 
            order.orderDate.isAfter(thisMonth) && 
            order.orderDate.isBefore(nextMonth) &&
            StatusUtils.normalizeStatus(order.status) != 'Delivered')
        .fold(0, (sum, order) => sum + order.price);
  }

  int _calculateMonthlyBilled(List<OrderModel> orders) {
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    final nextMonth = DateTime(now.year, now.month + 1);
    
    return orders
        .where((order) => 
            order.orderDate.isAfter(thisMonth) && 
            order.orderDate.isBefore(nextMonth))
        .fold(0, (sum, order) => sum + order.price);
  }

  int _calculateMonthlyCollected(List<Payment> payments) {
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    final nextMonth = DateTime(now.year, now.month + 1);
    
    return payments
        .where((payment) => 
            payment.paymentDate.isAfter(thisMonth) && 
            payment.paymentDate.isBefore(nextMonth))
        .fold(0, (sum, payment) => sum + payment.amount);
  }

  int _calculateTodayCash(List<Payment> payments) {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    
    return payments
        .where((payment) => 
            payment.paymentDate.isAfter(todayStart) && 
            payment.paymentDate.isBefore(todayEnd) &&
            payment.paymentMethod.toLowerCase().contains('cash'))
        .fold(0, (sum, payment) => sum + payment.amount);
  }



  // Today's Overview Calculation Methods

  int _calculateTodayCollectedCash(List<Payment> payments, List<OrderModel> orders) {
    // Cash Collected Today = Total value of orders delivered TODAY (including sales tax)
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    
    return orders
        .where((order) => 
            StatusUtils.normalizeStatus(order.status) == 'Delivered' &&
            order.orderDate.isAfter(todayStart) &&
            order.orderDate.isBefore(todayEnd))
        .fold(0, (sum, order) => sum + ((order.price + (order.salesTax ?? 0)) * order.quantity));
  }

  int _calculateTotalBalance(List<OrderModel> orders, List<Payment> payments) {
    // Total balance = total value of all delivered orders (including sales tax)
    // This represents the total business value generated
    return orders
        .where((order) => StatusUtils.normalizeStatus(order.status) == 'Delivered')
        .fold(0, (sum, order) => sum + ((order.price + (order.salesTax ?? 0)) * order.quantity));
  }


  // New calculation methods for updated UI
  int _calculateCurrentMonthBottlesSold(List<OrderModel> orders) {
    final now = DateTime.now();
    final thisMonthStart = DateTime(now.year, now.month, 1);
    final nextMonthStart = DateTime(now.year, now.month + 1, 1);
    
    return orders
        .where((order) => 
            (order.orderDate.isAtSameMomentAs(thisMonthStart) ||
             order.orderDate.isAfter(thisMonthStart)) &&
            order.orderDate.isBefore(nextMonthStart) &&
            StatusUtils.normalizeStatus(order.status) == 'Delivered')
        .fold(0, (sum, order) => sum + order.quantity);
  }

  int _calculateTodayBottlesSold(List<OrderModel> orders) {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    
    return orders
        .where((order) => 
            StatusUtils.normalizeStatus(order.status) == 'Delivered' &&
            order.orderDate.isAfter(todayStart) &&
            order.orderDate.isBefore(todayEnd))
        .fold(0, (sum, order) => sum + order.quantity);
  }

  int _calculateTotalPurchased(List<OrderModel> orders) {
    // Total purchased = sum of all orders (pending + in transit + delivered) including sales tax
    return orders.fold(0, (sum, order) => sum + ((order.price + (order.salesTax ?? 0)) * order.quantity));
  }

  int _calculatePendingPayments(List<OrderModel> orders, List<Payment> payments) {
    // Calculate total pending payments = total order value - total payments collected
    final deliveredOrders = orders.where((o) => 
      StatusUtils.normalizeStatus(o.status) == 'Delivered').toList();
    
    final totalOrderValue = deliveredOrders.fold<int>(
      0, 
      (sum, order) => sum + ((order.price + (order.salesTax ?? 0)) * order.quantity)
    );
    
    final totalPayments = payments.fold<int>(
      0, 
      (sum, payment) => sum + payment.amount
    );
    
    final pending = totalOrderValue - totalPayments;
    return pending > 0 ? pending : 0;
  }
}

/// ======== SCREEN CLASSES ========


class DriverDashboardScreen extends StatelessWidget {
  const DriverDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final currentUser = appState.currentUser;
        if (currentUser == null) {
          return const AppShell(
            title: 'Driver Dashboard',
            body: Center(child: Text('Please log in')),
          );
        }

        // Get driver's assigned customers
        final driverCustomers = appState.customers.where((c) => c.assignedDriver == currentUser.name).toList();
        
        // Get driver's assigned orders (same logic as My Deliveries screen)
        final allDriverOrders = appState.orders.where((order) {
          final customer = appState.customers.firstWhere(
            (c) => c.id == order.customerId,
            orElse: () => Customer(
              id: '',
              name: '',
              phone: '',
              address: '',
              area: '',
              product: '',
              numberOfBottles: 0,
              daysAssigned: [],
              paymentMode: 'Cash',
              bottleRate: 0,
              bottleDeposit: 0,
              lastDelivery: DateTime.now(),
              assignedDriver: null,
              createdAt: PakistanTime.now(),
            ),
          );
          return customer.assignedDriver == currentUser.name || order.assignedDriver == currentUser.name;
        }).toList();

        // Get today's pending and in-transit orders
        final today = DateTime.now();
        final startOfDay = DateTime(today.year, today.month, today.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));
        
        
        // Get today's weekday
        final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
        final todayWeekday = weekdays[today.weekday - 1];
        
        // Check if driver has any routes assigned
        final driverRoutes = appState.routes.values.where((route) => 
          route.assignedDriver == currentUser.name
        ).toList();
        
        List<OrderModel> todayOrders = [];
        
        if (driverRoutes.isNotEmpty) {
          // Show orders for today's specific day when routes are assigned
          todayOrders = allDriverOrders.where((order) {
            final status = StatusUtils.normalizeStatus(order.status);
            final isPending = (status == 'Pending');
            
            // Get the customer to check their assigned days
            final customer = appState.customers.firstWhere(
              (c) => c.id == order.customerId,
              orElse: () => Customer(
                id: '',
                name: '',
                phone: '',
                address: '',
                area: '',
                product: '',
                numberOfBottles: 0,
                daysAssigned: [],
                paymentMode: 'Cash',
                bottleRate: 0,
                bottleDeposit: 0,
                lastDelivery: DateTime.now(),
                assignedDriver: null,
                createdAt: PakistanTime.now(),
              ),
            );
            
            // Check if customer is assigned to today's weekday
            final isAssignedForToday = customer.daysAssigned.contains(todayWeekday);
            
            // Show pending orders only for customers assigned to today's weekday
            final shouldShow = isPending && isAssignedForToday;
            
            
            return shouldShow;
          }).toList();
        } else {
          // No routes assigned - show nothing
          todayOrders = [];
        }
        

        return AppShell(
          title: 'Driver Dashboard',
          body: RefreshIndicator(
            onRefresh: () async {
              await appState.setupAuthListener();
            },
            child: SingleChildScrollView(
              padding: ResponsiveHelper.getResponsivePadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Card
                  Card(
                    color: primaryColor.withOpacity(0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, ${currentUser.name}!',
                            style: TextStyle(
                              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 24),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 8)),
                          Text(
                            'Today\'s Deliveries - $todayWeekday',
                            style: TextStyle(
                              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 16)),

                  // Today's Deliveries
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Today\'s Deliveries',
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, 20),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Chip(
                        label: Text('${todayOrders.length} deliveries'),
                        backgroundColor: primaryColor.withOpacity(0.2),
                        avatar: Icon(Icons.local_shipping, size: 18, color: primaryColor),
                      ),
                    ],
                  ),
                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 8)),

                  if (todayOrders.isEmpty)
                    Card(
                      child: Padding(
                        padding: ResponsiveHelper.getResponsivePadding(context),
                        child: Column(
                          children: [
                            Icon(Icons.check_circle_outline, size: ResponsiveHelper.getResponsiveIconSize(context, 64), color: Colors.grey[400]),
                            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 16)),
                            Text(
                              'No deliveries found',
                              style: TextStyle(
                                fontSize: ResponsiveHelper.getResponsiveFontSize(context, 18),
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...todayOrders.map((order) {
                      final customer = appState.customers.firstWhere(
                        (c) => c.id == order.customerId,
                        orElse: () => Customer(
                          id: '',
                          name: 'Unknown',
                          phone: '',
                          address: '',
                          area: '',
                          product: '',
                          numberOfBottles: 0,
                          daysAssigned: [],
                          paymentMode: 'Cash',
                          bottleRate: 0,
                          bottleDeposit: 0,
                          lastDelivery: DateTime.now(),
                          assignedDriver: null,
                          createdAt: PakistanTime.now(),
                        ),
                      );

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: primaryColor,
                                    child: Text(
                                      StatusUtils.getInitial(customer.name, fallback: 'C'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          customer.name,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          customer.address,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (customer.area.isNotEmpty)
                                          Text(
                                            customer.area,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      );
                    }),
                  
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDeliveryCompletionDialog(BuildContext context, OrderModel order, AppState appState) {
    String selectedPaymentMethod = 'Cash';
    String bankName = '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Complete Delivery'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please select the payment method:'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedPaymentMethod,
                decoration: const InputDecoration(labelText: 'Payment Method'),
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'Easypaisa/Jazzcash', child: Text('Easypaisa/Jazzcash')),
                  DropdownMenuItem(value: 'Bank Account', child: Text('Bank Account')),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedPaymentMethod = value!;
                  });
                },
              ),
              if (selectedPaymentMethod == 'Bank Account') ...[
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(labelText: 'Bank Name'),
                  onChanged: (value) => bankName = value,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Validate bank name if Bank Account is selected
                if (selectedPaymentMethod == 'Bank Account' && bankName.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter bank name for bank account payment'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Close payment method dialog
                Navigator.pop(context);
                
                // Show payment amount dialog immediately
                _showPaymentAmountDialog(context, order, appState, selectedPaymentMethod, bankName);
              },
              child: const Text('Next'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPaymentAmountDialog(BuildContext context, OrderModel order, AppState appState, String selectedPaymentMethod, String bankName) async {
    final paymentAmountController = TextEditingController();
    final orderTotal = (order.price + (order.salesTax ?? 0)) * order.quantity;
    
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent auto-close on outside tap
      builder: (context) => AlertDialog(
        title: const Text('Payment Amount'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue[600], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Order Total: Rs. $orderTotal',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: paymentAmountController,
              decoration: InputDecoration(
                labelText: 'Amount Customer is Paying (Rs.)',
                hintText: 'Enter amount customer is paying now',
                helperText: 'Remaining amount will be added to customer credit',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.attach_money),
              ),
              keyboardType: TextInputType.number,
              autofocus: true, // Auto-focus on the input field
              onChanged: (value) {
                // Update UI when text changes
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amountText = paymentAmountController.text.trim();
              if (amountText.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter the payment amount'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 3),
                  ),
                );
                return;
              }

              final paymentAmount = int.tryParse(amountText);
              if (paymentAmount == null || paymentAmount < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid payment amount'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 3),
                  ),
                );
                return;
              }

              Navigator.pop(context);
              await _completeDeliveryWithAmount(context, order, appState, selectedPaymentMethod, bankName, paymentAmount, orderTotal);
            },
            child: const Text('Complete Delivery'),
          ),
        ],
      ),
    );
  }

  Future<void> _completeDeliveryWithAmount(BuildContext context, OrderModel order, AppState appState, String selectedPaymentMethod, String bankName, int paymentAmount, int orderTotal) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
                
                // Show loading indicator
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 16),
                        Text('Completing delivery...'),
                      ],
                    ),
                    duration: Duration(seconds: 2),
                  ),
                );

                try {
                  // Validate bank name if Bank Account is selected
                  if (selectedPaymentMethod == 'Bank Account' && bankName.trim().isEmpty) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Please enter bank name for bank account payment'),
            backgroundColor: Colors.red,
          ),
                    );
                    return;
                  }

      // Update order status to delivered
      await FirebaseService.updateOrderStatus(order.id, 'Delivered');
                  
      // Create payment record with the actual amount paid
                  await FirebaseService.createPaymentWithOrder(
                    orderId: order.id,
        amount: paymentAmount, // Use actual amount paid, not total
        paymentMethod: selectedPaymentMethod,
                    customerId: order.customerId,
                    quantity: order.quantity,
        price: order.price + (order.salesTax ?? 0),
                    collectedBy: appState.currentUser?.name,
        notes: 'Payment collected via $selectedPaymentMethod${bankName.isNotEmpty ? ' ($bankName)' : ''}',
      );

      // If payment amount is less than order total, create a credit record
      if (paymentAmount < orderTotal) {
        final remainingAmount = orderTotal - paymentAmount;
        await FirebaseService.createPaymentWithOrder(
          orderId: order.id,
          amount: -remainingAmount, // Negative amount for credit
          paymentMethod: 'Credit',
          customerId: order.customerId,
          quantity: order.quantity,
          price: order.price + (order.salesTax ?? 0),
          collectedBy: 'System',
          notes: 'Credit balance - remaining amount from order',
          customerName: order.customerName,
        );
      }

      // Refresh data
                  await appState.setupAuthListener();
                  
      if (context.mounted) {
                  scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(paymentAmount >= orderTotal 
                ? 'Delivery completed successfully!' 
                : 'Delivery completed! Rs. ${orderTotal - paymentAmount} added to customer credit.'),
                      backgroundColor: Colors.green,
                    ),
                  );
      }
                } catch (e) {
      if (context.mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
            content: Text('Error completing delivery: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
    }
  }

}

/// ======== APP SHELL ========

class AppShell extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? floatingActionButton;
  final List<Widget>? actions;

  const AppShell({
    super.key,
    required this.title,
    required this.body,
    this.floatingActionButton,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              title,
              style: TextStyle(
                fontSize: ResponsiveHelper.getResponsiveFontSize(context, 20),
              ),
            ),
            actions: actions,
            elevation: 0,
            toolbarHeight: ResponsiveHelper.isMobile(context) ? 56 : 64,
          ),
          drawer: ResponsiveHelper.isMobile(context) ? _buildDrawer(context, appState) : null,
          endDrawer: ResponsiveHelper.isTablet(context) || ResponsiveHelper.isDesktop(context) || ResponsiveHelper.isLargeDesktop(context) 
              ? _buildDrawer(context, appState) 
              : null,
          body: ResponsiveContainer(
            child: Column(
              children: [
                Expanded(child: body),
                _buildFooter(context),
              ],
            ),
          ),
          floatingActionButton: floatingActionButton,
        );
      },
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: ResponsiveHelper.getResponsiveSpacing(context, 12),
        horizontal: ResponsiveHelper.getResponsiveSpacing(context, 16),
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F5),
        border: Border(
          top: BorderSide(
            color: Color(0xFFE0E0E0),
            width: 1,
          ),
        ),
      ),
      child: Text(
        'Powered by RathiSoft',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: ResponsiveHelper.getResponsiveFontSize(context, 12),
          color: const Color(0xFF666666),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Drawer _buildDrawer(BuildContext context, AppState appState) {
    return Drawer(
      width: ResponsiveHelper.isMobile(context) 
          ? null 
          : ResponsiveHelper.isTablet(context) 
              ? 280 
              : ResponsiveHelper.isDesktop(context) 
                  ? 320 
                  : 360,
      child: SafeArea(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [primaryColor, primaryDark],
                ),
              ),
              accountName: Text(
                appState.currentUser?.name ?? 'User',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
                ),
              ),
              accountEmail: Text(
                appState.currentUser?.email ?? '',
                style: TextStyle(
                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                ),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: accentColor,
                radius: ResponsiveHelper.getResponsiveIconSize(context, 20),
                child: Text(
                  StatusUtils.getInitial(
                    appState.currentUser?.name,
                    fallback: (appState.currentUser?.email != null && appState.currentUser!.email.isNotEmpty)
                        ? StatusUtils.getInitial(appState.currentUser!.email, fallback: 'U')
                        : 'U'
                  ),
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, 20),
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              otherAccountsPictures: [
                Container(
                  padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, 4)),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context, 16)),
                  ),
                  child: Text(
                    appState.currentUser?.role.toUpperCase() ?? '',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, 10),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  if (appState.isAdmin || appState.isDriver)
                    _drawerItem(context, Icons.dashboard, 'Dashboard', _getHomeScreen(appState)),
                  if (appState.isDriver)
                    _drawerItem(context, Icons.local_shipping, 'My Deliveries', const DriverOrdersScreen()),
                  if (appState.isAdmin)
                    _drawerItem(context, Icons.people, 'Customers', const CustomersScreen()),
                  if (appState.isDriver)
                    _drawerItem(context, Icons.people_outline, 'My Customers', const DriverCustomersScreen()),
                  if (appState.isAdmin)
                    _drawerItem(context, Icons.badge, 'Employees', const EmployeesScreen()),
                  if (appState.isAdmin)
                    _drawerItem(context, Icons.inventory, 'Products', const ProductsScreen()),
                  if (appState.isAdmin)
                    _drawerItem(context, Icons.business, 'Vendors', const VendorsScreen()),
                  if (appState.isAdmin)
                    _drawerItem(context, Icons.account_balance_wallet, 'Revenue', const RevenueScreen()),
                  if (appState.isAdmin)
                    _drawerItem(context, Icons.map, 'Routes', const RoutesScreen()),
                  if (appState.isDriver)
                    _drawerItem(context, Icons.route, 'My Route', const DriverRouteScreen()),
                  if (appState.isDriver)
                    _drawerItem(context, Icons.inventory, 'Vendors', const DriverVendorsScreen()),
                  const Divider(),
                  _drawerItem(context, Icons.settings, 'Settings', const SettingsScreen()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getHomeScreen(AppState appState) {
    if (appState.isDriver) {
      return const DriverDashboardScreen();
    } else {
      return const DashboardScreen();
    }
  }

  ListTile _drawerItem(BuildContext context, IconData icon, String text, Widget screen) {
    return ListTile(
      leading: Icon(
        icon, 
        color: primaryColor,
        size: ResponsiveHelper.getResponsiveIconSize(context, 24),
      ),
      title: Text(
        text, 
        style: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => screen));
      },
    );
  }
}

/// ======== UTILITY FUNCTIONS ========

class StatusUtils {
  // Helper function to safely get first character of a string for avatars
  static String getInitial(String? name, {String fallback = 'U'}) {
    if (name == null || name.isEmpty) return fallback;
    return name[0].toUpperCase();
  }
  
  // Helper function to normalize status values for consistency
  static String normalizeStatus(String status) {
    // Handle different possible formats and return standardized capitalized values
    String normalized = status.toLowerCase().trim();
    
    if (normalized == 'pending') return 'Pending';
    if (normalized == 'delivered') return 'Delivered';
    
    // If already properly capitalized, return as is
    if (status == 'Pending' || status == 'Delivered') {
      return status;
    }
    
    // Default fallback - capitalize first letter
    return normalized.isNotEmpty ? normalized[0].toUpperCase() + normalized.substring(1) : status;
  }
}

/// ======== PLACEHOLDER SCREENS ========

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String _selectedFilter = 'Pending'; // Default to showing pending orders

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return AppShell(
          title: 'Orders',
          body: Column(
            children: [
              // Filter tabs
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildFilterTab('Pending', Colors.orange, _getFilterCount(appState.orders, 'Pending')),
                    ),
                    Expanded(
                      child: _buildFilterTab('Delivered', Colors.green, _getFilterCount(appState.orders, 'Delivered')),
                    ),
                    Expanded(
                      child: _buildFilterTab('Unassigned', Colors.red, _getUnassignedCount(appState.orders)),
                    ),
                    Expanded(
                      child: _buildFilterTab('Auto Orders', Colors.purple, appState.autoOrders.length),
                    ),
                  ],
                ),
              ),
              // Orders List
              Expanded(
                child: _selectedFilter == 'Auto Orders'
                    ? const AutoOrdersScreen()
                    : _buildGroupedOrdersList(appState),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending': return Colors.orange;
      case 'Delivered': return Colors.green;
      default: return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildDriverLoadCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }


  void _showPaymentMethodDialog(BuildContext context, OrderModel order, String newStatus) {
    String selectedPaymentMethod = 'Cash';
    String bankName = '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Complete Delivery'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please select the payment method:'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedPaymentMethod,
                decoration: const InputDecoration(labelText: 'Payment Method'),
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'Easypaisa/Jazzcash', child: Text('Easypaisa/Jazzcash')),
                  DropdownMenuItem(value: 'Bank Account', child: Text('Bank Account')),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedPaymentMethod = value!;
                  });
                },
              ),
              if (selectedPaymentMethod == 'Bank Account') ...[
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(labelText: 'Bank Name'),
                  onChanged: (value) => bankName = value,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Validate bank name if Bank Account is selected
                if (selectedPaymentMethod == 'Bank Account' && bankName.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter bank name for bank account payment'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Close payment method dialog immediately
                Navigator.pop(context);
                
                // Show payment amount dialog with proper delay for Flutter web
                // Use a more reliable approach - schedule the next dialog on the next frame
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  try {
                    // Get the app state from the current context
                    final appState = Provider.of<AppState>(context, listen: false);
                    _showPaymentAmountDialog(context, order, appState, selectedPaymentMethod, bankName);
                  } catch (e) {
                    // Fallback: complete delivery without payment dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Payment dialog failed, completing delivery with full payment: $e'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    // Complete delivery with full payment as fallback
                    final orderTotal = (order.price + (order.salesTax ?? 0)) * order.quantity;
                    FirebaseService.updateOrderStatus(order.id, 'Delivered').then((_) {
                      return FirebaseService.createPaymentWithOrder(
                        orderId: order.id,
                        amount: orderTotal,
                        paymentMethod: selectedPaymentMethod,
                        customerId: order.customerId,
                        quantity: order.quantity,
                        price: order.price + (order.salesTax ?? 0),
                        collectedBy: Provider.of<AppState>(context, listen: false).currentUser?.name,
                        notes: 'Payment collected via $selectedPaymentMethod${bankName.isNotEmpty ? ' ($bankName)' : ''} (Full payment - dialog failed)',
                        customerName: order.customerName,
                      );
                    }).then((_) {
                      return Provider.of<AppState>(context, listen: false).setupAuthListener();
                    }).then((_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Delivery completed with full payment!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }).catchError((error) {
                    });
                  }
                });
              },
              child: const Text('Next'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPaymentAmountDialog(BuildContext context, OrderModel order, AppState appState, String selectedPaymentMethod, String bankName) async {
    final paymentAmountController = TextEditingController();
    final orderTotal = (order.price + (order.salesTax ?? 0)) * order.quantity;
    
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent auto-close on outside tap
      builder: (context) => AlertDialog(
        title: const Text('Payment Amount'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue[600], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Order Total: Rs. $orderTotal',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: paymentAmountController,
              decoration: InputDecoration(
                labelText: 'Amount Customer is Paying (Rs.)',
                hintText: 'Enter amount customer is paying now',
                helperText: 'Remaining amount will be added to customer credit',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.attach_money),
              ),
              keyboardType: TextInputType.number,
              autofocus: true, // Auto-focus on the input field
              onChanged: (value) {
                // Update UI when text changes
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amountText = paymentAmountController.text.trim();
              if (amountText.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter the payment amount'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 3),
                  ),
                );
                return;
              }

              final paymentAmount = int.tryParse(amountText);
              if (paymentAmount == null || paymentAmount < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid payment amount'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 3),
                  ),
                );
                return;
              }

              if (paymentAmount > orderTotal) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Payment amount cannot exceed order total'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 3),
                  ),
                );
                return;
              }

              Navigator.pop(context);
              await _completeDeliveryWithAmount(context, order, appState, selectedPaymentMethod, bankName, paymentAmount, orderTotal);
            },
            child: const Text('Complete Delivery'),
          ),
        ],
      ),
    );
  }

  Future<void> _completeDeliveryWithAmount(BuildContext context, OrderModel order, AppState appState, String selectedPaymentMethod, String bankName, int paymentAmount, int orderTotal) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
                
                // Show loading indicator
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 16),
                        Text('Completing delivery...'),
                      ],
                    ),
                    duration: Duration(seconds: 2),
                  ),
                );

                try {
                  // Validate bank name if Bank Account is selected
                  if (selectedPaymentMethod == 'Bank Account' && bankName.trim().isEmpty) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Please enter bank name for bank account payment'),
            backgroundColor: Colors.red,
          ),
                    );
                    return;
                  }

      // Update order status to delivered
      await FirebaseService.updateOrderStatus(order.id, 'Delivered');
                  
      // Create payment record with the actual amount paid
                  await FirebaseService.createPaymentWithOrder(
                    orderId: order.id,
        amount: paymentAmount, // Use actual amount paid, not total
        paymentMethod: selectedPaymentMethod,
                    customerId: order.customerId,
                    quantity: order.quantity,
        price: order.price + (order.salesTax ?? 0),
                    collectedBy: appState.currentUser?.name,
        notes: 'Payment collected via $selectedPaymentMethod${bankName.isNotEmpty ? ' ($bankName)' : ''}',
      );

      // If payment amount is less than order total, create a credit record
      if (paymentAmount < orderTotal) {
        final remainingAmount = orderTotal - paymentAmount;
        await FirebaseService.createPaymentWithOrder(
          orderId: order.id,
          amount: -remainingAmount, // Negative amount for credit
          paymentMethod: 'Credit',
          customerId: order.customerId,
          quantity: order.quantity,
          price: order.price + (order.salesTax ?? 0),
          collectedBy: 'System',
          notes: 'Credit balance - remaining amount from order',
          customerName: order.customerName,
        );
      }

      // Refresh data
                  await appState.setupAuthListener();
                  
      if (context.mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(paymentAmount >= orderTotal 
                          ? 'Delivery completed successfully!' 
                          : 'Delivery completed! Rs. ${orderTotal - paymentAmount} added to customer credit.'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
                } catch (e) {
                  if (context.mounted) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Error completing delivery: $e'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                }
  }


  List<OrderModel> _getFilteredOrders(List<OrderModel> allOrders) {
    switch (_selectedFilter) {
      case 'Pending':
        return allOrders.where((order) => StatusUtils.normalizeStatus(order.status) == 'Pending').toList();
      case 'Delivered':
        return allOrders.where((order) => StatusUtils.normalizeStatus(order.status) == 'Delivered').toList();
      case 'Unassigned':
        return allOrders.where((order) => order.assignedDriver == null || order.assignedDriver!.isEmpty).toList();
      default:
        return allOrders;
    }
  }

  int _getFilterCount(List<OrderModel> allOrders, String status) {
    return allOrders.where((order) => StatusUtils.normalizeStatus(order.status) == status).length;
  }

  int _getUnassignedCount(List<OrderModel> allOrders) {
    return allOrders.where((order) => order.assignedDriver == null || order.assignedDriver!.isEmpty).length;
  }

  Widget _buildFilterTab(String filter, Color color, int count) {
    final isSelected = _selectedFilter == filter;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filter;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              filter,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white : color,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '($count)',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white : color.withOpacity(0.7),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build grouped orders list with date grouping
  Widget _buildGroupedOrdersList(AppState appState) {
    final filteredOrders = _getFilteredOrders(appState.orders);
    final groupedOrders = DateGroupingUtils.groupItemsByDate(
      filteredOrders,
      (order) => order.createdAt,
    );
    
    return ListView.builder(
      itemCount: DateGroupingUtils.getOrderedGroups().length,
      cacheExtent: 500,
      itemBuilder: (context, groupIndex) {
        final group = DateGroupingUtils.getOrderedGroups()[groupIndex];
        final ordersInGroup = groupedOrders[group]!;
        
        if (ordersInGroup.isEmpty) {
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
                '${DateGroupingUtils.getDateGroupTitle(group)} (${ordersInGroup.length})',
                style: TextStyle(
                  color: DateGroupingUtils.getDateGroupColor(group),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            // Orders in this group
            ...ordersInGroup.map((order) => _buildOrderCard(order, appState)),
          ],
        );
      },
    );
  }

  // Build individual order card
  Widget _buildOrderCard(OrderModel order, AppState appState) {
    final customer = appState.customers.firstWhere(
      (c) => c.id == order.customerId,
      orElse: () => Customer(
        id: 'unknown',
        name: 'Unknown Customer',
        phone: '',
        address: '',
        area: '',
        product: '',
        numberOfBottles: 0,
        daysAssigned: [],
        paymentMode: 'Cash',
        bottleRate: 0,
        bottleDeposit: 0,
        lastDelivery: DateTime.now(),
        assignedDriver: '',
        createdAt: PakistanTime.now(),
      ),
    );
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Order #${order.id.substring(order.id.length - 6)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (order.assignedDriver == null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Unassigned',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order.status),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    order.status,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Customer Info
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: primaryColor.withOpacity(0.1),
                  radius: 20,
                  child: Text(
                    StatusUtils.getInitial(customer.name, fallback: 'C'),
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        customer.area,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Order Details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildDetailItem('Quantity', '${order.quantity} bottles', Icons.local_drink),
                      _buildDetailItem('Price', 'Rs. ${(order.price + (order.salesTax ?? 0)) * order.quantity}', Icons.attach_money),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildDetailItem('Date', DateGroupingUtils.formatDate(order.orderDate), Icons.calendar_today),
                      _buildDetailItem(
                        'Driver', 
                        order.assignedDriver ?? 'Unassigned', 
                        order.assignedDriver != null ? Icons.person : Icons.person_off,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Payment Method and Credit Info (if delivered)
            if (StatusUtils.normalizeStatus(order.status) == 'Delivered') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.payment, color: Colors.green[600], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Payment: ${order.paymentMethod ?? 'Not specified'}',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Credit Information
              FutureBuilder<int>(
                future: _calculateOrderCredit(order.id, appState),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data! > 0) {
                    return Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.account_balance_wallet, color: Colors.orange[600], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Credit Due: Rs. ${snapshot.data}',
                              style: TextStyle(
                                color: Colors.orange[700],
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
            
            // Payment Collected Info (if delivered)
            if (StatusUtils.normalizeStatus(order.status) == 'Delivered' && order.paymentMethod != null) ...[
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
                    Icon(Icons.receipt, color: Colors.blue[600], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Payment collected via ${order.paymentMethod}',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Update Status Dropdown (for admin only)
            if (appState.isAdmin) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    'Update Status:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: StatusUtils.normalizeStatus(order.status),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: ['Pending', 'Delivered'].map((status) {
                        return DropdownMenuItem(
                          value: status,
                          child: Text(status),
                        );
                      }).toList(),
                      onChanged: (newStatus) async {
                        if (newStatus != null && newStatus != order.status) {
                          try {
                            await appState.updateOrderStatus(order.id, newStatus);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Order status updated to $newStatus'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error updating order status: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Helper method to calculate credit amount for an order
  Future<int> _calculateOrderCredit(String orderId, AppState appState) async {
    try {
      // Get all payments for this order
      final orderPayments = appState.payments.where((payment) => payment.orderId == orderId).toList();
      
      if (orderPayments.isEmpty) {
        return 0; // No payments found
      }
      
      // Get the order to calculate total amount
      final order = appState.orders.firstWhere((o) => o.id == orderId);
      final orderTotal = (order.price + (order.salesTax ?? 0)) * order.quantity;
      
      // Calculate total paid amount (positive payments only)
      final totalPaid = orderPayments
          .where((payment) => payment.amount > 0)
          .fold<int>(0, (sum, payment) => sum + payment.amount);
      
      // Calculate credit amount
      final creditAmount = orderTotal - totalPaid;
      
      return creditAmount > 0 ? creditAmount : 0;
    } catch (e) {
      return 0; // Return 0 if there's an error
    }
  }
}

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedDayFilter = 'All'; // Default to show all customers
  final List<String> _dayFilters = [
    'All',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        // Filter customers based on search query and day filter, then sort by creation date (newest first)
        final filteredCustomers = appState.customers.where((customer) {
          // Search filter
          bool matchesSearch = true;
          if (_searchQuery.isNotEmpty) {
            matchesSearch = customer.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                 customer.phone.contains(_searchQuery) ||
                 customer.area.toLowerCase().contains(_searchQuery.toLowerCase());
          }
          
          // Day filter
          bool matchesDay = true;
          if (_selectedDayFilter != 'All') {
            matchesDay = customer.daysAssigned.any((day) => day.toLowerCase() == _selectedDayFilter.toLowerCase());
          }
          
          return matchesSearch && matchesDay;
        }).toList()
          ..sort((a, b) {
            // Handle null createdAt values - put them at the end
            if (a.createdAt == null && b.createdAt == null) return 0;
            if (a.createdAt == null) return 1;
            if (b.createdAt == null) return -1;
            // Use PakistanTime for consistent sorting (newest first)
            final pakistanDateA = PakistanTime.toPakistanTime(a.createdAt!);
            final pakistanDateB = PakistanTime.toPakistanTime(b.createdAt!);
            return pakistanDateB.compareTo(pakistanDateA);
          });

        return AppShell(
          title: 'Customers',
          body: Column(
            children: [
              // Search Bar
              Padding(
                padding: ResponsiveHelper.getResponsivePadding(context),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name, phone, or area...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              // Day Filter Dropdown
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    const Text(
                      'Filter by Day: ',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedDayFilter,
                          isExpanded: true,
                          underline: Container(),
                          items: _dayFilters.map((day) => DropdownMenuItem(
                            value: day,
                            child: Text(day),
                          )).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedDayFilter = value!;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Add Customer Button
              if (appState.isAdmin)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ElevatedButton.icon(
                    onPressed: () => _showCreateCustomerDialog(context, appState),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Add New Customer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              // Customers List
              Expanded(
                child: filteredCustomers.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isEmpty && _selectedDayFilter == 'All'
                              ? 'No customers found. Add some customers to get started.'
                              : _searchQuery.isNotEmpty && _selectedDayFilter != 'All'
                                  ? 'No customers found matching "$_searchQuery" for $_selectedDayFilter'
                                  : _searchQuery.isNotEmpty
                                      ? 'No customers found matching "$_searchQuery"'
                                      : 'No customers assigned for $_selectedDayFilter',
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : _buildGroupedCustomersList(filteredCustomers, appState),
              ),
            ],
          ),
        );
      },
    );
  }

  // Build grouped customers list with date grouping
  Widget _buildGroupedCustomersList(List<Customer> customers, AppState appState) {
    final groupedCustomers = DateGroupingUtils.groupItemsByDate(
      customers,
      (customer) => customer.createdAt ?? customer.lastDelivery,
    );
    
    return ListView.builder(
      itemCount: DateGroupingUtils.getOrderedGroups().length,
      cacheExtent: 500,
      itemBuilder: (context, groupIndex) {
        final group = DateGroupingUtils.getOrderedGroups()[groupIndex];
        final customersInGroup = groupedCustomers[group]!;
        
        if (customersInGroup.isEmpty) {
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
                '${DateGroupingUtils.getDateGroupTitle(group)} (${customersInGroup.length})',
                style: TextStyle(
                  color: DateGroupingUtils.getDateGroupColor(group),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            // Customers in this group
            ...customersInGroup.map((customer) => _buildCustomerCard(customer, appState)),
          ],
        );
      },
    );
  }

  // Format last delivery date - always show proper date, not "Today 12:12"
  String _formatLastDeliveryDate(DateTime date) {
    final pakistanDate = PakistanTime.toPakistanTime(date);
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${pakistanDate.day} ${months[pakistanDate.month - 1]} ${pakistanDate.year}';
  }

  // Build individual customer card
  Widget _buildCustomerCard(Customer customer, AppState appState) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CustomerDetailScreen(customer: customer),
            ),
          );
        },
        leading: CircleAvatar(
          backgroundColor: primaryColor,
          child: Text(
            StatusUtils.getInitial(customer.name, fallback: 'C'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Expanded(child: Text(customer.name)),
            if (customer.daysAssigned.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  customer.daysAssigned.join(', '),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Phone: ${customer.phone}'),
            Text('Area: ${customer.area}'),
            Text('Address: ${customer.address}'),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Chip(
                  label: Text('Delivered: ${appState.getCustomerDeliveredBottles(customer.id)}'),
                  backgroundColor: Colors.green[100],
                ),
                // Show legacy single driver only when not using multi-day routing
                if ((customer.daysAssigned.isEmpty || customer.daysAssigned.length < 2) &&
                    customer.assignedDriver != null && customer.assignedDriver!.isNotEmpty)
                  Chip(
                    label: Text('Driver: ${customer.assignedDriver}'),
                    backgroundColor: Colors.blue[100],
                  ),
                Chip(
                  label: Text('Rate: Rs. ${customer.bottleRate}'),
                  backgroundColor: Colors.orange[100],
                ),
              ],
            ),
            const SizedBox(height: 4),
            // For customers with 2 or more days, show per-day route driver mapping
            if (customer.daysAssigned.length >= 2) ...[
              Builder(
                builder: (context) {
                  final List<String> dayLines = [];
                  for (final day in customer.daysAssigned) {
                    // Find a route that contains this day and covers the customer's area
                    final routeForDay = appState.routes.values.firstWhere(
                      (route) => route.days.contains(day) &&
                        route.areas.any((routeArea) =>
                          routeArea.trim().toLowerCase() == customer.area.trim().toLowerCase()),
                      orElse: () => RoutePlan(days: [], areas: [], assignedDriver: null, createdAt: DateTime.now()),
                    );
                    final driverName = routeForDay.assignedDriver ?? 'Unassigned';
                    dayLines.add('$day Route: $driverName');
                  }
                  return Text(dayLines.join('  '), style: const TextStyle(fontSize: 12));
                },
              ),
              const SizedBox(height: 4),
            ],
            Text(
              'Last Delivery: ${_formatLastDeliveryDate(customer.lastDelivery)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateCustomerDialog(BuildContext context, AppState appState) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final areaController = TextEditingController();
    final driverController = TextEditingController();
    final bottleRateController = TextEditingController();
    final bottleDepositController = TextEditingController();
    final numberOfBottlesController = TextEditingController();
    List<String> selectedDaysAssigned = [];
    String selectedPaymentMode = 'Cash';
    String selectedProduct = '';

    // Ensure context is still valid before showing dialog
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent auto-close on outside tap
      builder: (context) => AlertDialog(
        title: const Text('Add New Customer'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Customer Name
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Customer Name *'),
              ),
              const SizedBox(height: 16),
              // Phone Number
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number *'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              // Address
              TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'Address *'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              // Area (Route Assigned)
              TextField(
                controller: areaController,
                decoration: const InputDecoration(labelText: 'Area (Route Assigned) *'),
              ),
              const SizedBox(height: 16),
              // Product
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Product *'),
                isExpanded: true,
                value: selectedProduct.isEmpty ? null : selectedProduct,
                items: [
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Text('Select Product'),
                  ),
                  ...appState.products.map((product) {
                    return DropdownMenuItem<String>(
                      value: product.name,
                      child: Text('${product.name} (${product.size})'),
                    );
                  }),
                ],
                onChanged: (String? newValue) {
                  selectedProduct = newValue ?? '';
                },
              ),
              const SizedBox(height: 16),
              // Days Assigned (Multi-select)
              StatefulBuilder(
                builder: (context, setState) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Days Assigned *', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
                          .map((day) => FilterChip(
                                label: Text(day),
                                selected: selectedDaysAssigned.contains(day),
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      selectedDaysAssigned.add(day);
                                    } else {
                                      selectedDaysAssigned.remove(day);
                                    }
                                  });
                                },
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Payment Mode
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Payment Mode *'),
                isExpanded: true,
                value: selectedPaymentMode,
                items: [
                  const DropdownMenuItem<String>(
                    value: 'Cash',
                    child: Text('Cash'),
                  ),
                  const DropdownMenuItem<String>(
                    value: 'Credit',
                    child: Text('Credit'),
                  ),
                ],
                onChanged: (String? newValue) {
                  selectedPaymentMode = newValue ?? 'Cash';
                },
              ),
              const SizedBox(height: 16),
              // Bottle Rate
              TextField(
                controller: bottleRateController,
                decoration: const InputDecoration(labelText: 'Bottle Rate (PKR) *'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              // Bottle Deposit
              TextField(
                controller: bottleDepositController,
                decoration: const InputDecoration(labelText: 'Bottle Deposit (PKR) *'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              // Assigned Driver (Optional)
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Assigned Driver (Optional)'),
                isExpanded: true,
                items: [
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Text('No Driver Assigned'),
                  ),
                  ...appState.employees.where((e) => e.role == 'driver').map((driver) {
                    return DropdownMenuItem<String>(
                      value: driver.name,
                      child: Text(driver.name),
                    );
                  }),
                ],
                onChanged: (String? newValue) {
                  driverController.text = newValue ?? '';
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
            onPressed: () async {
              // Validate that if a driver is assigned, they have routes
              if (driverController.text.isNotEmpty) {
                final driverHasRoutes = appState.routes.values.any((route) => 
                  route.assignedDriver == driverController.text);
                
                if (!driverHasRoutes) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${driverController.text} does not have any routes assigned. Please assign routes first.')),
                  );
                  return;
                }
              }

              // Validate required fields
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter customer name')),
                );
                return;
              }
              
              if (phoneController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter phone number')),
                );
                return;
              }
              
              if (addressController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter address')),
                );
                return;
              }
              
              if (areaController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter area')),
                );
                return;
              }

              if (selectedProduct.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please select a product')),
                );
                return;
              }


              if (selectedDaysAssigned.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please select at least one delivery day')),
                );
                return;
              }

              if (bottleRateController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter bottle rate')),
                );
                return;
              }

              if (bottleDepositController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter bottle deposit')),
                );
                return;
              }

              try {
                final customerData = {
                  'name': nameController.text,
                  'phone': phoneController.text,
                  'address': addressController.text,
                  'area': areaController.text,
                  'product': selectedProduct,
                  'numberOfBottles': 0, // Not used anymore, kept for backward compatibility
                  'daysAssigned': selectedDaysAssigned,
                  'paymentMode': selectedPaymentMode,
                  'bottleRate': int.tryParse(bottleRateController.text) ?? 0,
                  'bottleDeposit': int.tryParse(bottleDepositController.text) ?? 0,
                  'bottlesDelivered': 0,
                  'bottlesReturned': 0,
                  'lastDelivery': DateTime.now().toIso8601String(),
                  'assignedDriver': driverController.text,
                  'createdAt': DateTime.now().toIso8601String(),
                };
                
                final customerId = await FirebaseService.createCustomer(customerData);
                
                // Add the actual customer ID to the data for subsequent operations
                customerData['id'] = customerId;
                
                // Auto-assign driver based on route if no driver was manually assigned
                if (driverController.text.isEmpty && areaController.text.isNotEmpty) {
                  await _autoAssignDriverBasedOnRoute(customerData, appState);
                }
                
                // Create automatic orders for the selected days
                await _createAutomaticOrdersForCustomer(customerData, appState);
                
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Customer added successfully! Orders will be created automatically.')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // Auto-assign driver based on route
  Future<void> _autoAssignDriverBasedOnRoute(Map<String, dynamic> customerData, AppState appState) async {
    try {
      
      final area = customerData['area'];
      
      // Find routes that match this area (strict match; case-insensitive, trimmed)
      final String? customerAreaRaw = (area is String) ? area : null;
      final String? customerArea = customerAreaRaw?.trim();
      if (customerArea == null || customerArea.isEmpty) {
        return;
      }
      final matchingRoutes = appState.routes.values.where((route) {
        return route.areas.any((routeArea) =>
          routeArea.trim().toLowerCase() == customerArea.trim().toLowerCase()
        );
      }).toList();
      
      
      if (matchingRoutes.isNotEmpty) {
        // Find the first route with an assigned driver
        final routeWithDriver = matchingRoutes.firstWhere(
          (route) => route.assignedDriver != null && route.assignedDriver!.isNotEmpty,
          orElse: () => RoutePlan(days: [], areas: [], assignedDriver: null, createdAt: DateTime.now()),
        );
        
        if (routeWithDriver.assignedDriver != null && routeWithDriver.assignedDriver!.isNotEmpty) {
          final assignedDriver = routeWithDriver.assignedDriver!;
          
          // Update customer with assigned driver
          final customerId = customerData['id'];
          if (customerId != null) {
            await FirebaseService.updateCustomer(customerId, {
              'assignedDriver': assignedDriver,
              'updatedAt': DateTime.now().toIso8601String(),
            });
            
          } else {
          }
        } else {
        }
      } else {
      }
      
    } catch (e) {
      // Don't throw error to prevent customer creation from failing
    }
  }

  // Create automatic orders for customer based on selected delivery days
  Future<void> _createAutomaticOrdersForCustomer(Map<String, dynamic> customerData, AppState appState) async {
    try {
      
      final customerId = customerData['id'];
      if (customerId == null) {
        return;
      }
      
      final daysAssigned = List<String>.from(customerData['daysAssigned'] ?? []);
      final bottleRate = customerData['bottleRate'] ?? 0;
      final paymentMode = customerData['paymentMode'] ?? 'Cash';
      
      
      // Create orders for each assigned day
      for (String day in daysAssigned) {
        // Calculate next delivery date for this day
        final nextDeliveryDate = _getNextDeliveryDateForDay(day);
        
        
        // Create the order with quantity 0 (will be set by driver during delivery)
        final orderData = {
          'customerId': customerId,
          'customerName': customerData['name'],
          'quantity': 0, // Quantity will be set by driver during delivery
          'price': bottleRate,
          'salesTax': 0, // Will be calculated based on settings
          'status': 'Pending',
          'orderDate': nextDeliveryDate.toIso8601String(),
          'handledBy': appState.currentUser?.name ?? 'System',
          'notes': 'Auto-generated order for $day delivery',
          'assignedDriver': customerData['assignedDriver'],
          'paymentMethod': paymentMode,
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        };
        
        
        // Create order in Firebase
        await FirebaseService.createOrder(orderData);
        
      }
      
      
    } catch (e) {
      // Don't throw error to prevent customer creation from failing
    }
  }
  
  // Get next delivery date for a specific day of the week
  DateTime _getNextDeliveryDateForDay(String dayOfWeek) {
    final now = DateTime.now();
    final daysOfWeek = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final targetDayIndex = daysOfWeek.indexOf(dayOfWeek);
    
    if (targetDayIndex == -1) {
      return now.add(const Duration(days: 1)); // Default to tomorrow
    }
    
    final currentDayIndex = now.weekday - 1; // Convert to 0-based index
    int daysUntilTarget = (targetDayIndex - currentDayIndex) % 7;
    
    if (daysUntilTarget == 0) {
      daysUntilTarget = 7; // If it's the same day, schedule for next week
    }
    
    return now.add(Duration(days: daysUntilTarget));
  }
}

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  DateTime? _selectedAttendanceDate;
  
  // Simple in-memory tracking of salary payments (in production, this would be in Firebase)
  static Map<String, List<Map<String, dynamic>>> _salaryPayments = {};
  
  // Helper method to get company name
  String _getCompanyName(UserAccount? currentUser) {
    if (currentUser == null) return 'Admin';
    
    // For legacy admin without companyId, show company name from email
    if (currentUser.companyId == null) {
      final emailPrefix = currentUser.email.split('@').first;
      return emailPrefix.replaceAll('.', ' ').replaceAll('_', ' ').split(' ').map((word) => 
        word.isNotEmpty ? word[0].toUpperCase() + word.substring(1).toLowerCase() : ''
      ).join(' ');
    }
    
    // For new company admins, try to get a meaningful name
    // First try to use the user's name if it's not empty
    if (currentUser.name.isNotEmpty && currentUser.name != 'Admin') {
      return currentUser.name;
    }
    
    // Fallback to email prefix
    final emailPrefix = currentUser.email.split('@').first;
    return emailPrefix.replaceAll('.', ' ').replaceAll('_', ' ').split(' ').map((word) => 
      word.isNotEmpty ? word[0].toUpperCase() + word.substring(1).toLowerCase() : ''
    ).join(' ');
  }
  
  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return AppShell(
          title: 'Employees',
          body: Column(
            children: [
              // Create Employee Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ElevatedButton.icon(
                  onPressed: () => _showCreateEmployeeDialog(context, appState),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add Employee'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              
              // Employees List
              Expanded(
                child: appState.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                        ),
                      )
                    : _buildEmployeesList(appState),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmployeesList(AppState appState) {
    // Filter out admin users from the list and sort by creation date (newest first)
    final nonAdminEmployees = appState.employees.where((employee) => employee.role.toLowerCase() != 'admin').toList()
      ..sort((a, b) {
        // Use PakistanTime for consistent sorting (newest first)
        final pakistanDateA = PakistanTime.toPakistanTime(a.createdAt);
        final pakistanDateB = PakistanTime.toPakistanTime(b.createdAt);
        return pakistanDateB.compareTo(pakistanDateA);
      });
    
    return nonAdminEmployees.isEmpty
        ? const Center(
            child: Text(
              'No regular employees found. Add some employees to get started.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          )
        : ListView.builder(
            itemCount: nonAdminEmployees.length,
            cacheExtent: 500,
            itemBuilder: (context, index) {
              final employee = nonAdminEmployees[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                color: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  onTap: employee.hasLoginCredentials 
                      ? () {
                          _showDriverDetailsDialog(context, appState, employee);
                        }
                      : () {
                          _showEmployeeDetailsDialog(context, employee);
                        },
                  leading: CircleAvatar(
                    backgroundColor: _getRoleColor(employee.role),
                    child: Text(
                      StatusUtils.getInitial(employee.name, fallback: 'E'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Designation: ${employee.designation?.isNotEmpty == true ? employee.designation! : employee.role}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (employee.email.isNotEmpty) 
                        Text(
                          employee.email,
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      if (employee.phone != null && employee.phone!.isNotEmpty) 
                        Text(
                          'Phone: ${employee.phone}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Chip(
                        label: Text(employee.designation?.isNotEmpty == true ? employee.designation! : employee.role),
                        backgroundColor: _getRoleColor(employee.role),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.book, color: Colors.green),
                        onPressed: () => _showEmployeeBookDialog(context, appState, employee),
                        tooltip: 'Employee Book',
                      ),
                        IconButton(
                          icon: const Icon(Icons.info_outline, color: Colors.blue),
                        onPressed: () {
                          
                          if (employee.hasLoginCredentials) {
                            _showDriverDetailsDialog(context, appState, employee);
                          } else {
                            _showEmployeeDetailsDialog(context, employee);
                          }
                        },
                        tooltip: employee.hasLoginCredentials 
                            ? 'View Driver Details' 
                            : 'View Employee Details',
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _showDeleteEmployeeDialog(context, appState, employee),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }






  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin': return Colors.red;
      case 'driver': return Colors.blue;
      default: return Colors.grey;
    }
  }

  void _showEmployeeInfoDialog(BuildContext context, UserAccount employee) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _getRoleColor(employee.role),
                _getRoleColor(employee.role).withOpacity(0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Row(
          children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white,
              child: Text(
                  StatusUtils.getInitial(employee.name, fallback: 'E'),
                style: TextStyle(
                    color: _getRoleColor(employee.role),
                  fontWeight: FontWeight.bold,
                    fontSize: 24,
                ),
              ),
            ),
              const SizedBox(width: 16),
              Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                    Text(
                      employee.name,
                    style: const TextStyle(
                        fontSize: 22,
                      fontWeight: FontWeight.bold,
                        color: Colors.white,
                    ),
                  ),
                    const SizedBox(height: 4),
            Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                  ),
              child: Text(
                        employee.role.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
              ),
            ],
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Employee Status Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: employee.isActive ? Colors.green[50] : Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: employee.isActive ? Colors.green[200]! : Colors.red[200]!,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        employee.isActive ? Icons.check_circle : Icons.cancel,
                        color: employee.isActive ? Colors.green[600] : Colors.red[600],
                        size: 24,
                ),
                const SizedBox(width: 12),
                      Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                            employee.isActive ? 'Active Employee' : 'Inactive Employee',
                style: TextStyle(
                          fontSize: 16,
                  fontWeight: FontWeight.bold,
                              color: employee.isActive ? Colors.green[700] : Colors.red[700],
                        ),
                      ),
                      Text(
                            employee.isActive ? 'Currently working' : 'Not available',
                        style: TextStyle(
                          fontSize: 12,
                              color: employee.isActive ? Colors.green[600] : Colors.red[600],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
                ),
                
                const SizedBox(height: 20),
                
                // Contact Information Section
                _buildEmployeeSection(
                  'Contact Information',
                  Icons.contact_phone,
                  [
                    _buildEmployeeInfoRow(Icons.email, 'Email', employee.email),
                    if (employee.phone != null && employee.phone!.isNotEmpty)
                      _buildEmployeeInfoRow(Icons.phone, 'Phone', employee.phone!),
                    if (employee.address != null && employee.address!.isNotEmpty)
                      _buildEmployeeInfoRow(Icons.location_on, 'Address', employee.address!),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Employee Details Section
                _buildEmployeeSection(
                  'Employee Details',
                  Icons.person,
                  [
                    _buildEmployeeInfoRow(Icons.work, 'Designation', employee.designation?.isNotEmpty == true ? employee.designation!.toUpperCase() : employee.role.toUpperCase()),
                    _buildEmployeeInfoRow(Icons.calendar_today, 'Joined', _formatDate(employee.createdAt)),
                    _buildEmployeeInfoRow(Icons.badge, 'Employee ID', employee.uid.substring(0, 8).toUpperCase()),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Additional Information Section (if available)
                if (employee.companyId != null) ...[
                  _buildEmployeeSection(
                    'Company Information',
                    Icons.business,
                    [
                      _buildEmployeeInfoRow(Icons.business_center, 'Company ID', employee.companyId!.substring(0, 8).toUpperCase()),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
                
                // Role-specific Information
                if (employee.role.toLowerCase() == 'admin') ...[
            Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                children: [
                        Icon(
                          Icons.admin_panel_settings,
                          color: Colors.blue[600],
                          size: 32,
                  ),
                  const SizedBox(height: 8),
                Text(
                          'Administrator',
                  style: TextStyle(
                  fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                Text(
                          'Full system access and management privileges',
                          style: TextStyle(
                    fontSize: 12,
                            color: Colors.blue[600],
                  ),
                          textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
              label: const Text('Close'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
        ),
      );
    }
    
  Widget _buildInfoRow(String label, String value) {
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

  Widget _buildEmployeeSection(String title, IconData icon, List<Widget> children) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
            Icon(
              icon,
              color: Colors.blue[600],
              size: 20,
                  ),
                  const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
                Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildEmployeeInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.grey[600],
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  void _showEmployeeBookDialog(BuildContext context, AppState appState, UserAccount employee) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.green[600]!,
                Colors.green[400]!,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 35,
                backgroundColor: Colors.white,
                child: Text(
                  StatusUtils.getInitial(employee.name, fallback: 'E'),
                  style: TextStyle(
                    color: Colors.green[600],
                          fontWeight: FontWeight.bold,
                    fontSize: 28,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      Text(
                      '${employee.name}\'s Book',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        'Employee Management',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Employee Info Card
            Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                        Icon(Icons.person, color: Colors.green[600], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Employee Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
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
                                'Designation',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                              Text(
                                employee.designation?.isNotEmpty == true ? employee.designation! : employee.role,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Salary',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                              Text(
                                employee.salary?.isNotEmpty == true ? 'Rs. ${employee.salary}' : 'Not Set',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Action Buttons
              Row(
                    children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showAttendanceDialog(context, appState, employee),
                      icon: const Icon(Icons.access_time),
                      label: const Text('Attendance'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showPayrollDialog(context, appState, employee),
                      icon: const Icon(Icons.account_balance_wallet),
                      label: const Text('Payroll'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[600],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                    ],
                  ),
                ],
          ),
        ),
        actions: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
              label: const Text('Close'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 3,
              ),
              ),
            ),
          ],
      ),
    );
  }

  void _showAttendanceDialog(BuildContext context, AppState appState, UserAccount employee) {
    Navigator.of(context).pop(); // Close the employee book dialog first
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            child: Column(
              children: [
                // Header with back button and title
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.orange[600]!,
                        Colors.orange[400]!,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                          ),
                          Expanded(
                            child: Text(
                              '${employee.name}\'s Attendance',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 48), // Balance the back button
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Content
                Expanded(
                  child: _buildEmployeeAttendanceContent(context, appState, employee, setState),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeAttendanceContent(BuildContext context, AppState appState, UserAccount employee, StateSetter setState) {
    // Initialize selected date if null
    _selectedAttendanceDate ??= DateTime.now();
    
    return StreamBuilder<List<Attendance>>(
      stream: FirebaseService.getEmployeeAttendanceForMonthStream(
        employee.uid,
        _selectedAttendanceDate!.year,
        _selectedAttendanceDate!.month,
      ),
      builder: (context, snapshot) {
        // Capture attendance data for use in nested widgets
        final attendanceData = snapshot.data;
        
        // Calculate attendance stats from Firebase data
        int totalPresent = 0;
        int totalAbsent = 0;
        int totalPaidHolidays = 0;
        int totalHalfDays = 0;
        int totalOvertime = 0;
        double totalFines = 0.0;
        
        if (snapshot.hasData) {
          for (final attendance in snapshot.data!) {
            switch (attendance.status.toLowerCase()) {
              case 'present':
                totalPresent++;
                break;
              case 'absent':
                totalAbsent++;
                break;
              case 'paid holiday':
                totalPaidHolidays++;
                break;
              case 'half day':
                totalHalfDays++;
                break;
              case 'overtime':
                totalPresent++; // Overtime counts as present
                totalOvertime++;
                break;
              case 'late fine':
                totalPresent++; // Late fine counts as present
                totalFines += attendance.fineAmount ?? 0.0;
                break;
            }
          }
        }
        
        // Calculate days from employee creation date to today
        final employeeStartDate = employee.createdAt;
        final today = DateTime.now();
        final daysDifference = today.difference(employeeStartDate).inDays;
        
        return Container(
          color: Colors.grey[100],
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Employee Info Card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
      child: Row(
        children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.orange[100],
                      child: Text(
                        StatusUtils.getInitial(employee.name, fallback: 'E'),
                        style: TextStyle(
                          color: Colors.orange[600],
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                            employee.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Joined: ${_formatDateForAttendance(employeeStartDate)}',
                  style: TextStyle(
                              fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                            'Days with company: $daysDifference',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Date Selector and Stats Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Date Selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _selectedAttendanceDate = _selectedAttendanceDate!.subtract(const Duration(days: 1));
                            });
                          },
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Column(
                          children: [
                            Text(
                              _formatDateForAttendance(_selectedAttendanceDate!),
                  style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _selectedAttendanceDate = _selectedAttendanceDate!.add(const Duration(days: 1));
                            });
                          },
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Stats
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            Text(
                              '$totalPresent',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[600],
                              ),
                            ),
                            Text(
                              'Total Present',
                              style: TextStyle(
                    fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              '$totalAbsent',
                              style: TextStyle(
                                fontSize: 20,
                    fontWeight: FontWeight.bold,
                                color: Colors.red[600],
                              ),
                            ),
                            Text(
                              'Total Absent',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                ),
              ],
            ),
                      ],
          ),
        ],
      ),
              ),
              
              const SizedBox(height: 16),
              
              // Attendance Actions Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mark Attendance for ${_formatDateForAttendance(_selectedAttendanceDate!)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                    // Show current attendance status if marked
                    Builder(
                      builder: (context) {
                        // Find attendance for selected date
                        Attendance? currentAttendance;
                        if (snapshot.hasData) {
                          final selectedDateStr = '${_selectedAttendanceDate!.year}_${_selectedAttendanceDate!.month}_${_selectedAttendanceDate!.day}';
                          for (final att in snapshot.data!) {
                            final attDateStr = '${att.date.year}_${att.date.month}_${att.date.day}';
                            if (attDateStr == selectedDateStr) {
                              currentAttendance = att;
                              break;
                            }
                          }
                        }
                        
                        if (currentAttendance != null) {
                          Color statusColor;
                          IconData statusIcon;
                          String statusText = currentAttendance.status;
                          String? additionalInfo;
                          
                          switch (currentAttendance.status.toLowerCase()) {
                            case 'present':
                              statusColor = Colors.green;
                              statusIcon = Icons.check_circle;
                              break;
                            case 'absent':
                              statusColor = Colors.red;
                              statusIcon = Icons.cancel;
                              break;
                            case 'late fine':
                              statusColor = Colors.orange;
                              statusIcon = Icons.warning;
                              additionalInfo = 'Fine: Rs ${(currentAttendance.fineAmount ?? 0).toStringAsFixed(0)}';
                              break;
                            case 'overtime':
                              statusColor = Colors.blue;
                              statusIcon = Icons.access_time;
                              additionalInfo = '${(currentAttendance.overtimeHours ?? 0).toStringAsFixed(1)}h overtime';
                              break;
                            case 'half day':
                              statusColor = Colors.orange;
                              statusIcon = Icons.schedule;
                              additionalInfo = 'Half Day (${currentAttendance.notes ?? "Morning"})';
                              break;
                            case 'paid holiday':
                              statusColor = Colors.purple;
                              statusIcon = Icons.beach_access;
                              break;
                            default:
                              statusColor = Colors.grey;
                              statusIcon = Icons.circle;
                          }
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: statusColor),
                            ),
                            child: Row(
                              children: [
                                Icon(statusIcon, color: statusColor, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Currently Marked: $statusText',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: statusColor,
                                        ),
                                      ),
                                      if (additionalInfo != null)
                                        Text(
                                          additionalInfo,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      if (currentAttendance.notes != null && currentAttendance.status.toLowerCase() != 'half day')
                                        Text(
                                          currentAttendance.notes!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // Fire and forget - don't await to make it faster
                              _saveAttendance(employee, _selectedAttendanceDate!, 'Present');
                            },
                            icon: const Icon(Icons.check, color: Colors.white),
                            label: const Text('Present'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[600],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // Fire and forget - don't await to make it faster
                              _saveAttendance(employee, _selectedAttendanceDate!, 'Absent');
                            },
                            icon: const Icon(Icons.close, color: Colors.white),
                            label: const Text('Absent'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[600],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                      SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showAttendanceOptionsDialog(context, appState, employee, _selectedAttendanceDate!, snapshot.data),
                        icon: const Icon(Icons.more_horiz, color: Colors.white),
                        label: const Text('More Options'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[600],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
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
    );
  }

  Widget _buildAttendanceContent(BuildContext context, AppState appState, StateSetter setState) {
    // Filter employees (non-admin)
    final employees = appState.employees.where((emp) => emp.role.toLowerCase() != 'admin').toList();
    
    return StatefulBuilder(
      builder: (context, setState) {
        DateTime selectedDate = DateTime.now();
        int totalPresent = 0;
        int totalAbsent = 0;
        String searchQuery = '';
        
        return Container(
          color: Colors.grey[100],
          child: Column(
      children: [
              // Date Selector and Stats Card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Date Selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _selectedAttendanceDate = _selectedAttendanceDate!.subtract(const Duration(days: 1));
                            });
                          },
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Column(
                          children: [
                            Text(
                              _formatDateForAttendance(_selectedAttendanceDate!),
              style: const TextStyle(
                                fontSize: 16,
                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _selectedAttendanceDate = _selectedAttendanceDate!.add(const Duration(days: 1));
                            });
                          },
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Stats
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                        Column(
                          children: [
                            Text(
                              '$totalPresent',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[600],
                              ),
                            ),
                            Text(
                              'Total Present',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        Column(
                children: [
                            Text(
                              '$totalAbsent',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.red[600],
                              ),
                            ),
                            Text(
                              'Total Absent',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                  ),
                ],
              ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Search Bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search',
                    prefixIcon: Icon(Icons.search),
                    border: InputBorder.none,
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                    });
                  },
                ),
              ),
              
              const SizedBox(height: 16),
              
              // All Staff Section
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.orange[100],
                      child: Icon(
                        Icons.group,
                        color: Colors.orange[600],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'All Staff',
                            style: TextStyle(
                              fontSize: 16,
                fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Mark All Present',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        // Mark all staff present
                        for (final employee in employees) {
                          await _saveAttendance(employee, _selectedAttendanceDate!, 'Present');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[600],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('PRESENT'),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Employee List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: employees.length,
                  cacheExtent: 500,
                  itemBuilder: (context, index) {
                    final emp = employees[index];
                    
                    // Filter by search query
                    if (searchQuery.isNotEmpty && 
                        !emp.name.toLowerCase().contains(searchQuery.toLowerCase())) {
                      return const SizedBox.shrink();
                    }
                        
                    return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                    backgroundColor: Colors.orange[100],
                    child: Text(
                                  StatusUtils.getInitial(emp.name, fallback: 'E'),
                    style: TextStyle(
                                    color: Colors.orange[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                                    Text(
                                      emp.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Not Marked',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Builder(
                                builder: (innerContext) {
                                  final isDateValid = _isAttendanceDateValid(emp, _selectedAttendanceDate!);
                                  return Row(
                                    children: [
                                      // Present Button
                                      GestureDetector(
                                        onTap: isDateValid ? () {
                                          _saveAttendance(emp, _selectedAttendanceDate!, 'Present');
                                        } : null,
                                        behavior: HitTestBehavior.opaque,
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: isDateValid ? Colors.green[100] : Colors.grey[100],
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: isDateValid ? Colors.green[300]! : Colors.grey[300]!),
                                          ),
                                          child: Center(
                                            child: Text(
                                              'P',
                                              style: TextStyle(
                                                color: isDateValid ? Colors.green[600] : Colors.grey[400],
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Absent Button
                                      GestureDetector(
                                        onTap: isDateValid ? () {
                                          _saveAttendance(emp, _selectedAttendanceDate!, 'Absent');
                                        } : null,
                                        behavior: HitTestBehavior.opaque,
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: isDateValid ? Colors.red[100] : Colors.grey[100],
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: isDateValid ? Colors.red[300]! : Colors.grey[300]!),
                                          ),
                                          child: Center(
                                            child: Text(
                                              'A',
                                              style: TextStyle(
                                                color: isDateValid ? Colors.red[600] : Colors.grey[400],
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // More Options Button
                                      GestureDetector(
                                        onTap: isDateValid ? () {
                                          final appState = Provider.of<AppState>(innerContext, listen: false);
                                          // For all staff view, pass null - dialog will fetch if needed
                                          _showAttendanceOptionsDialog(innerContext, appState, emp, _selectedAttendanceDate!, null);
                                        } : null,
                                        behavior: HitTestBehavior.opaque,
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: isDateValid ? Colors.grey[100] : Colors.grey[50],
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: isDateValid ? Colors.grey[300]! : Colors.grey[200]!),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.keyboard_arrow_down,
                                          color: isDateValid ? Colors.grey[600] : Colors.grey[400],
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
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

  String _formatDateForAttendance(DateTime date) {
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    final weekday = weekdays[date.weekday - 1];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year.toString().substring(2);
    
    return '$weekday, $day $month $year';
  }

  bool _isAttendanceDateValid(UserAccount employee, DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final joiningDate = DateTime(employee.createdAt.year, employee.createdAt.month, employee.createdAt.day);
    return normalizedDate.isAtSameMomentAs(joiningDate) || normalizedDate.isAfter(joiningDate);
  }

  void _showAttendanceOptionsDialog(BuildContext context, AppState appState, UserAccount employee, DateTime date, List<Attendance>? monthAttendance) {
    // Check if date is valid before showing options
    if (!_isAttendanceDateValid(employee, date)) {
      return;
    }
    
    // Check if present is already marked for this date
    Attendance? currentAttendance;
    if (monthAttendance != null) {
      final selectedDateStr = '${date.year}_${date.month}_${date.day}';
      for (final att in monthAttendance) {
        final attDateStr = '${att.date.year}_${att.date.month}_${att.date.day}';
        if (attDateStr == selectedDateStr) {
          currentAttendance = att;
          break;
        }
      }
    }
    
    final isPresentMarked = currentAttendance != null && 
        (currentAttendance.status.toLowerCase() == 'present' ||
         currentAttendance.status.toLowerCase() == 'overtime' ||
         currentAttendance.status.toLowerCase() == 'late fine');
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Employee info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Text(
                      employee.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isPresentMarked 
                          ? '${_formatDateForAttendance(date)} - ${currentAttendance!.status}'
                          : '${_formatDateForAttendance(date)} - Not Marked',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Action buttons grid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Show overtime/late fine if present is marked
                    if (isPresentMarked) ...[
                      Row(
                        children: [
                          Expanded(
                            child: _buildOptionButton(
                              'Add Overtime',
                              Icons.schedule,
                              Colors.blue,
                              () {
                                Navigator.pop(context);
                                _showOvertimeDialog(context, employee, date);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildOptionButton(
                              'Late Fine',
                              Icons.money_off,
                              Colors.red,
                              () {
                                Navigator.pop(context);
                                _showLateFineDialog(context, employee, date);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ] else ...[
                      // Show all options if not marked
                      Row(
                        children: [
                          Expanded(
                            child: _buildOptionButton(
                              'Add Overtime',
                              Icons.schedule,
                              Colors.blue,
                              () {
                                Navigator.pop(context);
                                _showOvertimeDialog(context, employee, date);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildOptionButton(
                              'Late Fine',
                              Icons.money_off,
                              Colors.red,
                              () {
                                Navigator.pop(context);
                                _showLateFineDialog(context, employee, date);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildOptionButton(
                              'Paid Holiday',
                              Icons.beach_access,
                              Colors.green,
                              () async {
                                Navigator.pop(context);
                                await _saveAttendanceWithDetails(employee, date, 'Paid Holiday');
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('${employee.name} marked as Paid Holiday'),
                                      backgroundColor: Colors.green[600],
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildOptionButton(
                              'Half Day',
                              Icons.schedule,
                              Colors.orange,
                              () {
                                Navigator.pop(context);
                                _showHalfDayDialog(context, employee, date);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showOvertimeDialog(BuildContext context, UserAccount employee, DateTime date) {
    // Check if date is valid before showing dialog
    if (!_isAttendanceDateValid(employee, date)) {
      return;
    }
    
    final hoursController = TextEditingController();
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Overtime - ${employee.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Date: ${_formatDateForAttendance(date)}'),
            const SizedBox(height: 16),
            TextField(
              controller: hoursController,
              decoration: const InputDecoration(
                labelText: 'Overtime Hours',
                hintText: 'Enter hours (e.g., 2.5)',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'Enter reason for overtime',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (hoursController.text.isNotEmpty) {
                final hours = double.tryParse(hoursController.text);
                if (hours != null && hours > 0) {
                  Navigator.of(context).pop();
                  await _saveAttendanceWithDetails(
                    employee, 
                    date, 
                    'Overtime', 
                    notes: reasonController.text.isNotEmpty ? reasonController.text : null,
                    overtimeHours: hours,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Overtime added for ${employee.name}'),
                        backgroundColor: Colors.blue[600],
                      ),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter valid hours'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showLateFineDialog(BuildContext context, UserAccount employee, DateTime date) {
    // Check if date is valid before showing dialog
    if (!_isAttendanceDateValid(employee, date)) {
      return;
    }
    
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Late Fine - ${employee.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Date: ${_formatDateForAttendance(date)}'),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: 'Fine Amount (Rs.)',
                hintText: 'Enter amount',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'Enter reason for late fine',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (amountController.text.isNotEmpty) {
                final amount = double.tryParse(amountController.text);
                if (amount != null && amount > 0) {
                  Navigator.of(context).pop();
                  await _saveAttendanceWithDetails(
                    employee, 
                    date, 
                    'Late Fine', 
                    notes: reasonController.text.isNotEmpty ? reasonController.text : null,
                    fineAmount: amount,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Late fine added for ${employee.name}'),
                        backgroundColor: Colors.red[600],
                      ),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter valid amount'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showHalfDayDialog(BuildContext context, UserAccount employee, DateTime date) {
    // Check if date is valid before showing dialog
    if (!_isAttendanceDateValid(employee, date)) {
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Half Day - ${employee.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Date: ${_formatDateForAttendance(date)}'),
            const SizedBox(height: 16),
            const Text(
              'Select Half Day Option:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await _saveAttendanceWithDetails(
                        employee, 
                        date, 
                        'Half Day', 
                        notes: 'Morning',
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${employee.name} marked as Half Day (Morning)'),
                            backgroundColor: Colors.orange[600],
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.wb_sunny),
                    label: const Text('Morning'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[100],
                      foregroundColor: Colors.orange[700],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await _saveAttendanceWithDetails(
                        employee, 
                        date, 
                        'Half Day', 
                        notes: 'Evening',
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${employee.name} marked as Half Day (Evening)'),
                            backgroundColor: Colors.orange[600],
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.nights_stay),
                    label: const Text('Evening'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[100],
                      foregroundColor: Colors.orange[700],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionButton(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceCalendar(BuildContext context, UserAccount employee) {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    
    // Get the weekday of the first day (0 = Sunday, 1 = Monday, etc.)
    final firstDayWeekday = firstDayOfMonth.weekday % 7;
    
    return Column(
      children: [
        // Days of week header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                .map((day) => Expanded(
                      child: Text(
                        day,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
        
        // Calendar grid
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemCount: 42, // 6 weeks * 7 days
            itemBuilder: (context, index) {
              final dayIndex = index - firstDayWeekday;
              final isCurrentMonth = dayIndex >= 0 && dayIndex < daysInMonth;
              final day = dayIndex + 1;
              final isToday = isCurrentMonth && day == now.day;
              final isPast = isCurrentMonth && day < now.day;
              
              if (!isCurrentMonth) {
                return Container(); // Empty cell for days outside current month
              }
              
              return GestureDetector(
                onTap: isPast ? () => _markAttendance(context, employee, day) : null,
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isToday 
                        ? Colors.blue[100] 
                        : isPast 
                            ? Colors.grey[100] 
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isToday 
                        ? Border.all(color: Colors.blue[600]!, width: 2)
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          color: isToday 
                              ? Colors.blue[600] 
                              : isPast 
                                  ? Colors.grey[600] 
                                  : Colors.grey[400],
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Attendance status indicator
                      if (isPast)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.grey[300], // Default: no attendance marked
                            shape: BoxShape.circle,
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
    );
  }

  void _markAttendance(BuildContext context, UserAccount employee, int day) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Mark Attendance - ${employee.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Date: ${DateTime.now().month}/$day/${DateTime.now().year}'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      final date = DateTime(DateTime.now().year, DateTime.now().month, day);
                      _saveAttendance(employee, date, 'Present');
                    },
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: const Text('Present'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      final date = DateTime(DateTime.now().year, DateTime.now().month, day);
                      _saveAttendance(employee, date, 'Absent');
                    },
                    icon: const Icon(Icons.close, color: Colors.white),
                    label: const Text('Absent'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAttendance(UserAccount employee, DateTime date, String status) async {
    await _saveAttendanceWithDetails(employee, date, status);
  }

  Future<void> _saveAttendanceWithDetails(
    UserAccount employee, 
    DateTime date, 
    String status, {
    String? notes,
    double? overtimeHours,
    double? fineAmount,
  }) async {
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      
      // Normalize date to midnight
      final normalizedDate = DateTime(date.year, date.month, date.day);
      
      // Normalize joining date to midnight for comparison
      final joiningDate = DateTime(employee.createdAt.year, employee.createdAt.month, employee.createdAt.day);
      
      // Check if the attendance date is before the employee's joining date
      if (normalizedDate.isBefore(joiningDate)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cannot add attendance before joining date. Employee joined on ${_formatDateForAttendance(joiningDate)}'),
              backgroundColor: Colors.red[600],
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }
      
      // Check if attendance already exists for this date
      final attendanceId = '${employee.uid}_${date.year}_${date.month}_${date.day}';
      Attendance? existingAttendance;
      
      // Try to get existing attendance from Firestore (optimized - only fetch for this date)
      try {
        final existingList = await FirebaseService.getEmployeeAttendanceForMonth(
          employee.uid,
          date.year,
          date.month,
        );
        for (final att in existingList) {
          if (att.date.year == date.year && 
              att.date.month == date.month && 
              att.date.day == date.day) {
            existingAttendance = att;
            break;
          }
        }
      } catch (e) {
        // Silently continue - will create new record
      }
      
      // Determine final status and merge data
      String finalStatus = status;
      String? finalNotes = notes;
      double? finalOvertimeHours = overtimeHours;
      double? finalFineAmount = fineAmount;
      DateTime createdAt = PakistanTime.now();
      
      // If adding overtime/late fine to existing present record
      if (existingAttendance != null && 
          existingAttendance.status.toLowerCase() == 'present') {
        if (status.toLowerCase() == 'overtime') {
          finalStatus = 'Overtime';
          finalOvertimeHours = overtimeHours;
          finalNotes = notes ?? existingAttendance.notes;
          createdAt = existingAttendance.createdAt; // Keep original creation date
        } else if (status.toLowerCase() == 'late fine') {
          finalStatus = 'Late Fine';
          finalFineAmount = fineAmount;
          finalNotes = notes ?? existingAttendance.notes;
          createdAt = existingAttendance.createdAt; // Keep original creation date
        }
      } else if (existingAttendance != null && 
                 existingAttendance.status.toLowerCase() == 'overtime' &&
                 status.toLowerCase() == 'late fine') {
        // If already overtime, add late fine - keep overtime but add fine
        finalStatus = 'Late Fine'; // Late fine takes precedence
        finalOvertimeHours = existingAttendance.overtimeHours; // Keep existing overtime
        finalFineAmount = fineAmount;
        finalNotes = notes ?? existingAttendance.notes;
        createdAt = existingAttendance.createdAt;
      } else if (existingAttendance != null && 
                 existingAttendance.status.toLowerCase() == 'late fine' &&
                 status.toLowerCase() == 'overtime') {
        // If already late fine, add overtime - keep fine but add overtime
        finalStatus = 'Late Fine'; // Keep late fine status, but add overtime hours
        finalFineAmount = existingAttendance.fineAmount; // Keep existing fine
        finalOvertimeHours = overtimeHours;
        finalNotes = notes ?? existingAttendance.notes;
        createdAt = existingAttendance.createdAt;
      } else if (existingAttendance != null) {
        // For other statuses (half day, paid holiday), update notes if provided
        finalNotes = notes ?? existingAttendance.notes;
        createdAt = existingAttendance.createdAt;
      }
      
      // Create/update attendance record
      final attendance = Attendance(
        id: attendanceId,
        employeeId: employee.uid,
        employeeName: employee.name,
        date: normalizedDate,
        status: finalStatus,
        notes: finalNotes,
        overtimeHours: finalOvertimeHours,
        fineAmount: finalFineAmount,
        companyId: appState.currentUser?.companyId,
        createdAt: createdAt,
        updatedAt: PakistanTime.now(),
      );
      
      // Save without blocking - don't await to make it faster
      FirebaseService.saveAttendance(attendance).then((_) {
        // Show success message after save completes
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${employee.name} marked as $finalStatus'),
              backgroundColor: Colors.green[600],
              duration: const Duration(milliseconds: 800),
            ),
          );
        }
      }).catchError((error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save: ${error.toString()}'),
              backgroundColor: Colors.red[600],
              duration: const Duration(seconds: 2),
            ),
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save attendance: ${e.toString()}'),
            backgroundColor: Colors.red[600],
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showPayrollDialog(BuildContext context, AppState appState, UserAccount employee) {
    Navigator.of(context).pop(); // Close the employee book dialog first
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _PayrollDialogWidget(appState: appState, employee: employee),
    );
  }

  // Helper method to format dates
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // Method to show create employee dialog
  void _showCreateEmployeeDialog(BuildContext context, AppState appState) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CreateEmployeeDialog(appState: appState),
    );
  }

  // Method to show employee details dialog
  void _showEmployeeDetailsDialog(BuildContext context, UserAccount employee) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: primaryColor,
              child: Text(
                StatusUtils.getInitial(employee.name, fallback: 'E'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    employee.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Employee Details',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Personal Information Section
                _buildDetailSection('Personal Information', [
                  if (employee.email.isNotEmpty)
                    _buildDetailRow('Email', employee.email),
                  _buildDetailRow('CNIC', employee.cnic ?? 'N/A'),
                  if (employee.phone != null && employee.phone!.isNotEmpty)
                    _buildDetailRow('Phone', employee.phone!),
                  if (employee.address != null && employee.address!.isNotEmpty)
                    _buildDetailRow('Address', employee.address!),
                  _buildDetailRow('Role', employee.role),
                  _buildDetailRow('Status', employee.isActive ? 'Active' : 'Inactive'),
                  _buildDetailRow('Joined', _formatDate(employee.createdAt)),
                ]),
                
                const SizedBox(height: 16),
                
                // Employment Details Section
                _buildEmployeeDetailsSection('Employment Details', [
                  if (employee.cnic?.isNotEmpty == true)
                    _buildEmployeeDetailRow(Icons.credit_card, 'CNIC', employee.cnic!),
                  if (employee.salary?.isNotEmpty == true)
                    _buildEmployeeDetailRow(Icons.attach_money, 'Base Salary', 'Rs ${employee.salary}'),
                  if (employee.salaryType?.isNotEmpty == true)
                    _buildEmployeeDetailRow(Icons.schedule, 'Salary Type', employee.salaryType!),
                  _buildEmployeeDetailRow(Icons.business, 'Company ID', employee.companyId ?? 'N/A'),
                ]),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Method to show delete employee dialog
  void _showDeleteEmployeeDialog(BuildContext context, AppState appState, UserAccount employee) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Delete Employee'),
        content: Text('Are you sure you want to delete ${employee.name}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await appState.deleteEmployee(employee.uid);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${employee.name} deleted successfully'),
                      backgroundColor: Colors.green[600],
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete employee: $e'),
                      backgroundColor: Colors.red[600],
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // Helper method to build detail sections
  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  // Helper method to build detail rows
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build stat cards
  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: primaryColor),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to get status icon
  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return Icons.check_circle;
      case 'pending':
        return Icons.pending;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  // Helper method to build employee details section
  Widget _buildEmployeeDetailsSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  // Helper method to build employee detail rows
  Widget _buildEmployeeDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  // Method to show driver details dialog
  void _showDriverDetailsDialog(BuildContext context, AppState appState, UserAccount driver) {
    // Check if driver has login credentials (email & password)
    if (!driver.hasLoginCredentials) {
      _showEmployeeDetailsDialog(context, driver);
      return;
    }
    
    // Get driver statistics
    final totalBottlesSold = appState.getDriverTotalBottlesSoldById(driver.uid);
    final totalCashCollected = appState.getDriverTotalCashCollectedById(driver.uid);
    
    // Get driver's assigned routes
    final assignedRoutes = appState.routes.values.where((route) => 
        route.assignedDriver != null &&
        route.assignedDriver!.toLowerCase().trim() == driver.name.toLowerCase().trim()).toList();
    
    // Get driver's assigned customers based on routes (area + day matching)
    final assignedCustomers = appState.customers.where((customer) {
      for (final route in assignedRoutes) {
        // Check if customer's area matches any of the route areas
        final areaMatches = route.areas.any((routeArea) =>
          routeArea.trim().toLowerCase() == customer.area.trim().toLowerCase()
        );
        if (!areaMatches) continue;
        
        // Check if customer's assigned days overlap with route days
        final dayMatches = route.days.any((routeDay) => 
          customer.daysAssigned.contains(routeDay)
        );
        if (dayMatches) return true;
      }
      return false;
    }).toList();
    
    // Get driver's orders
    final driverOrders = appState.orders.where((order) => 
        order.assignedDriver != null &&
        order.assignedDriver!.toLowerCase().trim() == driver.name.toLowerCase().trim()).toList();
    
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent auto-close on outside tap
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue,
              child: Text(
                StatusUtils.getInitial(driver.name, fallback: 'D'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    driver.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Driver Profile',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Personal Information Section
                _buildDetailSection('Personal Information', [
                  _buildDetailRow('Email', driver.email),
                  _buildDetailRow('CNIC', driver.cnic?.isNotEmpty == true ? driver.cnic! : 'N/A'),
                  if (driver.phone != null && driver.phone!.isNotEmpty)
                    _buildDetailRow('Phone', driver.phone!),
                  if (driver.address != null && driver.address!.isNotEmpty)
                    _buildDetailRow('Address', driver.address!),
                  _buildDetailRow('Base Salary', driver.salary?.isNotEmpty == true ? 'Rs ${driver.salary}' : 'Rs 0'),
                  if (driver.salaryType != null && driver.salaryType!.isNotEmpty)
                    _buildDetailRow('Salary Type', driver.salaryType!),
                  _buildDetailRow('Role', driver.role),
                  _buildDetailRow('Status', driver.isActive ? 'Active' : 'Inactive'),
                  _buildDetailRow('Joined', _formatDate(driver.createdAt)),
                ]),
                
                const SizedBox(height: 16),
                
                // Performance Statistics Section
                _buildDetailSection('Performance Statistics', [
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard('Bottles Sold', '$totalBottlesSold', Icons.sell),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard('Cash Collected', 'Rs. $totalCashCollected', Icons.money),
                      ),
                    ],
                  ),
                ]),
                
                const SizedBox(height: 16),
                
                // Assigned Customers Section
                _buildDetailSection('Assigned Customers', [
                  if (assignedCustomers.isEmpty)
                    const Text('No customers assigned', style: TextStyle(color: Colors.grey))
                  else
                    ...assignedCustomers.take(5).map((customer) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.blue[100],
                            child: Text(
                              StatusUtils.getInitial(customer.name, fallback: 'C'),
                              style: TextStyle(fontSize: 10, color: Colors.blue[800]),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${customer.name} - ${customer.area}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    )),
                  if (assignedCustomers.length > 5)
                    Text('... and ${assignedCustomers.length - 5} more customers',
                        style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ]),
                
                const SizedBox(height: 16),
                
                // Assigned Routes Section
                _buildDetailSection('Assigned Routes', [
                  if (assignedRoutes.isEmpty)
                    const Text('No routes assigned', style: TextStyle(color: Colors.grey))
                  else
                    ...assignedRoutes.map((route) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Icon(Icons.route, size: 16, color: Colors.orange[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${route.days.join(', ')} - ${route.areas.join(', ')}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    )),
                ]),
                
                const SizedBox(height: 16),
                
                // Recent Orders Section
                _buildDetailSection('Recent Orders', [
                  if (driverOrders.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: Text('No orders found', style: TextStyle(color: Colors.grey))),
                    )
                  else
                    ...driverOrders.take(5).map((order) {
                      final customer = appState.customers.firstWhere(
                        (c) => c.id == order.customerId,
                        orElse: () => Customer(
                          id: '',
                          name: 'Unknown',
                          phone: '',
                          address: '',
                          area: '',
                          product: '',
                          numberOfBottles: 0,
                          daysAssigned: [],
                          paymentMode: 'Cash',
                          bottleRate: 0,
                          bottleDeposit: 0,
                          lastDelivery: DateTime.now(),
                        ),
                      );
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(order.status).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _getStatusIcon(order.status),
                                        size: 14,
                                        color: _getStatusColor(order.status),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        order.status,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: _getStatusColor(order.status),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        customer.name,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${order.quantity} bottles',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Rs. ${(order.price + (order.salesTax ?? 0)) * order.quantity}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green[700],
                                      ),
                                    ),
                                    Text(
                                      _formatDate(order.createdAt),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  if (driverOrders.length > 5)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('... and ${driverOrders.length - 5} more orders',
                          style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ),
                ]),
              ],
            ),
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

  Color _getStatusColor(String status) {
    switch (StatusUtils.normalizeStatus(status)) {
      case 'Pending': return Colors.orange;
      case 'Delivered': return Colors.green;
      default: return Colors.grey;
    }
  }
}

// Optimized Create Employee Dialog Widget
class _CreateEmployeeDialog extends StatefulWidget {
  final AppState appState;

  const _CreateEmployeeDialog({required this.appState});

  @override
  State<_CreateEmployeeDialog> createState() => _CreateEmployeeDialogState();
}

class _CreateEmployeeDialogState extends State<_CreateEmployeeDialog> {
  // Controllers
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _cnicController;
  late final TextEditingController _contactNumberController;
  late final TextEditingController _driverAddressController;
  late final TextEditingController _salaryController;
  late final TextEditingController _designationController;

  // State variables
  String _selectedSalaryType = 'Monthly';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers once
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _cnicController = TextEditingController();
    _contactNumberController = TextEditingController();
    _driverAddressController = TextEditingController();
    _salaryController = TextEditingController();
    _designationController = TextEditingController();
  }

  @override
  void dispose() {
    // Dispose controllers
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _cnicController.dispose();
    _contactNumberController.dispose();
    _driverAddressController.dispose();
    _salaryController.dispose();
    _designationController.dispose();
    super.dispose();
  }

  // Fast validation method
  bool _validateFields() {
    final name = _nameController.text.trim();
    final cnic = _cnicController.text.trim();
    final contact = _contactNumberController.text.trim();
    final address = _driverAddressController.text.trim();
    final salary = _salaryController.text.trim();
    final designation = _designationController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || cnic.isEmpty || contact.isEmpty || 
        address.isEmpty || salary.isEmpty || designation.isEmpty) {
      _showError('Please fill all required fields');
      return false;
    }

    if ((email.isNotEmpty && password.isEmpty) || 
        (email.isEmpty && password.isNotEmpty)) {
      _showError('Email and password must both be provided or both left empty');
      return false;
    }
    
    // If email is provided, validate email format with regex
    if (email.isNotEmpty) {
      final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
      if (!emailRegex.hasMatch(email)) {
        _showError('Please enter a valid email address (e.g., user@example.com)');
        return false;
      }
    }
    
    // If password is provided, validate password strength
    if (password.isNotEmpty && password.length < 6) {
      _showError('Password must be at least 6 characters long');
      return false;
    }

    return true;
  }

  // Fast error display
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red[600],
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Fast success display
  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green[600],
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Helper method to format dates
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // Optimized async method
  Future<void> _addEmployee() async {
    if (!_validateFields()) return;

    setState(() => _isLoading = true);

    try {
      await widget.appState.createEmployee(
        name: _nameController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        password: _passwordController.text.trim().isEmpty ? null : _passwordController.text.trim(),
        role: 'driver',
        cnic: _cnicController.text.trim(),
        contactNumber: _contactNumberController.text.trim(),
        driverAddress: _driverAddressController.text.trim(),
        salary: _salaryController.text.trim(),
        designation: _designationController.text.trim(),
        salaryType: _selectedSalaryType,
      );

      if (mounted) {
        Navigator.of(context).pop();
        _showSuccess('Employee added successfully');
      }
    } catch (e) {
      String errorMessage = 'Failed to add employee';
      if (e.toString().contains('email-already-in-use')) {
        errorMessage = 'Email is already in use. Please use a different email or leave it empty.';
      } else if (e.toString().contains('weak-password')) {
        errorMessage = 'Password is too weak. Please use a stronger password.';
      } else if (e.toString().contains('invalid-email')) {
        errorMessage = 'Invalid email format. Please enter a valid email.';
      } else if (e.toString().contains('re-authenticate')) {
        errorMessage = 'Authentication failed. Please log in again.';
      }
      
      _showError(errorMessage);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Employee Only'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Name Field
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              
              // Email Field
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email (Optional)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              
              // Password Field
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password (Optional)',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              
              // CNIC Field
              TextField(
                controller: _cnicController,
                decoration: const InputDecoration(
                  labelText: 'CNIC *',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              
              // Contact Number Field
              TextField(
                controller: _contactNumberController,
                decoration: const InputDecoration(
                  labelText: 'Contact Number *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              
              // Address Field
              TextField(
                controller: _driverAddressController,
                decoration: const InputDecoration(
                  labelText: 'Address *',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              
              // Salary Field
              TextField(
                controller: _salaryController,
                decoration: const InputDecoration(
                  labelText: 'Salary *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              
              // Salary Type Dropdown
              DropdownButtonFormField<String>(
                value: _selectedSalaryType,
                decoration: const InputDecoration(
                  labelText: 'Salary Type *',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Monthly', child: Text('Monthly')),
                  DropdownMenuItem(value: 'Weekly', child: Text('Weekly')),
                  DropdownMenuItem(value: 'Daily', child: Text('Daily')),
                  DropdownMenuItem(value: 'Hourly', child: Text('Hourly')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedSalaryType = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              
              // Designation Field
              TextField(
                controller: _designationController,
                decoration: const InputDecoration(
                  labelText: 'Designation *',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addEmployee(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _addEmployee,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add'),
        ),
      ],
    );
  }
}

class _PayrollDialogWidget extends StatefulWidget {
  final AppState appState;
  final UserAccount employee;
  
  const _PayrollDialogWidget({
    required this.appState,
    required this.employee,
  });
  
  @override
  _PayrollDialogWidgetState createState() => _PayrollDialogWidgetState();
}

class _PayrollDialogWidgetState extends State<_PayrollDialogWidget> {
  DateTime selectedMonth = DateTime.now();
  
  // Simple in-memory tracking of salary payments (in production, this would be in Firebase)
  static Map<String, List<Map<String, dynamic>>> _salaryPayments = {};
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.9,
        child: Column(
          children: [
            // Header with back button and title
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.orange[600]!,
                    Colors.orange[400]!,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      Expanded(
                        child: Text(
                          'Salary Book',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 48), // Balance the back button
                    ],
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: _buildPayrollContentForStateful(
                context, 
                widget.appState, 
                widget.employee, 
                selectedMonth,
                (DateTime newMonth) {
                  setState(() {
                    selectedMonth = newMonth;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Helper method to get company name
  String _getCompanyName(UserAccount? currentUser) {
    if (currentUser == null) return 'Admin';
    
    // For legacy admin without companyId, show company name from email
    if (currentUser.companyId == null) {
      final emailPrefix = currentUser.email.split('@').first;
      return emailPrefix.replaceAll('.', ' ').replaceAll('_', ' ').split(' ').map((word) => 
        word.isNotEmpty ? word[0].toUpperCase() + word.substring(1).toLowerCase() : ''
      ).join(' ');
    }
    
    // For new company admins, try to get a meaningful name
    // First try to use the user's name if it's not empty
    if (currentUser.name.isNotEmpty && currentUser.name != 'Admin') {
      return currentUser.name;
    }
    
    // Fallback to email prefix
    final emailPrefix = currentUser.email.split('@').first;
    return emailPrefix.replaceAll('.', ' ').replaceAll('_', ' ').split(' ').map((word) => 
      word.isNotEmpty ? word[0].toUpperCase() + word.substring(1).toLowerCase() : ''
    ).join(' ');
  }
  
  // Helper methods for salary tracking
  double _getSalaryPaidThisMonth(UserAccount employee, DateTime month) {
    String key = '${employee.uid}_${month.year}_${month.month}';
    if (_salaryPayments.containsKey(key)) {
      return _salaryPayments[key]!.fold<double>(0, (sum, payment) => sum + (payment['amount'] as double));
    }
    return 0.0;
  }
  
  bool _isSalaryPaidThisMonth(UserAccount employee, DateTime month) {
    return _getSalaryPaidThisMonth(employee, month) > 0;
  }
  
  void _markSalaryAsPaid(UserAccount employee, DateTime paymentDate, double amount) {
    String key = '${employee.uid}_${paymentDate.year}_${paymentDate.month}';
    if (!_salaryPayments.containsKey(key)) {
      _salaryPayments[key] = [];
    }
    _salaryPayments[key]!.add({
      'amount': amount,
      'date': paymentDate,
      'employee': employee.name,
    });
    
  }
  
  // Enhanced salary calculation based on salary type using per-day rate
  // Only calculates for marked days - if no days are marked, salary is 0
  double _calculateSalaryBasedOnType(
    double baseSalaryRate,
    String salaryType,
    double totalPresent,
    double totalAbsent,
    double paidHolidays,
    double halfDays,
    double overtimeDays, // Days with overtime (already counted in totalPresent)
    DateTime selectedMonth,
    DateTime employeeJoiningDate,
  ) {
    // Count total marked days
    final totalMarkedDays = totalPresent + totalAbsent + paidHolidays + halfDays;
    
    // If no days are marked, salary is 0
    if (totalMarkedDays == 0) {
      return 0.0;
    }
    
    // Calculate days in month
    final daysInMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
    final monthStart = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final monthEnd = DateTime(selectedMonth.year, selectedMonth.month, daysInMonth);
    
    // Determine effective month start based on joining date
    final effectiveMonthStart = (employeeJoiningDate.isAfter(monthStart)) 
        ? employeeJoiningDate 
        : monthStart;
    final effectiveMonthEnd = monthEnd;
    
    // Calculate effective days in month (considering joining date)
    final effectiveDaysInMonth = effectiveMonthEnd.difference(effectiveMonthStart).inDays + 1;
    
    switch (salaryType.toLowerCase()) {
      case 'monthly':
        // Calculate per-day rate: total monthly base salary / days in month
        final perDayRate = baseSalaryRate / effectiveDaysInMonth;
        
        // Calculate salary ONLY for marked days:
        // - Add for present days (including overtime/late fine which count as present)
        // - Add for paid holidays
        // - Add half rate for half days
        // - Subtract for absent days
        // Unmarked days are not included (neither added nor subtracted)
        double calculatedSalary = (totalPresent * perDayRate) +  // Present days
                                   (paidHolidays * perDayRate) +  // Paid holidays
                                   (halfDays * perDayRate * 0.5) - // Half days (half rate)
                                   (totalAbsent * perDayRate);     // Absent days (deduct)
        
        return calculatedSalary;
        
      case 'weekly':
        // For weekly: baseSalaryRate is weekly rate, convert to per-day
        // First calculate what a full month would be in weekly terms
        final weeksInEffectiveMonth = effectiveDaysInMonth / 7.0;
        final monthlyEquivalent = baseSalaryRate * weeksInEffectiveMonth;
        
        // Now calculate per-day rate based on monthly equivalent
        final perDayRate = monthlyEquivalent / effectiveDaysInMonth;
        
        // Calculate salary ONLY for marked days using same logic as monthly
        double calculatedSalary = (totalPresent * perDayRate) +
                                   (paidHolidays * perDayRate) +
                                   (halfDays * perDayRate * 0.5) -
                                   (totalAbsent * perDayRate);
        
        return calculatedSalary;
        
      case 'daily':
        // For daily: baseSalaryRate is daily rate
        final perDayRate = baseSalaryRate;
        
        // Calculate salary ONLY for marked days using same logic
        double calculatedSalary = (totalPresent * perDayRate) +
                                   (paidHolidays * perDayRate) +
                                   (halfDays * perDayRate * 0.5) -
                                   (totalAbsent * perDayRate);
        
        return calculatedSalary;
        
      case 'hourly':
        // For hourly: calculate based on hours worked (only for marked days)
        // Assume 8 hours per day for present days, 4 hours for half days
        // If no days marked, hoursWorked = 0, so salary = 0
        final hoursWorked = (totalPresent * 8) + (halfDays * 4) + overtimeDays * 8;
        final hourlySalary = baseSalaryRate * hoursWorked;
        return hourlySalary;
        
      default:
        // Default to monthly calculation
        final perDayRate = baseSalaryRate / effectiveDaysInMonth;
        double calculatedSalary = (totalPresent * perDayRate) +
                                   (paidHolidays * perDayRate) +
                                   (halfDays * perDayRate * 0.5) -
                                   (totalAbsent * perDayRate);
        return calculatedSalary;
    }
  }
  
  // Simple employee details dialog for the payroll context
  void _showEmployeeDetailsDialog(BuildContext context, UserAccount employee) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: Text(employee.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('CNIC: ${employee.cnic ?? 'N/A'}'),
            Text('Contact: ${employee.contactNumber ?? 'N/A'}'),
            Text('Designation: ${employee.designation ?? employee.role}'),
            Text('Base Salary: Rs ${employee.salary ?? '0'}'),
            if (employee.salaryType?.isNotEmpty == true)
              Text('Salary Type: ${employee.salaryType}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPayrollContentForStateful(BuildContext context, AppState appState, UserAccount employee, DateTime selectedMonth, Function(DateTime) onMonthChanged) {
    String searchQuery = '';
    
    return FutureBuilder<List<Attendance>>(
      future: FirebaseService.getEmployeeAttendanceForMonth(
        employee.uid,
        selectedMonth.year,
        selectedMonth.month,
      ),
      builder: (context, snapshot) {
        // Calculate attendance data from Firebase
        double totalPresent = 0.0;
        double totalAbsent = 0.0;
        double paidHolidays = 0.0;
        double notMarked = 0.0;
        double fineTotal = 0.0;
        double halfDays = 0.0;
        double overtimeHoursTotal = 0.0;
        
        // Get employee's joining date for filtering
        final employeeJoiningDate = DateTime(
          employee.createdAt.year,
          employee.createdAt.month,
          employee.createdAt.day,
        );
        
        if (snapshot.hasData) {
          for (final attendance in snapshot.data!) {
            // Normalize attendance date to midnight for comparison
            final attendanceDate = DateTime(
              attendance.date.year,
              attendance.date.month,
              attendance.date.day,
            );
            
            // Skip attendance records before the employee's joining date
            if (attendanceDate.isBefore(employeeJoiningDate)) {
              continue;
            }
            
            // Check if this attendance date is within the selected month
            if (attendanceDate.year == selectedMonth.year && 
                attendanceDate.month == selectedMonth.month) {
              final status = attendance.status.toLowerCase();
              if (status == 'present') {
                totalPresent++;
              } else if (status == 'absent') {
                totalAbsent++;
              } else if (status == 'paid holiday') {
                paidHolidays++;
              } else if (status == 'half day') {
                halfDays++;
              } else if (status == 'overtime') {
                // Count as present + add overtime hours
                totalPresent++;
                if (attendance.overtimeHours != null) {
                  overtimeHoursTotal += attendance.overtimeHours!;
                }
              } else if (status == 'late fine') {
                // Count as present but with fine deduction
                totalPresent++;
                if (attendance.fineAmount != null) {
                  fineTotal += attendance.fineAmount!;
                }
              }
            }
          }
          
          // Calculate not marked days (total days in month from joining date onwards)
          final daysInMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
          
          // Adjust calculation if employee joined mid-month
          DateTime monthStart = DateTime(selectedMonth.year, selectedMonth.month, 1);
          DateTime monthEnd = DateTime(selectedMonth.year, selectedMonth.month, daysInMonth);
          
          DateTime effectiveMonthStart = (employeeJoiningDate.isAfter(monthStart)) 
              ? employeeJoiningDate 
              : monthStart;
          DateTime effectiveMonthEnd = (employeeJoiningDate.isBefore(monthEnd)) 
              ? monthEnd 
              : employeeJoiningDate;
          
          int effectiveDaysInMonth = effectiveMonthEnd.difference(effectiveMonthStart).inDays + 1;
          
          // Count only valid attendance records
          int validAttendanceCount = 0;
          if (snapshot.hasData) {
            for (final attendance in snapshot.data!) {
              final attendanceDate = DateTime(
                attendance.date.year,
                attendance.date.month,
                attendance.date.day,
              );
              if (attendanceDate.isAtSameMomentAs(employeeJoiningDate) || 
                  attendanceDate.isAfter(employeeJoiningDate)) {
                if (attendanceDate.year == selectedMonth.year && 
                    attendanceDate.month == selectedMonth.month) {
                  validAttendanceCount++;
                }
              }
            }
          }
          
          notMarked = effectiveDaysInMonth - validAttendanceCount.toDouble();
        }
        
        // Calculate payroll data based on salary type
        double baseSalaryRate = double.tryParse(employee.salary ?? '0') ?? 0.0;
        double closingBalance = 0.0; // This would come from previous month
        
        // Calculate base salary based on salary type using per-day rate
        // Note: overtime days are already counted in totalPresent
        double baseSalary = _calculateSalaryBasedOnType(
          baseSalaryRate, 
          employee.salaryType ?? 'Monthly',
          totalPresent,
          totalAbsent,
          paidHolidays,
          halfDays,
          0.0, // Overtime days (already in totalPresent for per-day calculation)
          selectedMonth,
          employeeJoiningDate,
        );
        
        // Apply fine deductions to net salary
        double salaryAfterFines = baseSalary - fineTotal;
        
        // Check if salary has been paid this month
        bool salaryPaid = _isSalaryPaidThisMonth(employee, selectedMonth);
        double monthPayment = _getSalaryPaidThisMonth(employee, selectedMonth); // Get actual salary paid
        
        double netSalary = salaryAfterFines + closingBalance - monthPayment;
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        return _buildPayrollContentUI(
          context,
          appState,
          employee,
          selectedMonth,
          onMonthChanged,
          searchQuery,
          baseSalary,
          closingBalance,
          monthPayment,
          netSalary,
          totalPresent,
          totalAbsent,
          paidHolidays,
          notMarked,
          fineTotal,
          halfDays,
          overtimeHoursTotal,
        );
      },
    );
  }
  
  Widget _buildPayrollContentUI(
    BuildContext context,
    AppState appState,
    UserAccount employee,
    DateTime selectedMonth,
    Function(DateTime) onMonthChanged,
    String searchQuery,
    double baseSalary,
    double closingBalance,
    double monthPayment,
    double netSalary,
    double totalPresent,
    double totalAbsent,
    double paidHolidays,
    double notMarked,
    double fine,
    double halfDays,
    double extraTime,
  ) {
    return Container(
      color: Colors.grey[100],
      child: Column(
        children: [
          // Payroll Summary Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                // Month Selection
                Expanded(
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          onMonthChanged(DateTime(selectedMonth.year, selectedMonth.month - 1, 1));
                        },
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Text(
                          '${_getMonthName(selectedMonth.month)} ${selectedMonth.year}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          onMonthChanged(DateTime(selectedMonth.year, selectedMonth.month + 1, 1));
                        },
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),
                // Salary Amount
                Column(
                  children: [
                    Text(
                      'Rs ${netSalary.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[600],
                      ),
                    ),
                    Text(
                      'Salary',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Search and Export
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _generatePayrollPDF(context, appState, employee, selectedMonth),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[600],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.picture_as_pdf,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Employee Payroll Details Card
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Employee Info
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: Colors.grey[300],
                          child: Text(
                            StatusUtils.getInitial(employee.name, fallback: 'E'),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                employee.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${employee.salaryType ?? 'Monthly'} Salary',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                'Base Rate: Rs ${employee.salary ?? '0'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'Rs ${netSalary.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[600],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Info button explaining salary calculation
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Salary Breakdown',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.info_outline, color: Colors.blue[600]),
                          onPressed: () => _showSalaryCalculationInfoDialog(context, employee, selectedMonth),
                          tooltip: 'How is salary calculated?',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Enhanced Financial Breakdown
                    _buildPayrollRow('Previous Balance', 'Rs ${closingBalance.toStringAsFixed(0)}', Colors.red),
                    
                    // Show detailed salary calculation based on type
                    _buildDetailedSalaryRow(employee, selectedMonth, baseSalary, totalPresent, totalAbsent, paidHolidays, halfDays, fine, extraTime),
                    
                    _buildPayrollRow('${_getMonthName(selectedMonth.month)} Payment', 'Rs ${monthPayment.toStringAsFixed(0)}', Colors.black),
                    
                    // Show deductions if any
                    if (fine > 0)
                      _buildPayrollRow('Fine Deductions', 'Rs ${fine.toStringAsFixed(0)}', Colors.red),
                    
                    const Divider(),
                    _buildPayrollRow('Net Salary Due', 'Rs ${netSalary.toStringAsFixed(0)}', Colors.green[600]!),
                    
                    const SizedBox(height: 20),
                    
                    // Attendance Summary
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildAttendanceItem('Total Present', totalPresent.toStringAsFixed(0), Colors.green),
                              _buildAttendanceItem('Total Absent', totalAbsent.toStringAsFixed(0), Colors.red),
                              _buildAttendanceItem('Paid Holidays', paidHolidays.toStringAsFixed(0), Colors.blue),
                              _buildAttendanceItem('Not Marked', notMarked.toStringAsFixed(0), Colors.orange),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildAttendanceItem('Fine', 'Rs ${fine.toStringAsFixed(0)}', Colors.red),
                              _buildAttendanceItem('Half Days', halfDays.toStringAsFixed(0), Colors.orange),
                              _buildAttendanceItem('Overtime', '${extraTime.toStringAsFixed(1)}h', Colors.green),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Give Salary Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showGiveSalaryDialog(context, appState, employee, netSalary, selectedMonth),
                        icon: const Icon(Icons.payment, color: Colors.white),
                        label: const Text(
                          'Give Salary',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build detailed salary row based on salary type
  Widget _buildDetailedSalaryRow(
    UserAccount employee, 
    DateTime selectedMonth, 
    double baseSalary, 
    double totalPresent,
    double totalAbsent,
    double paidHolidays, 
    double halfDays,
    double fine,
    double extraTime
  ) {
    final salaryType = employee.salaryType ?? 'Monthly';
    final baseRate = double.tryParse(employee.salary ?? '0') ?? 0.0;
    final daysInMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
    
    String title;
    String details;
    
    switch (salaryType.toLowerCase()) {
      case 'monthly':
        final perDayRate = baseRate / daysInMonth;
        title = '${_getMonthName(selectedMonth.month)} Salary (Monthly)';
        details = 'Rs ${baseSalary.toStringAsFixed(0)} (Per-day: Rs ${perDayRate.toStringAsFixed(0)})';
        break;
        
      case 'weekly':
        final weeksInMonth = daysInMonth / 7.0;
        final monthlyEquivalent = baseRate * weeksInMonth;
        final perDayRate = monthlyEquivalent / daysInMonth;
        
        title = '${_getMonthName(selectedMonth.month)} Salary (Weekly)';
        details = 'Rs ${baseSalary.toStringAsFixed(0)} (Per-day: Rs ${perDayRate.toStringAsFixed(0)})';
        break;
        
      case 'daily':
        final perDayRate = baseRate;
        title = '${_getMonthName(selectedMonth.month)} Salary (Daily)';
        details = 'Rs ${baseSalary.toStringAsFixed(0)} (Per-day: Rs ${perDayRate.toStringAsFixed(0)})';
        break;
        
      case 'hourly':
        final hoursWorked = (totalPresent * 8) + (halfDays * 4) + extraTime;
        title = '${_getMonthName(selectedMonth.month)} Salary (Hourly)';
        details = 'Rs ${baseSalary.toStringAsFixed(0)} (${hoursWorked.toStringAsFixed(1)} hours × Rs ${baseRate.toStringAsFixed(0)})';
        break;
        
      default:
        final perDayRate = baseRate / daysInMonth;
        title = '${_getMonthName(selectedMonth.month)} Salary';
        details = 'Rs ${baseSalary.toStringAsFixed(0)} (Per-day: Rs ${perDayRate.toStringAsFixed(0)})';
    }
    
    return _buildPayrollRow(title, details, Colors.black);
  }
  
  // Show info dialog explaining salary calculation
  void _showSalaryCalculationInfoDialog(BuildContext context, UserAccount employee, DateTime selectedMonth) {
    final salaryType = employee.salaryType ?? 'Monthly';
    final baseRate = double.tryParse(employee.salary ?? '0') ?? 0.0;
    final daysInMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
    
    String calculationMethod = '';
    double perDayRate = 0.0;
    
    switch (salaryType.toLowerCase()) {
      case 'monthly':
        perDayRate = baseRate / daysInMonth;
        calculationMethod = '''
**Monthly Salary Calculation:**

1. **Per-Day Rate**: Total Monthly Salary ÷ Days in Month
   = Rs ${baseRate.toStringAsFixed(0)} ÷ $daysInMonth days
   = Rs ${perDayRate.toStringAsFixed(2)} per day

2. **Important**: Salary is calculated ONLY for marked attendance days.
   If no days are marked, salary = Rs 0.

3. **Salary Calculation** (for marked days only):
   - Add: Present days × Per-day rate
   - Add: Paid holidays × Per-day rate
   - Add: Half days × (Per-day rate ÷ 2)
   - Subtract: Absent days × Per-day rate
   - Subtract: Late fines
   - Unmarked days: Not included (neither added nor subtracted)

4. **Final Salary** = (Present + Paid Holidays + Half Days/2) × Per-day rate
                    - (Absent × Per-day rate) - Fines
        ''';
        break;
        
      case 'weekly':
        final weeksInMonth = daysInMonth / 7.0;
        final monthlyEquivalent = baseRate * weeksInMonth;
        perDayRate = monthlyEquivalent / daysInMonth;
        calculationMethod = '''
**Weekly Salary Calculation:**

1. **Monthly Equivalent**: Weekly Rate × Weeks in Month
   = Rs ${baseRate.toStringAsFixed(0)} × ${weeksInMonth.toStringAsFixed(1)} weeks
   = Rs ${monthlyEquivalent.toStringAsFixed(0)}

2. **Per-Day Rate**: Monthly Equivalent ÷ Days in Month
   = Rs ${monthlyEquivalent.toStringAsFixed(0)} ÷ $daysInMonth days
   = Rs ${perDayRate.toStringAsFixed(2)} per day

3. **Important**: Salary is calculated ONLY for marked attendance days.
   If no days are marked, salary = Rs 0.

4. **Salary Calculation** (for marked days only):
   - Add: Present days × Per-day rate
   - Add: Paid holidays × Per-day rate
   - Add: Half days × (Per-day rate ÷ 2)
   - Subtract: Absent days × Per-day rate
   - Subtract: Late fines
   - Unmarked days: Not included (neither added nor subtracted)
        ''';
        break;
        
      case 'daily':
        perDayRate = baseRate;
        calculationMethod = '''
**Daily Salary Calculation:**

1. **Per-Day Rate**: Daily Rate = Rs ${baseRate.toStringAsFixed(0)}

2. **Important**: Salary is calculated ONLY for marked attendance days.
   If no days are marked, salary = Rs 0.

3. **Salary Calculation** (for marked days only):
   - Add: Present days × Per-day rate
   - Add: Paid holidays × Per-day rate
   - Add: Half days × (Per-day rate ÷ 2)
   - Subtract: Absent days × Per-day rate
   - Subtract: Late fines
   - Unmarked days: Not included (neither added nor subtracted)

4. **Final Salary** = (Present + Paid Holidays + Half Days/2) × Daily rate
                    - (Absent × Daily rate) - Fines
        ''';
        break;
        
      case 'hourly':
        calculationMethod = '''
**Hourly Salary Calculation:**

1. **Important**: Salary is calculated ONLY for marked attendance days.
   If no days are marked, salary = Rs 0.

2. **Hours Worked** (for marked days only):
   - Present days × 8 hours
   - Half days × 4 hours
   - Overtime hours (if any)

3. **Salary Calculation**:
   Final Salary = Total Hours Worked × Hourly Rate

4. **Note**: Late fines are deducted from hourly salary as well.
   Unmarked days contribute 0 hours.
        ''';
        break;
        
      default:
        perDayRate = baseRate / daysInMonth;
        calculationMethod = '''
**Default (Monthly) Salary Calculation:**

1. **Per-Day Rate**: Total Monthly Salary ÷ Days in Month
   = Rs ${baseRate.toStringAsFixed(0)} ÷ $daysInMonth days
   = Rs ${perDayRate.toStringAsFixed(2)} per day

2. **Important**: Salary is calculated ONLY for marked attendance days.
   If no days are marked, salary = Rs 0.

3. **Salary Calculation** (for marked days only):
   - Add: Present days × Per-day rate
   - Add: Paid holidays × Per-day rate
   - Add: Half days × (Per-day rate ÷ 2)
   - Subtract: Absent days × Per-day rate
   - Subtract: Late fines
   - Unmarked days: Not included (neither added nor subtracted)
        ''';
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue[600]),
            const SizedBox(width: 8),
            const Text('Salary Calculation Method'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'How is ${employee.name}\'s salary calculated?',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Salary Type: ${salaryType}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Base Rate: Rs ${baseRate.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                calculationMethod,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Important Notes:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Salary is calculated ONLY for marked attendance days\n'
                      '• If no days are marked, salary = Rs 0\n'
                      '• Overtime and Late Fine days count as Present\n'
                      '• Paid Holidays are added to salary\n'
                      '• Half Days get half of per-day rate\n'
                      '• Absent days are deducted\n'
                      '• Unmarked days are not included in calculation\n'
                      '• Late fines are deducted from final salary',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[800],
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildPayrollRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
  
  // Get month name from DateTime
  String _getMonthNameFromDate(DateTime date) {
    return _getMonthName(date.month);
  }

  void _showGiveSalaryDialog(BuildContext context, AppState appState, UserAccount employee, double amount, DateTime selectedMonth) {
    final amountController = TextEditingController(text: amount.toStringAsFixed(0));
    final detailsController = TextEditingController(text: 'Salary');
    // Use selected month for payment date, not current date
    DateTime paymentDate = DateTime(selectedMonth.year, selectedMonth.month, 1);
    String paymentMethod = 'Cash';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.orange[600]!,
                        Colors.orange[400]!,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      Expanded(
                        child: Text(
                          'Give Salary',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 48), // Balance the back button
                    ],
                  ),
                ),
                
                // Content
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                        // Amount Field
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Amount',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: amountController,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                prefixIcon: Container(
                                  margin: const EdgeInsets.all(8),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Text(
                                    'Rs',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Details Field
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Details',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: detailsController,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Payment Date Field
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Payment Date',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: paymentDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (date != null) {
                                  setState(() {
                                    paymentDate = date;
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today, color: Colors.grey),
                                    const SizedBox(width: 12),
                                    Text(
                                      '${paymentDate.day} ${_getMonthName(paymentDate.month)}, ${paymentDate.year}',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Payment Method Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                builder: (context) => Container(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ListTile(
                                        title: const Text('Cash'),
                                        onTap: () {
                                          setState(() {
                                            paymentMethod = 'Cash';
                                          });
                                          Navigator.pop(context);
                                        },
                                      ),
                                      ListTile(
                                        title: const Text('Bank Transfer'),
                                        onTap: () {
                                          setState(() {
                                            paymentMethod = 'Bank Transfer';
                                          });
                                          Navigator.pop(context);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.red,
                              side: BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text(
                              paymentMethod,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 30),
                        
                        // Save Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              // Process salary payment
                              _processSalaryPayment(
                                context,
                                appState,
                                employee,
                                double.tryParse(amountController.text) ?? 0.0,
                                detailsController.text,
                                paymentDate,
                                paymentMethod,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange[600],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text(
                              'SAVE',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  void _processSalaryPayment(
    BuildContext context,
    AppState appState,
    UserAccount employee,
    double amount,
    String details,
    DateTime paymentDate,
    String paymentMethod,
  ) async {
    try {
      // Create expense record
      await appState.createExpense(
        title: 'Salary Payment',
        description: 'Salary given to ${employee.name}',
        amount: amount.toInt(),
        category: 'Salary',
        date: paymentDate,
      );
      
      // Mark salary as paid for the selected month (not payment date)
      final selectedMonth = DateTime(paymentDate.year, paymentDate.month, 1);
      _markSalaryAsPaid(employee, selectedMonth, amount);
      
      // Close dialogs
      Navigator.of(context).pop(); // Close give salary dialog
      Navigator.of(context).pop(); // Close payroll dialog
      
      // Show success message
      final monthName = _getMonthName(paymentDate.month);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Salary of Rs ${amount.toStringAsFixed(0)} given to ${employee.name}. ${monthName} Payment is now Rs ${amount.toStringAsFixed(0)}.'),
          backgroundColor: Colors.green[600],
        ),
      );
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing salary payment: $e'),
          backgroundColor: Colors.red[600],
        ),
      );
    }
  }


  // Helper method for PDF salary details
  pw.Widget _buildPDFSalaryDetail(String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  void _generatePayrollPDF(BuildContext context, AppState appState, UserAccount employee, DateTime selectedMonth) async {
    try {
      // Get actual attendance data from Firebase
      final attendanceData = await FirebaseService.getEmployeeAttendanceForMonth(
        employee.uid,
        selectedMonth.year,
        selectedMonth.month,
      );
      
      // Get employee's joining date for filtering
      final employeeJoiningDate = DateTime(
        employee.createdAt.year,
        employee.createdAt.month,
        employee.createdAt.day,
      );
      
      // Calculate actual attendance statistics
      double totalPresent = 0.0;
      double totalAbsent = 0.0;
      double paidHolidays = 0.0;
      double halfDays = 0.0;
      double overtimeHours = 0.0;
      double fineTotal = 0.0;
      
      int validAttendanceCount = 0;
      for (final attendance in attendanceData) {
        // Normalize attendance date to midnight for comparison
        final attendanceDate = DateTime(
          attendance.date.year,
          attendance.date.month,
          attendance.date.day,
        );
        
        // Skip attendance records before the employee's joining date
        if (attendanceDate.isBefore(employeeJoiningDate)) {
          continue;
        }
        
        // Check if this attendance date is within the selected month
        if (attendanceDate.year == selectedMonth.year && 
            attendanceDate.month == selectedMonth.month) {
          validAttendanceCount++;
          
          switch (attendance.status.toLowerCase()) {
            case 'present':
              totalPresent++;
              break;
            case 'absent':
              totalAbsent++;
              break;
            case 'paid holiday':
              paidHolidays++;
              break;
            case 'half day':
              halfDays++;
              break;
            case 'overtime':
              totalPresent++; // Count as present
              overtimeHours += attendance.overtimeHours ?? 0.0;
              break;
            case 'late fine':
              totalPresent++; // Count as present but with fine
              fineTotal += attendance.fineAmount ?? 0.0;
              break;
          }
        }
      }
      
      // Calculate days in month adjusted for joining date
      final daysInMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
      
      // Adjust calculation if employee joined mid-month
      DateTime monthStart = DateTime(selectedMonth.year, selectedMonth.month, 1);
      DateTime monthEnd = DateTime(selectedMonth.year, selectedMonth.month, daysInMonth);
      
      DateTime effectiveMonthStart = (employeeJoiningDate.isAfter(monthStart)) 
          ? employeeJoiningDate 
          : monthStart;
      DateTime effectiveMonthEnd = (employeeJoiningDate.isBefore(monthEnd)) 
          ? monthEnd 
          : employeeJoiningDate;
      
      int effectiveDaysInMonth = effectiveMonthEnd.difference(effectiveMonthStart).inDays + 1;
      final notMarked = effectiveDaysInMonth - validAttendanceCount.toDouble();
      
      // Calculate salary based on type
      final baseSalaryRate = double.tryParse(employee.salary ?? '0') ?? 0.0;
      final salaryType = employee.salaryType ?? 'Monthly';
      
      double baseSalary = _calculateSalaryBasedOnType(
        baseSalaryRate,
        salaryType,
        totalPresent,
        totalAbsent,
        paidHolidays,
        halfDays,
        0.0, // Overtime days already counted in totalPresent
        selectedMonth,
        employeeJoiningDate,
      );
      
      double closingBalance = 0.0;
      double monthPayment = _getSalaryPaidThisMonth(employee, selectedMonth);
      double netSalary = baseSalary + closingBalance - monthPayment - fineTotal;
      
      // Calculate payment details for PDF
      double octoberPayment = monthPayment;
      double remainingAmount = netSalary - octoberPayment;
      
      // Get company information
      String companyName = _getCompanyName(appState.currentUser);
      String companyEmail = appState.currentUser?.email ?? 'N/A';
      
      
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generating PDF...'),
          duration: Duration(seconds: 2),
        ),
      );
      
      // Create PDF document
      final pdf = pw.Document();
      
      // Determine the effective month start and end dates for PDF
      DateTime pdfMonthStart = DateTime(selectedMonth.year, selectedMonth.month, 1);
      DateTime pdfMonthEnd = DateTime(selectedMonth.year, selectedMonth.month, daysInMonth);
      int startDay = 1;
      int endDay = daysInMonth;
      
      // If employee joined mid-month in the same month
      if (selectedMonth.year == employeeJoiningDate.year && 
          selectedMonth.month == employeeJoiningDate.month) {
        startDay = effectiveMonthStart.day;
        endDay = effectiveMonthEnd.day;
      }
      
      // Build daily attendance map for the month
      Map<int, Attendance?> dailyAttendance = {};
      for (int day = startDay; day <= endDay; day++) {
        dailyAttendance[day] = null;
      }
      
      // Fill in attendance data
      for (final attendance in attendanceData) {
        final attendanceDate = DateTime(
          attendance.date.year,
          attendance.date.month,
          attendance.date.day,
        );
        
        // Skip records before joining date
        if (attendanceDate.isBefore(employeeJoiningDate)) {
          continue;
        }
        
        // Check if within selected month
        if (attendanceDate.year == selectedMonth.year && 
            attendanceDate.month == selectedMonth.month) {
          dailyAttendance[attendanceDate.day] = attendance;
        }
      }
      
      // Add first page (Payroll Summary) to PDF
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.orange,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'Employee Salary Slip',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        companyName,
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.Text(
                        companyEmail,
                        style: pw.TextStyle(
                          fontSize: 14,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                
                pw.SizedBox(height: 20),
                
                // Report Details
                pw.Text(
                  '${_getMonthName(selectedMonth.month)} ${selectedMonth.year} Salary Report',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Employee: ${employee.name} (${salaryType} Salary)',
                  style: pw.TextStyle(
                    fontSize: 14,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Text(
                  'Generated on: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                  style: pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.grey600,
                  ),
                ),
                
                pw.SizedBox(height: 20),
                
                // Salary Calculation Details
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Salary Calculation Details',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      _buildPDFSalaryDetail('Salary Type', salaryType),
                      _buildPDFSalaryDetail('Base Rate', 'Rs ${baseSalaryRate.toStringAsFixed(0)}'),
                      _buildPDFSalaryDetail('Total Present Days', totalPresent.toStringAsFixed(0)),
                      _buildPDFSalaryDetail('Total Absent Days', totalAbsent.toStringAsFixed(0)),
                      _buildPDFSalaryDetail('Paid Holidays', paidHolidays.toStringAsFixed(0)),
                      _buildPDFSalaryDetail('Half Days', halfDays.toStringAsFixed(0)),
                      _buildPDFSalaryDetail('Overtime Hours', overtimeHours.toStringAsFixed(1)),
                      if (fineTotal > 0) _buildPDFSalaryDetail('Fine Deductions', 'Rs ${fineTotal.toStringAsFixed(0)}'),
                      pw.Divider(),
                      _buildPDFSalaryDetail('Calculated Salary', 'Rs ${baseSalary.toStringAsFixed(0)}', isBold: true),
                    ],
                  ),
                ),
                
                pw.SizedBox(height: 20),
                
                // Payroll Table
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey),
                  children: [
                    // Header Row
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Closing Balance', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Salary', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Payment', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Total Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                    // Employee Row
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('${employee.name} - Weekly'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Rs ${closingBalance.toStringAsFixed(0)}'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Rs ${baseSalary.toStringAsFixed(2)}'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Rs ${octoberPayment.toStringAsFixed(0)}'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Rs ${netSalary.toStringAsFixed(0)}'),
                        ),
                      ],
                    ),
                  ],
                ),
                
                pw.SizedBox(height: 20),
                
                // Salary Summary
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Salary Summary',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 12),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Base Salary:'),
                          pw.Text('Rs ${baseSalary.toStringAsFixed(0)}'),
                        ],
                      ),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Amount Paid:'),
                          pw.Text('Rs ${octoberPayment.toStringAsFixed(0)}', 
                            style: pw.TextStyle(color: PdfColors.green)),
                        ],
                      ),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Remaining Amount:'),
                          pw.Text('Rs ${remainingAmount.toStringAsFixed(0)}', 
                            style: pw.TextStyle(color: PdfColors.red)),
                        ],
                      ),
                    ],
                  ),
                ),
                
                pw.SizedBox(height: 20),
                
                // Attendance Details
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey50,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Attendance Detail',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 12),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                        children: [
                          pw.Column(
                            children: [
                              pw.Text('${totalPresent.toStringAsFixed(0)}', 
                                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
                              pw.Text('Present', style: pw.TextStyle(fontSize: 10)),
                            ],
                          ),
                          pw.Column(
                            children: [
                              pw.Text('${totalAbsent.toStringAsFixed(0)}', 
                                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
                              pw.Text('Absent', style: pw.TextStyle(fontSize: 10)),
                            ],
                          ),
                          pw.Column(
                            children: [
                              pw.Text('${paidHolidays.toStringAsFixed(0)}', 
                                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue)),
                              pw.Text('Paid Holidays', style: pw.TextStyle(fontSize: 10)),
                            ],
                          ),
                          pw.Column(
                            children: [
                              pw.Text('${notMarked.toStringAsFixed(0)}', 
                                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.orange)),
                              pw.Text('Not Marked', style: pw.TextStyle(fontSize: 10)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                pw.Spacer(),
                
                // Footer
                pw.Text(
                  'Report Generated : ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')} ${DateTime.now().hour >= 12 ? 'PM' : 'AM'} | ${DateTime.now().day} ${_getMonthName(DateTime.now().month)} ${DateTime.now().year}',
                  style: pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            );
          },
        ),
      );
      
      // Add second page with detailed attendance report
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header for attendance report
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue700,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'Attendance Report',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        '${_getMonthName(selectedMonth.month)} ${selectedMonth.year} - Daily Attendance',
                        style: pw.TextStyle(
                          fontSize: 16,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                
                pw.SizedBox(height: 16),
                
                pw.Text(
                  'Employee: ${employee.name}',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Employee Joined: ${_getMonthName(employeeJoiningDate.month)} ${employeeJoiningDate.day}, ${employeeJoiningDate.year}',
                  style: pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.grey700,
                  ),
                ),
                
                pw.SizedBox(height: 16),
                
                // Daily Attendance Table
                pw.Container(
                  width: double.infinity,
                  child: pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey, width: 1),
                    children: [
                      // Header Row
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('Status', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('Details', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          ),
                        ],
                      ),
                      // Data Rows
                      ...dailyAttendance.entries.map((entry) {
                        int day = entry.key;
                        Attendance? attendance = entry.value;
                        
                        String status = 'Not Marked';
                        String details = '-';
                        PdfColor statusColor = PdfColors.grey;
                        
                        if (attendance != null) {
                          status = attendance.status;
                          
                          // Set color based on status
                          switch (attendance.status.toLowerCase()) {
                            case 'present':
                              statusColor = PdfColors.green;
                              details = '-';
                              break;
                            case 'absent':
                              statusColor = PdfColors.red;
                              details = '-';
                              break;
                            case 'late fine':
                              statusColor = PdfColors.orange;
                              details = 'Fine: Rs ${(attendance.fineAmount ?? 0).toStringAsFixed(0)}';
                              break;
                            case 'overtime':
                              statusColor = PdfColors.blue;
                              details = '${(attendance.overtimeHours ?? 0).toStringAsFixed(1)}h';
                              break;
                            case 'half day':
                              statusColor = PdfColors.orange;
                              details = attendance.notes ?? 'Morning';
                              break;
                            case 'paid holiday':
                              statusColor = PdfColors.purple;
                              details = '-';
                              break;
                            default:
                              statusColor = PdfColors.black;
                              details = attendance.notes ?? '-';
                          }
                        }
                        
                        String dateStr = '$day/${selectedMonth.month}/${selectedMonth.year}';
                        
                        return pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(dateStr, style: pw.TextStyle(fontSize: 9)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(status, style: pw.TextStyle(fontSize: 9, color: statusColor, fontWeight: pw.FontWeight.bold)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(details, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                            ),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                ),
                
                pw.Spacer(),
                
                pw.Text(
                  'Report Generated : ${DateTime.now().day} ${_getMonthName(DateTime.now().month)} ${DateTime.now().year}',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            );
          },
        ),
      );
      
      // Print the PDF
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Monthly_Report_${employee.name}_${selectedMonth.year}_${selectedMonth.month}.pdf',
      );
      
      // Show success message with payment details
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF Generated and Ready to Print!\nSalary: Rs ${baseSalary.toStringAsFixed(0)}\nPaid: Rs ${octoberPayment.toStringAsFixed(0)}\nRemaining: Rs ${remainingAmount.toStringAsFixed(0)}'),
          backgroundColor: Colors.green[600],
          duration: const Duration(seconds: 4),
        ),
      );
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating PDF: $e'),
          backgroundColor: Colors.red[600],
        ),
      );
    }
  }


  void _showDeleteEmployeeDialog(BuildContext context, AppState appState, UserAccount employee) {
    
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent auto-close on outside tap
      builder: (context) => AlertDialog(
        title: const Text('Delete Employee'),
        content: Text('Are you sure you want to delete ${employee.name}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Store ScaffoldMessenger reference before closing dialog
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              try {
                await appState.deleteEmployee(employee.uid);
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('${employee.name} deleted successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('Error deleting ${employee.name}: $e'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 5),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }


}



class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return AppShell(
          title: 'Products',
          body: Column(
            children: [
              // Add Product Button
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  onPressed: () => _showCreateProductDialog(context, appState),
                  icon: const Icon(Icons.add),
                  label: const Text('Add New Product'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ),
              // Products List
              Expanded(
                child: appState.products.isEmpty
                    ? const Center(
                        child: Text(
                          'No products found. Add some products to get started.',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : Builder(
                        builder: (context) {
                          // Sort products by creation date (newest first) - only once
                          final sortedProducts = List<Product>.from(appState.products)
                            ..sort((a, b) {
                              // Use PakistanTime for consistent sorting (newest first)
                              final pakistanDateA = PakistanTime.toPakistanTime(a.createdAt);
                              final pakistanDateB = PakistanTime.toPakistanTime(b.createdAt);
                              return pakistanDateB.compareTo(pakistanDateA);
                            });
                          
                          return ListView.builder(
                            itemCount: sortedProducts.length,
                            cacheExtent: 500,
                            itemBuilder: (context, index) {
                              final product = sortedProducts[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: primaryColor,
                                    child: Text(
                                      StatusUtils.getInitial(product.name, fallback: '?'),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  title: Text(product.name),
                                  subtitle: Text('Size: ${product.size}'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _showDeleteProductDialog(context, appState, product),
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

  void _showCreateProductDialog(BuildContext context, AppState appState) {
    final nameController = TextEditingController();
    final sizeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Product'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Product Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: sizeController,
              decoration: const InputDecoration(labelText: 'Size (e.g., 1L, 5L)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final product = Product(
                  id: PakistanTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text,
                  size: sizeController.text,
                );
                
                await appState.addProduct(product);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Product added successfully!')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showDeleteProductDialog(BuildContext context, AppState appState, Product product) {
    
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent auto-close on outside tap
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete ${product.name}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await appState.deleteProduct(product.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${product.name} deleted successfully!')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

}

class RoutesScreen extends StatelessWidget {
  const RoutesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final drivers = appState.employees.where((e) => e.role == 'driver').toList();
        
        return AppShell(
          title: 'Routes',
          body: Column(
            children: [
              // Add Route Button
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  onPressed: () => _showCreateRouteDialog(context, appState),
                  icon: const Icon(Icons.add),
                  label: const Text('Add New Route'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ),
              // Routes List
              Expanded(
                child: appState.routes.isEmpty
                    ? const Center(
                        child: Text(
                          'No routes found. Add some routes to get started.',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: appState.routes.length,
                        cacheExtent: 500,
                        itemBuilder: (context, index) {
                          // Sort routes by creation date (newest first)
                          final sortedRoutes = appState.routes.entries.toList()
                            ..sort((a, b) {
                              // Use PakistanTime for consistent sorting (newest first)
                              final pakistanDateA = PakistanTime.toPakistanTime(a.value.createdAt);
                              final pakistanDateB = PakistanTime.toPakistanTime(b.value.createdAt);
                              return pakistanDateB.compareTo(pakistanDateA);
                            });
                          final routeEntry = sortedRoutes[index];
                          final routeId = routeEntry.key;
                          final route = routeEntry.value;
                          final routeDisplayName = route.days.join(', ');
                          
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: primaryColor,
                                child: Text(
                                  route.days.isNotEmpty ? route.days[0][0].toUpperCase() : 'R',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text('${routeDisplayName} Route'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (route.assignedDriver != null)
                                    Text('Driver: ${route.assignedDriver}'),
                                  Text('Areas: ${route.areas.join(", ")}'),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 4,
                                    children: route.areas.map((area) => Chip(
                                      label: Text(area),
                                      backgroundColor: Colors.blue[100],
                                    )).toList(),
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _showDeleteRouteDialog(context, appState, routeId, routeDisplayName),
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

  void _showCreateRouteDialog(BuildContext context, AppState appState) {
    final areasController = TextEditingController();
    String selectedDriver = '';
    List<String> selectedDays = [];

    // Ensure context is still valid before showing dialog
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent auto-close on outside tap
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
        title: const Text('Add New Route'),
          content: SingleChildScrollView(
            child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
                // Multiple Day Selection
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Days *', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'].map((day) {
                        final isSelected = selectedDays.contains(day);
                        return FilterChip(
                          label: Text(day),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                selectedDays.add(day);
                              } else {
                                selectedDays.remove(day);
                              }
                            });
                          },
                          selectedColor: primaryColor.withOpacity(0.3),
                          checkmarkColor: primaryColor,
                );
              }).toList(),
                    ),
                    if (selectedDays.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Please select at least one day',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                // Driver Selection
            DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Assign to Driver *'),
                  isExpanded: true,
                  value: selectedDriver.isEmpty ? null : selectedDriver,
                  items: [
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('Select Driver'),
                    ),
                    ...appState.employees.where((e) => e.role == 'driver').map((driver) {
                return DropdownMenuItem<String>(
                  value: driver.name,
                  child: Text(driver.name),
                );
                    }),
                  ],
              onChanged: (String? newValue) {
                    selectedDriver = newValue ?? '';
              },
            ),
                const SizedBox(height: 16),
                // Areas Input
            TextField(
              controller: areasController,
              decoration: const InputDecoration(
                    labelText: 'Areas (comma separated) *',
                hintText: 'Area 1, Area 2, Area 3',
              ),
              maxLines: 3,
            ),
                const SizedBox(height: 16),
                // Info Text
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: const Text(
                    'After creating this route, all customers in the specified areas will be automatically assigned to the selected driver.',
                    style: TextStyle(fontSize: 12, color: Colors.blue),
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
            onPressed: () async {
                if (selectedDays.isEmpty || selectedDriver.isEmpty || areasController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all required fields')),
                );
                return;
              }

              // Check for duplicate route assignment
              final existingRoute = appState.routes.values.firstWhere(
                  (route) => route.days.any((day) => selectedDays.contains(day)) && route.assignedDriver == selectedDriver,
                  orElse: () => RoutePlan(days: [], areas: [], createdAt: DateTime.now()),
              );

                if (existingRoute.days.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Warning: $selectedDriver already has a route for one or more of the selected days')),
                );
                return;
              }

              try {
                final areas = areasController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                  final routeId = PakistanTime.now().millisecondsSinceEpoch.toString(); // Generate unique ID
                  
                final route = RoutePlan(
                    days: selectedDays,
                  areas: areas,
                  assignedDriver: selectedDriver,
                  createdAt: PakistanTime.now(),
                );
                
                  await appState.addRoute(route, routeId);
                  
                  // Automatically assign customers to driver
                  await _assignCustomersToDriver(context, appState, areas, selectedDriver);
                  
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Route added successfully for $selectedDriver!')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
        ),
      ),
    );
  }

  // Method to automatically assign customers to driver based on area AND day matching
  Future<void> _assignCustomersToDriver(BuildContext context, AppState appState, List<String> areas, String driverName) async {
    try {
      
      // Get the route that was just created to check its days
      final route = appState.routes.values.firstWhere(
        (r) => r.assignedDriver == driverName && 
               r.areas.any((area) => areas.contains(area)),
        orElse: () => RoutePlan(days: [], areas: [], assignedDriver: null, createdAt: DateTime.now()),
      );
      
      
      // Find customers that match BOTH area AND day criteria
      final eligibleCustomers = appState.customers.where((customer) {
        // Check if customer's area matches any of the route areas (improved matching)
        final areaMatches = areas.any((area) => 
          customer.area.trim().toLowerCase() == area.trim().toLowerCase()
        );
        
        // Check if customer's assigned days overlap with route days
        final dayMatches = route.days.any((routeDay) => 
          customer.daysAssigned.contains(routeDay)
        );
        
        
        return areaMatches && dayMatches;
      }).toList();
      
      
      int assignedCount = 0; // number of customers for whom at least one order was created
      List<String> assignmentNotifications = [];
      
      for (final customer in eligibleCustomers) {
        try {
          // Update customer's assignedDriver field if it doesn't match
          if (customer.assignedDriver == null || 
              customer.assignedDriver!.trim().toLowerCase() != driverName.trim().toLowerCase()) {
            await FirebaseService.updateCustomer(customer.id, {
              'assignedDriver': driverName,
              'updatedAt': DateTime.now().toIso8601String(),
            });
          }
          
          bool createdAny = false;
          // Create auto orders only for intersecting days between route and customer
          for (String day in route.days) {
            if (customer.daysAssigned.contains(day)) {
              final now = DateTime.now();
              final targetWeekday = _getWeekdayIndex(day);
              final currentWeekday = now.weekday;
              
              // Calculate days to add for this week relative to today
              int daysToAddThisWeek = targetWeekday - currentWeekday;
              DateTime todayDate = DateTime(now.year, now.month, now.day);
              DateTime thisWeekDate = todayDate.add(Duration(days: daysToAddThisWeek < 0 ? daysToAddThisWeek + 7 : daysToAddThisWeek));

              // If the route day is TODAY, create a Pending order now instead of an auto order
              if (daysToAddThisWeek == 0) {
                final orderData = {
                  'customerId': customer.id,
                  'customerName': customer.name,
                  'quantity': 0,
                  'price': customer.bottleRate,
                  'salesTax': 0,
                  'status': 'Pending',
                  'orderDate': FieldValue.serverTimestamp(),
                  'notes': 'Auto-generated from route created for today ($day)',
                  'assignedDriver': driverName,
                  'companyId': appState.currentUser?.companyId,
                };
                await FirebaseService.createOrder(orderData);
                createdAny = true;
                
                // Create a single auto order that recurs weekly starting next week
                final recurringStart = todayDate.add(const Duration(days: 7));
                final nextAuto = AutoOrder(
                  id: '${customer.id}_${day}_${DateTime.now().millisecondsSinceEpoch}_auto',
                  customerId: customer.id,
                  customerName: customer.name,
                  customerPhone: customer.phone,
                  customerArea: customer.area,
                  quantity: 0,
                  price: customer.bottleRate,
                  salesTax: 0,
                  assignedDriver: driverName,
                  dayOfWeek: day,
                  nextDeliveryDate: recurringStart,
                  isActive: true,
                  notes: 'Auto-generated recurring from route (today start)',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  companyId: appState.currentUser?.companyId,
                );
                await FirebaseService.createAutoOrder(nextAuto);
              } else {
                // Otherwise create a single recurring auto order starting this upcoming occurrence
                final nextAuto = AutoOrder(
                  id: '${customer.id}_${day}_${DateTime.now().millisecondsSinceEpoch}_auto',
                  customerId: customer.id,
                  customerName: customer.name,
                  customerPhone: customer.phone,
                  customerArea: customer.area,
                  quantity: 0,
                  price: customer.bottleRate,
                  salesTax: 0,
                  assignedDriver: driverName,
                  dayOfWeek: day,
                  nextDeliveryDate: thisWeekDate,
                  isActive: true,
                  notes: 'Auto-generated recurring from route',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  companyId: appState.currentUser?.companyId,
                );
                await FirebaseService.createAutoOrder(nextAuto);
                createdAny = true;
              }
            }
          }
          if (createdAny) {
            assignedCount++;
            assignmentNotifications.add('Customer: ${customer.name} scheduled for ${route.days.where((d) => customer.daysAssigned.contains(d)).join(', ')} with Driver: $driverName');
          }
        } catch (e) {
        }
      }
      
      // Show assignment notifications
      if (assignmentNotifications.isNotEmpty) {
        for (final notification in assignmentNotifications) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(notification),
                duration: const Duration(seconds: 4),
                backgroundColor: Colors.green,
              ),
            );
            // Small delay between notifications
            await Future.delayed(const Duration(milliseconds: 500));
          }
        }
      }
      
      
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error assigning customers: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Helper method for strict area matching (case-insensitive, trimmed)
  bool _isAreaMatch(String customerArea, String routeArea) {
    final customerLower = customerArea.trim().toLowerCase();
    final routeLower = routeArea.trim().toLowerCase();
    return customerLower == routeLower;
  }

  // Helper method to get the weekday index (1=Monday, 7=Sunday)
  int _getWeekdayIndex(String dayOfWeek) {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days.indexOf(dayOfWeek) + 1;
  }

  // Helper method to get date for this week's occurrence of a day
  DateTime _getDateForThisWeek(String dayOfWeek) {
    final now = DateTime.now();
    final targetWeekday = _getWeekdayIndex(dayOfWeek);
    final currentWeekday = now.weekday;
    
    int daysToAdd = targetWeekday - currentWeekday;
    
    // If the target day has already passed this week, wrap to next week
    if (daysToAdd <= 0) {
      daysToAdd += 7;
    }
    
    DateTime targetDate = now.add(Duration(days: daysToAdd));
    return DateTime(targetDate.year, targetDate.month, targetDate.day);
  }

  // Helper method to get date for next week's occurrence of a day
  DateTime _getDateForNextWeek(String dayOfWeek) {
    final now = DateTime.now();
    final targetWeekday = _getWeekdayIndex(dayOfWeek);
    final currentWeekday = now.weekday;
    
    int daysToAdd = targetWeekday - currentWeekday + 7; // Add 7 to ensure it's next week
    
    DateTime targetDate = now.add(Duration(days: daysToAdd));
    return DateTime(targetDate.year, targetDate.month, targetDate.day);
  }

  void _showDeleteRouteDialog(BuildContext context, AppState appState, String routeId, String routeDisplayName) {
    final route = appState.routes[routeId];
    if (route == null) return;
    
    // Count customers that will be affected
    // Check customers that match area AND days AND (have matching assignedDriver OR have orders/auto-orders for this route)
    final affectedCustomers = appState.customers.where((customer) {
      // Check area match
      final areaMatches = route.areas.any((area) => 
        customer.area.trim().toLowerCase() == area.trim().toLowerCase()
      );
      if (!areaMatches) return false;
      
      // Check day match
      final dayMatches = route.days.any((routeDay) => customer.daysAssigned.contains(routeDay));
      if (!dayMatches) return false;
      
      // Check driver match (case-insensitive, trimmed)
      final driverMatches = route.assignedDriver != null && customer.assignedDriver != null
        ? route.assignedDriver!.trim().toLowerCase() == customer.assignedDriver!.trim().toLowerCase()
        : route.assignedDriver == customer.assignedDriver; // Both null or both empty
      
      // If driver matches, this customer is affected
      if (driverMatches) return true;
      
      // Also check if customer has orders or auto-orders for this route's driver and days
      if (route.assignedDriver != null) {
        final routeDriverLower = route.assignedDriver!.trim().toLowerCase();
        
        // Check if customer has orders assigned to this route's driver for matching days
        final hasMatchingOrders = appState.orders.any((order) =>
          order.customerId == customer.id &&
          order.assignedDriver != null &&
          order.assignedDriver!.trim().toLowerCase() == routeDriverLower
        );
        
        // Check if customer has auto-orders assigned to this route's driver for matching days
        final hasMatchingAutoOrders = appState.autoOrders.any((autoOrder) =>
          autoOrder.customerId == customer.id &&
          autoOrder.isActive &&
          autoOrder.assignedDriver != null &&
          autoOrder.assignedDriver!.trim().toLowerCase() == routeDriverLower &&
          route.days.contains(autoOrder.dayOfWeek)
        );
        
        if (hasMatchingOrders || hasMatchingAutoOrders) return true;
      }
      
      return false;
    }).toList();
    
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent auto-close on outside tap
      builder: (context) => AlertDialog(
        title: const Text('Delete Route'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete the "$routeDisplayName" route?'),
            const SizedBox(height: 8),
            Text('Driver: ${route.assignedDriver ?? 'None'}'),
            Text('Areas: ${route.areas.join(', ')}'),
            const SizedBox(height: 8),
            if (affectedCustomers.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚠️ This will affect ${affectedCustomers.length} customer(s):',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                    const SizedBox(height: 4),
                    // Show all customers in a scrollable container
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: affectedCustomers.map((customer) => 
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text('• ${customer.name} (${customer.area})'),
                            )
                          ).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'These customers will be unassigned from the driver and become available for reassignment.',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: const Text(
                  '✅ No customers are currently assigned to this route.',
                  style: TextStyle(color: Colors.green),
                ),
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await appState.deleteRoute(routeId);
                Navigator.pop(context);
                
                // Show success message with details
                final message = affectedCustomers.isNotEmpty 
                  ? 'Route "$routeDisplayName" deleted successfully! ${affectedCustomers.length} customer(s) have been unassigned.'
                  : 'Route "$routeDisplayName" deleted successfully!';
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 4),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

}



// Driver-specific screens
class DriverOrdersScreen extends StatefulWidget {
  const DriverOrdersScreen({super.key});

  @override
  State<DriverOrdersScreen> createState() => _DriverOrdersScreenState();
}

class _DriverOrdersScreenState extends State<DriverOrdersScreen> {
  String _selectedFilter = 'Pending'; // Default to showing pending orders
  String? _selectedDay; // Selected day filter for scheduled orders

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final currentUser = appState.currentUser;
        if (currentUser == null) {
          return const AppShell(
            title: 'My Deliveries',
            body: Center(child: Text('Please log in')),
          );
        }

        // Get driver's assigned orders
        final allDriverOrders = appState.orders.where((order) {
          final customer = appState.customers.firstWhere(
            (c) => c.id == order.customerId,
            orElse: () => Customer(
              id: '',
              name: '',
              phone: '',
              address: '',
              area: '',
              product: '',
              numberOfBottles: 0,
              daysAssigned: [],
              paymentMode: 'Cash',
              bottleRate: 0,
              bottleDeposit: 0,
              lastDelivery: DateTime.now(),
              assignedDriver: null,
              createdAt: PakistanTime.now(),
            ),
          );
          return customer.assignedDriver == currentUser.name || order.assignedDriver == currentUser.name;
        }).toList();

        // Get today's weekday
        final today = DateTime.now();
        final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
        final todayWeekday = weekdays[today.weekday - 1];
        
        // Get driver's auto orders for next week
        final driverAutoOrders = appState.autoOrders.where((autoOrder) {
          return autoOrder.assignedDriver == currentUser.name && 
                 autoOrder.isActive &&
                 _isNextWeekDelivery(autoOrder.nextDeliveryDate);
        }).toList();

        // Filter orders based on selected filter
        List<OrderModel> driverOrders = [];
        List<AutoOrder> scheduledOrders = [];
        
        switch (_selectedFilter) {
          case 'Pending':
            // Show pending orders scheduled for TODAY only
            driverOrders = allDriverOrders.where((order) {
              final status = StatusUtils.normalizeStatus(order.status);
              if (status != 'Pending') return false;
              // Only include orders dated today
              return _isSameCalendarDay(order.orderDate, today);
            }).toList();
            break;
            
          case 'Delivered':
            // Show ALL delivered orders
            driverOrders = allDriverOrders.where((order) {
              return StatusUtils.normalizeStatus(order.status) == 'Delivered';
            }).toList();
            break;
            
          case 'Scheduled':
            // For scheduled view: show the next upcoming auto order PER CUSTOMER
            // Day chips act as filters; when "All" is selected, choose the nearest next date across all days
            final now = DateTime.now();
            final dayFilter = _selectedDay; // null = All
            final List<AutoOrder> driverAutos = appState.autoOrders.where((autoOrder) {
              if (autoOrder.assignedDriver != currentUser.name || !autoOrder.isActive) return false;
              if (autoOrder.nextDeliveryDate.isBefore(DateTime(now.year, now.month, now.day))) return false;
              if (dayFilter != null && autoOrder.dayOfWeek != dayFilter) return false;
              return true;
            }).toList();

            final Map<String, AutoOrder> byCustomerNext = {};
            for (final ao in driverAutos) {
              final existing = byCustomerNext[ao.customerId];
              if (existing == null || ao.nextDeliveryDate.isBefore(existing.nextDeliveryDate)) {
                byCustomerNext[ao.customerId] = ao;
              }
            }

            scheduledOrders = byCustomerNext.values.toList()
              ..sort((a, b) {
                // Use PakistanTime for consistent sorting (ascending - nearest first)
                final pakistanDateA = PakistanTime.toPakistanTime(a.nextDeliveryDate);
                final pakistanDateB = PakistanTime.toPakistanTime(b.nextDeliveryDate);
                return pakistanDateA.compareTo(pakistanDateB);
              });
            break;
            
          default:
            driverOrders = allDriverOrders;
        }

        return AppShell(
          title: 'My Deliveries',
          body: Column(
            children: [
              // Filter tabs
              Container(
                margin: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildFilterTab('Pending', Colors.orange),
                    ),
                    Expanded(
                      child: _buildFilterTab('Delivered', Colors.green),
                    ),
                    Expanded(
                      child: _buildFilterTab('Scheduled', Colors.purple),
                    ),
                  ],
                ),
              ),
              // Day filter for scheduled orders
              if (_selectedFilter == 'Scheduled')
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: weekdays.length + 1, // +1 for "All" option
                    cacheExtent: 200,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        // "All" option
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text('All'),
                            selected: _selectedDay == null,
                            onSelected: (selected) {
                              setState(() {
                                _selectedDay = null;
                              });
                            },
                            selectedColor: Colors.purple,
                            labelStyle: TextStyle(
                              color: _selectedDay == null ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }
                      final day = weekdays[index - 1];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(day.substring(0, 3)), // Show "Mon", "Tue", etc.
                          selected: _selectedDay == day,
                          onSelected: (selected) {
                            setState(() {
                              _selectedDay = day;
                            });
                          },
                          selectedColor: Colors.purple,
                          labelStyle: TextStyle(
                            color: _selectedDay == day ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              // Orders list
              Expanded(
                child: _selectedFilter == 'Scheduled'
                    ? (scheduledOrders.isEmpty
                        ? Center(
                            child: Text(
                              'No scheduled deliveries found.',
                              style: const TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          )
                        : _buildScheduledOrdersList(scheduledOrders, appState))
                    : (driverOrders.isEmpty
                        ? Center(
                            child: Text(
                              _selectedFilter == 'Pending' 
                                  ? 'No deliveries for today.'
                                  : 'No $_selectedFilter.toLowerCase() orders found.',
                              style: const TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          )
                        : _buildGroupedDriverOrdersList(driverOrders, appState)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterTab(String filter, Color color) {
    final isSelected = _selectedFilter == filter;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filter;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          filter,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : color,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending': return Colors.orange;
      case 'Delivered': return Colors.green;
      default: return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // Compare only calendar day (ignoring time)
  bool _isSameCalendarDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // Check if the delivery date is in the next week
  bool _isNextWeekDelivery(DateTime deliveryDate) {
    final now = DateTime.now();
    final daysUntilNextMonday = 7 - now.weekday + 1;
    final nextWeekStart = now.add(Duration(days: daysUntilNextMonday)); // Next Monday
    final nextWeekEnd = nextWeekStart.add(const Duration(days: 6)); // Next Sunday
    
    return deliveryDate.isAfter(nextWeekStart.subtract(const Duration(days: 1))) &&
           deliveryDate.isBefore(nextWeekEnd.add(const Duration(days: 1)));
  }

  // Build grouped auto orders list with date grouping
  // Build scheduled orders list for next day and next week
  Widget _buildScheduledOrdersList(List<AutoOrder> autoOrders, AppState appState) {
    return _buildGroupedAutoOrdersList(autoOrders, appState);
  }

  Widget _buildGroupedAutoOrdersList(List<AutoOrder> autoOrders, AppState appState) {
    final groupedAutoOrders = DateGroupingUtils.groupItemsByDate(
      autoOrders,
      (autoOrder) => autoOrder.nextDeliveryDate,
    );
    
    return ListView.builder(
      itemCount: DateGroupingUtils.getOrderedGroups().length,
      cacheExtent: 500,
      itemBuilder: (context, groupIndex) {
        final group = DateGroupingUtils.getOrderedGroups()[groupIndex];
        final autoOrdersInGroup = groupedAutoOrders[group]!;
        
        if (autoOrdersInGroup.isEmpty) {
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
                '${DateGroupingUtils.getDateGroupTitle(group)} (${autoOrdersInGroup.length})',
                style: TextStyle(
                  color: DateGroupingUtils.getDateGroupColor(group),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            // Auto orders in this group
            ...autoOrdersInGroup.map((autoOrder) => _buildAutoOrderCard(autoOrder, appState)),
          ],
        );
      },
    );
  }

  // Build individual auto order card
  Widget _buildAutoOrderCard(AutoOrder autoOrder, AppState appState) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.purple,
                  child: const Icon(
                    Icons.autorenew,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Auto Order - ${autoOrder.customerName}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Phone: ${autoOrder.customerPhone}',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(autoOrder.dayOfWeek),
                  backgroundColor: Colors.purple.withOpacity(0.2),
                  labelStyle: const TextStyle(color: Colors.purple),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDetailItem('Price', 'Rs. ${autoOrder.price}'),
                ),
                Expanded(
                  child: _buildDetailItem('Area', autoOrder.customerArea),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildDetailItem('Next Delivery', _formatDate(autoOrder.nextDeliveryDate)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule, color: Colors.purple[600], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Scheduled for ${autoOrder.dayOfWeek} - ${_formatDate(autoOrder.nextDeliveryDate)}',
                      style: TextStyle(
                        color: Colors.purple[700],
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build detail item widget
  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  // Build grouped driver orders list with date grouping
  Widget _buildGroupedDriverOrdersList(List<OrderModel> driverOrders, AppState appState) {
    final groupedOrders = DateGroupingUtils.groupItemsByDate(
      driverOrders,
      (order) => order.createdAt,
    );
    
    return ListView.builder(
      itemCount: DateGroupingUtils.getOrderedGroups().length,
      cacheExtent: 500,
      itemBuilder: (context, groupIndex) {
        final group = DateGroupingUtils.getOrderedGroups()[groupIndex];
        final ordersInGroup = groupedOrders[group]!;
        
        if (ordersInGroup.isEmpty) {
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
                '${DateGroupingUtils.getDateGroupTitle(group)} (${ordersInGroup.length})',
                style: TextStyle(
                  color: DateGroupingUtils.getDateGroupColor(group),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            // Orders in this group
            ...ordersInGroup.map((order) => _buildDriverOrderCard(order, appState)),
          ],
        );
      },
    );
  }

  // Build individual driver order card
  Widget _buildDriverOrderCard(OrderModel order, AppState appState) {
    final customer = appState.customers.firstWhere(
      (c) => c.id == order.customerId,
      orElse: () => Customer(
        id: '',
        name: 'Unknown Customer',
        phone: '',
        address: '',
        area: '',
        product: '',
        numberOfBottles: 0,
        daysAssigned: [],
        paymentMode: 'Cash',
        bottleRate: 0,
        bottleDeposit: 0,
        lastDelivery: DateTime.now(),
        assignedDriver: null,
        createdAt: PakistanTime.now(),
      ),
    );
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getStatusColor(order.status),
                  child: Text(
                    order.status[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${order.id.length > 8 ? order.id.substring(0, 8) : order.id}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Customer: ${order.customerName ?? customer.name}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(order.status),
                  backgroundColor: _getStatusColor(order.status),
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
                      Builder(
                        builder: (context) {
                          final status = StatusUtils.normalizeStatus(order.status);
                          if (status == 'Delivered') {
                            // For delivered orders: show bottles, total price, and collected price
                            final totalPrice = (order.price + (order.salesTax ?? 0)) * order.quantity;
                            
                            // Use amountCollected from order (fast) or sum payments (fallback)
                            int collectedSum = order.amountCollected ?? 0;
                            
                            // If amountCollected is 0 or null, fall back to summing payments
                            if (collectedSum == 0) {
                              final relatedPayments = appState.payments.where((p) => p.orderId == order.id).toList();
                              collectedSum = relatedPayments
                                  .where((p) => p.amount > 0)
                                  .fold<int>(0, (sum, p) => sum + p.amount);
                            }
                            
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Bottles: ${order.quantity}'),
                                Text('Total Price: Rs. $totalPrice'),
                                Text('Collected: Rs. $collectedSum'),
                              ],
                            );
                          } else {
                            // For pending orders: show per bottle price
                            final customer = appState.customers.firstWhere(
                              (c) => c.id == order.customerId,
                              orElse: () => Customer(
                                id: '', name: '', phone: '', address: '', area: '', product: '',
                                numberOfBottles: 0, daysAssigned: [], paymentMode: 'Cash',
                                bottleRate: 0, bottleDeposit: 0, lastDelivery: DateTime.now(),
                                assignedDriver: null, createdAt: PakistanTime.now(),
                              ),
                            );
                            return Text('Per Bottle Price: Rs. ${customer.bottleRate}');
                          }
                        },
                      ),
                      Text('Date: ${DateGroupingUtils.formatDate(order.orderDate)}'),
                    ],
                  ),
                ),
                if (StatusUtils.normalizeStatus(order.status) != 'Delivered')
                  ElevatedButton(
                    onPressed: () => _showBottlesRefilledDialog(context, order, appState),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Next'),
                  ),
              ],
            ),
            if (order.notes != null && order.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Notes: ${order.notes}',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showBottlesRefilledDialog(BuildContext context, OrderModel order, AppState appState) {
    final bottlesRefilledController = TextEditingController();
    
    // Get customer to access bottleRate
    final customer = appState.customers.firstWhere(
      (c) => c.id == order.customerId,
      orElse: () => Customer(
        id: '',
        name: '',
        phone: '',
        address: '',
        area: '',
        product: '',
        numberOfBottles: 0,
        daysAssigned: [],
        paymentMode: 'Cash',
        bottleRate: 0,
        bottleDeposit: 0,
        lastDelivery: DateTime.now(),
        assignedDriver: null,
        createdAt: PakistanTime.now(),
      ),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bottles Refilled'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: bottlesRefilledController,
              decoration: const InputDecoration(
                labelText: 'Enter number of bottles refilled',
                hintText: 'Enter bottles refilled',
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue[600], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Rate: Rs. ${customer.bottleRate} per bottle',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final bottlesRefilledText = bottlesRefilledController.text.trim();
              if (bottlesRefilledText.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter bottles refilled'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final bottlesRefilled = int.tryParse(bottlesRefilledText);
              if (bottlesRefilled == null || bottlesRefilled <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid number of bottles'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context);
              
              // Calculate amount from rate * bottles refilled
              final calculatedAmount = customer.bottleRate * bottlesRefilled;
              
              // Show payment dialog with calculated amount
              _showPaymentMethodDialog(context, order, appState, bottlesRefilled, calculatedAmount);
            },
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }

  void _showPaymentMethodDialog(BuildContext context, OrderModel order, AppState appState, int bottlesRefilled, int calculatedAmount) {
    String selectedPaymentMethod = 'Cash';
    String bankName = '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Payment Method'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Show calculated amount
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Bottles Refilled:',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text('$bottlesRefilled'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Amount to Collect:',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Flexible(
                          child: Text(
                            'Rs. $calculatedAmount',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Please select the payment method:'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedPaymentMethod,
                decoration: const InputDecoration(labelText: 'Payment Method'),
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'Easypaisa/Jazzcash', child: Text('Easypaisa/Jazzcash')),
                  DropdownMenuItem(value: 'Bank Account', child: Text('Bank Account')),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedPaymentMethod = value!;
                  });
                },
              ),
              if (selectedPaymentMethod == 'Bank Account') ...[
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(labelText: 'Bank Name'),
                  onChanged: (value) => bankName = value,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Validate bank name if Bank Account is selected
                if (selectedPaymentMethod == 'Bank Account' && bankName.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter bank name for bank account payment'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Close payment method dialog
                Navigator.pop(context);
                
                // Show amount collected dialog
                _showAmountCollectedDialog(context, order, appState, selectedPaymentMethod, bankName, calculatedAmount, bottlesRefilled);
              },
              child: const Text('Next'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAmountCollectedDialog(BuildContext context, OrderModel order, AppState appState, String selectedPaymentMethod, String bankName, int calculatedAmount, int bottlesRefilled) async {
    final paymentAmountController = TextEditingController();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Amount Collected'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Amount to Collect:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Rs. $calculatedAmount',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Payment Method:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(selectedPaymentMethod),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: paymentAmountController,
              decoration: const InputDecoration(
                labelText: 'Amount Collected (Rs.)',
                hintText: 'Enter amount collected',
                helperText: 'Amount collected by driver',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amountText = paymentAmountController.text.trim();
              if (amountText.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter the amount collected'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 3),
                  ),
                );
                return;
              }

              final paymentAmount = int.tryParse(amountText);
              if (paymentAmount == null || paymentAmount < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid amount'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 3),
                  ),
                );
                return;
              }

              Navigator.pop(context);
              await _completeDeliveryWithAmountNewFlow(context, order, appState, selectedPaymentMethod, bankName, paymentAmount, calculatedAmount, bottlesRefilled);
            },
            child: const Text('Complete Delivery'),
          ),
        ],
      ),
    );
  }

  Future<void> _completeDeliveryWithAmountNewFlow(BuildContext context, OrderModel order, AppState appState, String selectedPaymentMethod, String bankName, int paymentAmount, int calculatedAmount, int bottlesRefilled) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    // Get customer to pass to auto order creation
    final customer = appState.customers.firstWhere(
      (c) => c.id == order.customerId,
      orElse: () => Customer(
        id: '',
        name: '',
        phone: '',
        address: '',
        area: '',
        product: '',
        numberOfBottles: 0,
        daysAssigned: [],
        paymentMode: 'Cash',
        bottleRate: 0,
        bottleDeposit: 0,
        lastDelivery: DateTime.now(),
        assignedDriver: null,
        createdAt: PakistanTime.now(),
      ),
    );
                
    // Show loading indicator
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 16),
            Text('Completing delivery...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      // Validate bank name if Bank Account is selected
      if (selectedPaymentMethod == 'Bank Account' && bankName.trim().isEmpty) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Please enter bank name for bank account payment'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Update order status to delivered
      await FirebaseService.updateOrderStatus(order.id, 'Delivered');
      
      // Update order quantity
      await FirebaseService.updateOrder(order.id, {
        'quantity': bottlesRefilled,
      });
      
      // Create payment record with the actual amount paid
      await FirebaseService.createPaymentWithOrder(
        orderId: order.id,
        amount: paymentAmount,
        paymentMethod: selectedPaymentMethod,
        customerId: order.customerId,
        quantity: bottlesRefilled,
        price: order.price + (order.salesTax ?? 0),
        collectedBy: appState.currentUser?.name,
        notes: 'Payment collected via $selectedPaymentMethod${bankName.isNotEmpty ? ' ($bankName)' : ''}',
        customerName: order.customerName,
      );

      // If payment amount is less than calculated amount, create a credit record
      if (paymentAmount < calculatedAmount) {
        final remainingAmount = calculatedAmount - paymentAmount;
        await FirebaseService.createPaymentWithOrder(
          orderId: order.id,
          amount: -remainingAmount,
          paymentMethod: 'Credit',
          customerId: order.customerId,
          quantity: bottlesRefilled,
          price: order.price + (order.salesTax ?? 0),
          collectedBy: 'System',
          notes: 'Credit balance - remaining amount from order',
          customerName: order.customerName,
        );
      }

      // Create auto orders for next week based on customer's delivery schedule
      await _createNextWeekAutoOrders(context, order, appState, bottlesRefilled, customer);

      // Refresh data
      await appState.setupAuthListener();
      
      if (context.mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(paymentAmount >= calculatedAmount 
                ? 'Delivery completed successfully!' 
                : 'Delivery completed! Rs. ${calculatedAmount - paymentAmount} added to customer credit.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error completing delivery: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createNextWeekAutoOrders(BuildContext context, OrderModel order, AppState appState, int bottlesRefilled, Customer customer) async {
    try {
      // Get customer's delivery schedule
      if (customer.daysAssigned.isEmpty || customer.assignedDriver == null) {
        return; // No schedule or no driver assigned
      }

      // Check if auto orders already exist for this customer
      final existingAutoOrders = appState.autoOrders.where((ao) => 
        ao.customerId == customer.id && ao.isActive
      ).toList();

      // If auto orders already exist, don't create duplicates
      if (existingAutoOrders.isNotEmpty) {
        return;
      }

      // Create auto orders for each scheduled day
      for (String day in customer.daysAssigned) {
        final nextDeliveryDate = AutoOrder.getNextDeliveryDate(day);
        
        final autoOrder = AutoOrder(
          id: '${customer.id}_${day}_${DateTime.now().millisecondsSinceEpoch}',
          customerId: customer.id,
          customerName: customer.name,
          customerPhone: customer.phone,
          customerArea: customer.area,
          quantity: bottlesRefilled, // Use the bottles delivered
          price: customer.bottleRate,
          salesTax: 0,
          assignedDriver: customer.assignedDriver!,
          dayOfWeek: day,
          nextDeliveryDate: nextDeliveryDate,
          isActive: true,
          notes: 'Auto-generated from delivery on ${DateTime.now().toIso8601String()}',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          companyId: appState.currentUser?.companyId,
        );

        await FirebaseService.createAutoOrder(autoOrder);
      }

    } catch (e) {
      // Don't throw - don't want to fail the delivery completion
    }
  }

  void _showDeliveryCompletionDialog(BuildContext context, OrderModel order, AppState appState) {
    String selectedPaymentMethod = 'Cash';
    String bankName = '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Complete Delivery'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please select the payment method:'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedPaymentMethod,
                decoration: const InputDecoration(labelText: 'Payment Method'),
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'Easypaisa/Jazzcash', child: Text('Easypaisa/Jazzcash')),
                  DropdownMenuItem(value: 'Bank Account', child: Text('Bank Account')),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedPaymentMethod = value!;
                  });
                },
              ),
              if (selectedPaymentMethod == 'Bank Account') ...[
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(labelText: 'Bank Name'),
                  onChanged: (value) => bankName = value,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Validate bank name if Bank Account is selected
                if (selectedPaymentMethod == 'Bank Account' && bankName.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter bank name for bank account payment'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Close payment method dialog
                Navigator.pop(context);
                
                // Show payment amount dialog immediately
                _showPaymentAmountDialog(context, order, appState, selectedPaymentMethod, bankName);
              },
              child: const Text('Next'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPaymentAmountDialog(BuildContext context, OrderModel order, AppState appState, String selectedPaymentMethod, String bankName) async {
    final paymentAmountController = TextEditingController();
    final orderTotal = (order.price + (order.salesTax ?? 0)) * order.quantity;
    
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent auto-close on outside tap
      builder: (context) => AlertDialog(
        title: const Text('Payment Amount'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue[600], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Order Total: Rs. $orderTotal',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: paymentAmountController,
              decoration: InputDecoration(
                labelText: 'Amount Customer is Paying (Rs.)',
                hintText: 'Enter amount customer is paying now',
                helperText: 'Remaining amount will be added to customer credit',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.attach_money),
              ),
              keyboardType: TextInputType.number,
              autofocus: true, // Auto-focus on the input field
              onChanged: (value) {
                // Update UI when text changes
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amountText = paymentAmountController.text.trim();
              if (amountText.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter the payment amount'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 3),
                  ),
                );
                return;
              }

              final paymentAmount = int.tryParse(amountText);
              if (paymentAmount == null || paymentAmount < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid payment amount'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 3),
                  ),
                );
                return;
              }

              Navigator.pop(context);
              await _completeDeliveryWithAmount(context, order, appState, selectedPaymentMethod, bankName, paymentAmount, orderTotal);
            },
            child: const Text('Complete Delivery'),
          ),
        ],
      ),
    );
  }

  Future<void> _completeDeliveryWithAmount(BuildContext context, OrderModel order, AppState appState, String selectedPaymentMethod, String bankName, int paymentAmount, int orderTotal) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
                
                // Show loading indicator
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 16),
                        Text('Completing delivery...'),
                      ],
                    ),
                    duration: Duration(seconds: 2),
                  ),
                );

                try {
                  // Validate bank name if Bank Account is selected
                  if (selectedPaymentMethod == 'Bank Account' && bankName.trim().isEmpty) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Please enter bank name for bank account payment'),
            backgroundColor: Colors.red,
          ),
                    );
                    return;
                  }

      // Update order status to delivered
      await FirebaseService.updateOrderStatus(order.id, 'Delivered');
                  
      // Create payment record with the actual amount paid
                  await FirebaseService.createPaymentWithOrder(
                    orderId: order.id,
        amount: paymentAmount, // Use actual amount paid, not total
        paymentMethod: selectedPaymentMethod,
                    customerId: order.customerId,
                    quantity: order.quantity,
        price: order.price + (order.salesTax ?? 0),
                    collectedBy: appState.currentUser?.name,
        notes: 'Payment collected via $selectedPaymentMethod${bankName.isNotEmpty ? ' ($bankName)' : ''}',
      );

      // If payment amount is less than order total, create a credit record
      if (paymentAmount < orderTotal) {
        final remainingAmount = orderTotal - paymentAmount;
        await FirebaseService.createPaymentWithOrder(
          orderId: order.id,
          amount: -remainingAmount, // Negative amount for credit
          paymentMethod: 'Credit',
          customerId: order.customerId,
          quantity: order.quantity,
          price: order.price + (order.salesTax ?? 0),
          collectedBy: 'System',
          notes: 'Credit balance - remaining amount from order',
          customerName: order.customerName,
        );
      }

      // Refresh data
                  await appState.setupAuthListener();
                  
      if (context.mounted) {
                  scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(paymentAmount >= orderTotal 
                ? 'Delivery completed successfully!' 
                : 'Delivery completed! Rs. ${orderTotal - paymentAmount} added to customer credit.'),
                      backgroundColor: Colors.green,
                    ),
                  );
      }
                } catch (e) {
      if (context.mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
            content: Text('Error completing delivery: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
    }
  }

}

class DriverCustomersScreen extends StatefulWidget {
  const DriverCustomersScreen({super.key});

  @override
  State<DriverCustomersScreen> createState() => _DriverCustomersScreenState();
}

class _DriverCustomersScreenState extends State<DriverCustomersScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final currentUser = appState.currentUser;
        if (currentUser == null) {
          return const AppShell(
            title: 'My Customers',
            body: Center(child: Text('Please log in')),
          );
        }

        // Get driver's assigned customers based on routes (supports multi-day routing)
        final driverRoutes = appState.routes.values.where((route) => 
          route.assignedDriver != null && route.assignedDriver == currentUser.name
        ).toList();

        final driverCustomers = appState.customers.where((customer) {
          // A customer appears if their area matches any route AND any of their days
          // overlap with the route's days
          for (final route in driverRoutes) {
            final areaMatches = route.areas.any((routeArea) =>
              routeArea.trim().toLowerCase() == customer.area.trim().toLowerCase());
            if (!areaMatches) continue;
            final dayMatches = route.days.any((routeDay) => customer.daysAssigned.contains(routeDay));
            if (dayMatches) return true;
          }
          return false;
        }).toList();

        return AppShell(
          title: 'My Customers',
          body: driverCustomers.isEmpty
              ? const Center(
                  child: Text(
                    'No customers assigned to you yet.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: driverCustomers.length,
                  cacheExtent: 500,
                  itemBuilder: (context, index) {
                    final customer = driverCustomers[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: primaryColor,
                          child: Text(
                            StatusUtils.getInitial(customer.name, fallback: 'C'),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          customer.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Phone: ${customer.phone}'),
                            Text('Area: ${customer.area}'),
                            Text('Address: ${customer.address}'),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Chip(
                                  label: Text('Delivered: ${appState.getCustomerDeliveredBottles(customer.id)}'),
                                  backgroundColor: Colors.green[100],
                                ),
                                Chip(
                                  label: Text('Rate: Rs. ${customer.bottleRate}'),
                                  backgroundColor: Colors.orange[100],
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: ElevatedButton.icon(
                          onPressed: () async {
                            // Find if there's a pending order for this customer
                            OrderModel? pendingOrder;
                            try {
                              pendingOrder = appState.orders.firstWhere(
                                (o) => o.customerId == customer.id && 
                                       StatusUtils.normalizeStatus(o.status) == 'Pending',
                              );
                            } catch (e) {
                              // No pending order found, create one
                              // Send only required fields to Firestore (no id, companyId, or timestamps)
                              final orderData = {
                                'customerId': customer.id,
                                'quantity': 0,
                                'price': customer.bottleRate,
                                'salesTax': 0,
                                'status': 'Pending',
                                'orderDate': FieldValue.serverTimestamp(),
                                'notes': 'Delivery from My Customers',
                                'assignedDriver': currentUser.name,
                              };
                              // Don't wait for the order to be created - just pass customer data directly
                              // The dialog will work with the order regardless of its Firestore ID
                              _showDeliveryDialogForCustomer(context, customer, appState);
                              return;
                            }
                            
                            _showBottlesRefilledDialog(context, pendingOrder!, appState);
                          },
                          icon: const Icon(Icons.local_shipping, size: 20),
                          label: const Text('Deliver'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  void _showDeliveryDialogForCustomer(BuildContext context, Customer customer, AppState appState) {
    // Simplified delivery flow without needing a pre-existing order
    final bottlesRefilledController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bottles Refilled'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: bottlesRefilledController,
              decoration: const InputDecoration(
                labelText: 'Enter number of bottles refilled',
                hintText: 'Enter bottles refilled',
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue[600], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Rate: Rs. ${customer.bottleRate} per bottle',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final bottlesRefilled = int.tryParse(bottlesRefilledController.text);
              if (bottlesRefilled == null || bottlesRefilled <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid number of bottles'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context);
              final calculatedAmount = customer.bottleRate * bottlesRefilled;
              _completeDeliveryDirectly(context, customer, appState, bottlesRefilled, calculatedAmount);
            },
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }

  Future<void> _completeDeliveryDirectly(BuildContext context, Customer customer, AppState appState, int bottlesRefilled, int calculatedAmount) async {
    // Show payment method dialog to complete the delivery
    String selectedPaymentMethod = 'Cash';
    String bankName = '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Payment Method'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Bottles Refilled:',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text('$bottlesRefilled'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Amount to Collect:',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Flexible(
                          child: Text(
                            'Rs. $calculatedAmount',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Please select the payment method:'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Payment Method'),
                isExpanded: true,
                value: selectedPaymentMethod,
                items: const [
                  DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'Easypaisa/Jazzcash', child: Text('Easypaisa/Jazzcash')),
                  DropdownMenuItem(value: 'Bank Account', child: Text('Bank Account')),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedPaymentMethod = value!;
                  });
                },
              ),
              if (selectedPaymentMethod == 'Bank Account') ...[
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(labelText: 'Bank Name'),
                  onChanged: (value) => bankName = value,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showAmountCollectedDialogDirectly(context, customer, appState, selectedPaymentMethod, bankName, bottlesRefilled, calculatedAmount);
              },
              child: const Text('Next'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAmountCollectedDialogDirectly(BuildContext context, Customer customer, AppState appState, String selectedPaymentMethod, String bankName, int bottlesRefilled, int calculatedAmount) {
    final paymentAmountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Amount Collected'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Amount to Collect:',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          'Rs. $calculatedAmount',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Payment Method:',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          selectedPaymentMethod,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: paymentAmountController,
              decoration: const InputDecoration(
                labelText: 'Enter amount collected',
                hintText: 'Enter amount',
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final paymentAmount = int.tryParse(paymentAmountController.text);
              if (paymentAmount == null || paymentAmount < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid amount'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context);
              await _completeDirectDelivery(context, customer, appState, selectedPaymentMethod, bankName, paymentAmount, bottlesRefilled, calculatedAmount);
            },
            child: const Text('Complete Delivery'),
          ),
        ],
      ),
    );
  }

  Future<void> _completeDirectDelivery(BuildContext context, Customer customer, AppState appState, String selectedPaymentMethod, String bankName, int paymentAmount, int bottlesRefilled, int calculatedAmount) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
            
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 16),
            Text('Completing delivery...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      // Validate customer has an ID
      if (customer.id.isEmpty) {
        throw Exception('Customer ID is missing. Please refresh the customer list.');
      }

      if (selectedPaymentMethod == 'Bank Account' && bankName.trim().isEmpty) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Please enter bank name for bank account payment'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Create the order as delivered
      final orderData = {
        'customerId': customer.id,
        'customerName': customer.name,
        'quantity': bottlesRefilled,
        'price': customer.bottleRate,
        'salesTax': 0,
        'status': 'Delivered',
        'orderDate': FieldValue.serverTimestamp(),
        'notes': 'On-demand delivery from My Customers',
        'assignedDriver': appState.currentUser?.name,
        'companyId': appState.currentUser?.companyId,
      };
      
      
      String orderId;
      try {
        orderId = await FirebaseService.createOrder(orderData);
        
        // Validate orderId was created successfully
        if (orderId.isEmpty) {
          throw Exception('Failed to create order: Order ID is empty');
        }
      } catch (e) {
        throw Exception('Failed to create order: $e');
      }
      
      await FirebaseService.createPaymentWithOrder(
        orderId: orderId,
        amount: paymentAmount,
        paymentMethod: selectedPaymentMethod,
        customerId: customer.id,
        quantity: bottlesRefilled,
        price: customer.bottleRate,
        collectedBy: appState.currentUser?.name,
        notes: 'Payment collected via $selectedPaymentMethod${bankName.isNotEmpty ? ' ($bankName)' : ''} - On-demand delivery',
        customerName: customer.name,
      );

      // Persist amountCollected shortcut for immediate accurate display
      await FirebaseService.updateOrder(orderId, {
        'amountCollected': paymentAmount,
      });

      if (paymentAmount < calculatedAmount) {
        final remainingAmount = calculatedAmount - paymentAmount;
        await FirebaseService.createPaymentWithOrder(
          orderId: orderId,
          amount: -remainingAmount,
          paymentMethod: 'Credit',
          customerId: customer.id,
          quantity: bottlesRefilled,
          price: customer.bottleRate,
          collectedBy: 'System',
          notes: 'Credit balance - remaining amount from order',
          customerName: customer.name,
        );
      }

      // Note: We don't create auto orders for on-demand deliveries from My Customers
      // Auto orders are only created for scheduled deliveries (from My Deliveries screen)
      await appState.setupAuthListener();
      
      if (context.mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(paymentAmount >= calculatedAmount 
                ? 'Delivery completed successfully!' 
                : 'Delivery completed! Rs. ${calculatedAmount - paymentAmount} added to customer credit.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error completing delivery: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showBottlesRefilledDialog(BuildContext context, OrderModel order, AppState appState) {
    // This is the same method from _DriverOrdersScreenState - reusing the delivery flow
    final bottlesRefilledController = TextEditingController();
    
    // Get customer to access bottleRate
    final customer = appState.customers.firstWhere(
      (c) => c.id == order.customerId,
      orElse: () => Customer(
        id: '',
        name: '',
        phone: '',
        address: '',
        area: '',
        product: '',
        numberOfBottles: 0,
        daysAssigned: [],
        paymentMode: 'Cash',
        bottleRate: 0,
        bottleDeposit: 0,
        lastDelivery: DateTime.now(),
        assignedDriver: null,
        createdAt: PakistanTime.now(),
      ),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bottles Refilled'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: bottlesRefilledController,
              decoration: const InputDecoration(
                labelText: 'Enter number of bottles refilled',
                hintText: 'Enter bottles refilled',
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue[600], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Rate: Rs. ${customer.bottleRate} per bottle',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final bottlesRefilled = int.tryParse(bottlesRefilledController.text);
              if (bottlesRefilled == null || bottlesRefilled <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid number of bottles'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context); // Close this dialog
              
              // Calculate amount
              final calculatedAmount = customer.bottleRate * bottlesRefilled;
              
              // Show next dialog (payment method) using the helper method
              _showPaymentMethodDialogFromCustomers(context, order, appState, bottlesRefilled, calculatedAmount);
            },
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }

  void _showPaymentMethodDialogFromCustomers(BuildContext context, OrderModel order, AppState appState, int bottlesRefilled, int calculatedAmount) {
    String selectedPaymentMethod = 'Cash';
    String bankName = '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Payment Method'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Bottles Refilled:',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text('$bottlesRefilled'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Amount to Collect:',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Flexible(
                          child: Text(
                            'Rs. $calculatedAmount',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Please select the payment method:'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Payment Method'),
                isExpanded: true,
                value: selectedPaymentMethod,
                items: const [
                  DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'Easypaisa/Jazzcash', child: Text('Easypaisa/Jazzcash')),
                  DropdownMenuItem(value: 'Bank Account', child: Text('Bank Account')),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedPaymentMethod = value!;
                  });
                },
              ),
              if (selectedPaymentMethod == 'Bank Account') ...[
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(labelText: 'Bank Name'),
                  onChanged: (value) => bankName = value,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showAmountCollectedDialogFromCustomers(context, order, appState, selectedPaymentMethod, bankName, bottlesRefilled, calculatedAmount);
              },
              child: const Text('Next'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAmountCollectedDialogFromCustomers(BuildContext context, OrderModel order, AppState appState, String selectedPaymentMethod, String bankName, int bottlesRefilled, int calculatedAmount) {
    final paymentAmountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Amount Collected'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Amount to Collect:',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          'Rs. $calculatedAmount',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Payment Method:',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          selectedPaymentMethod,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: paymentAmountController,
              decoration: const InputDecoration(
                labelText: 'Enter amount collected',
                hintText: 'Enter amount',
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final paymentAmount = int.tryParse(paymentAmountController.text);
              if (paymentAmount == null || paymentAmount < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid amount'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context);
              await _completeDeliveryFromCustomers(context, order, appState, selectedPaymentMethod, bankName, paymentAmount, calculatedAmount, bottlesRefilled);
            },
            child: const Text('Complete Delivery'),
          ),
        ],
      ),
    );
  }

  Future<void> _completeDeliveryFromCustomers(BuildContext context, OrderModel order, AppState appState, String selectedPaymentMethod, String bankName, int paymentAmount, int calculatedAmount, int bottlesRefilled) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
            
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 16),
            Text('Completing delivery...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      if (selectedPaymentMethod == 'Bank Account' && bankName.trim().isEmpty) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Please enter bank name for bank account payment'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Update order status to delivered
      await FirebaseService.updateOrderStatus(order.id, 'Delivered');
      
      // Update order quantity
      await FirebaseService.updateOrder(order.id, {
        'quantity': bottlesRefilled,
      });
      
      await FirebaseService.createPaymentWithOrder(
        orderId: order.id,
        amount: paymentAmount,
        paymentMethod: selectedPaymentMethod,
        customerId: order.customerId,
        quantity: bottlesRefilled,
        price: order.price + (order.salesTax ?? 0),
        collectedBy: appState.currentUser?.name,
        notes: 'Payment collected via $selectedPaymentMethod${bankName.isNotEmpty ? ' ($bankName)' : ''}',
        customerName: order.customerName,
      );

      if (paymentAmount < calculatedAmount) {
        final remainingAmount = calculatedAmount - paymentAmount;
        await FirebaseService.createPaymentWithOrder(
          orderId: order.id,
          amount: -remainingAmount,
          paymentMethod: 'Credit',
          customerId: order.customerId,
          quantity: bottlesRefilled,
          price: order.price + (order.salesTax ?? 0),
          collectedBy: 'System',
          notes: 'Credit balance - remaining amount from order',
          customerName: order.customerName,
        );
      }

      // Note: We don't create auto orders for on-demand deliveries from My Customers
      // Auto orders are only created for scheduled deliveries (from My Deliveries screen)
      await appState.setupAuthListener();
      
      if (context.mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(paymentAmount >= calculatedAmount 
                ? 'Delivery completed successfully!' 
                : 'Delivery completed! Rs. ${calculatedAmount - paymentAmount} added to customer credit.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error completing delivery: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class DriverRouteScreen extends StatelessWidget {
  const DriverRouteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final currentUser = appState.currentUser;
        if (currentUser == null) {
          return const AppShell(
            title: 'My Route',
            body: Center(child: Text('Please log in')),
          );
        }

        // Get driver's assigned routes
        final driverRoutes = appState.routes.values.where((route) {
          return route.assignedDriver == currentUser.name;
        }).toList();

        return AppShell(
          title: 'My Route',
          body: driverRoutes.isEmpty
              ? const Center(
                  child: Text(
                    'No routes assigned to you yet.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: driverRoutes.length,
                  cacheExtent: 500,
                  itemBuilder: (context, index) {
                    final route = driverRoutes[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.route, color: Colors.blue, size: 32),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${route.days.join(', ')} Route',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${route.areas.length} areas assigned',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Chip(
                                  label: const Text('Active'),
                                  backgroundColor: Colors.green[100],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Assigned Areas:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: route.areas.map((area) => Chip(
                                label: Text(area),
                                backgroundColor: Colors.blue[100],
                              )).toList(),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
