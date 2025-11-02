import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';

class FirebaseSetup {
  static Future<void> createAllUserProfiles() async {
    try {
      // Create Admin Profile in Firebase Auth
      try {
        final adminCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: 'admin@rathisoft.pk',
          password: 'admin123',
        );
        
        // Create Firestore profile for admin
        await FirebaseFirestore.instance
            .collection('users')
            .doc(adminCredential.user!.uid)
            .set({
          'uid': adminCredential.user!.uid,
          'email': 'admin@rathisoft.pk',
          'name': 'Admin',
          'role': 'admin',
          'phone': '+92 300 0000000',
          'address': 'Admin Office',
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        // Admin user profile created successfully
      } catch (e) {
        // Admin user might already exist
        // Try to find existing admin user
        try {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: 'admin@rathisoft.pk',
            password: 'admin123',
          );
          // Admin user found and can sign in
          await FirebaseAuth.instance.signOut(); // Sign out after verification
        } catch (signInError) {
          // Admin user cannot sign in
        }
      }

      // Create Driver Profile in Firebase Auth
      try {
        final driverCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: 'driver@rathisoft.pk',
          password: '123456',
        );
        
        // Create Firestore profile for driver
        await FirebaseFirestore.instance
            .collection('users')
            .doc(driverCredential.user!.uid)
            .set({
          'uid': driverCredential.user!.uid,
          'email': 'driver@rathisoft.pk',
          'name': 'Driver One',
          'role': 'driver',
          'phone': '+92 301 1111111',
          'address': 'Driver Office',
          'assignedRoute': 'Route A',
          'assignedAreas': ['Area 1', 'Area 2'],
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        // Driver user profile created successfully
      } catch (e) {
        // Driver user might already exist or error occurred
      }

      // Create Employee Profile in Firebase Auth
      try {
        final employeeCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: 'employee@rathisoft.pk',
          password: '123456',
        );
        
        // Create Firestore profile for employee
        await FirebaseFirestore.instance
            .collection('users')
            .doc(employeeCredential.user!.uid)
            .set({
          'uid': employeeCredential.user!.uid,
          'email': 'employee@rathisoft.pk',
          'name': 'Employee One',
          'role': 'employee',
          'phone': '+92 302 2222222',
          'address': 'Employee Office',
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        // Employee user profile created successfully
      } catch (e) {
        // Employee user might already exist or error occurred
      }

      // All user profiles created successfully
    } catch (e) {
      // Error creating user profiles
    }
  }

  static Future<void> setupAdminUser() async {
    try {
      // Create admin user if it doesn't exist
      final adminEmail = 'admin@rathisoft.pk';
      final adminPassword = '123456';
      
      // Try to sign in first
      try {
        await FirebaseService.signInWithEmailAndPassword(
          email: adminEmail,
          password: adminPassword,
        );
        // Admin user already exists and signed in
        return;
      } catch (e) {
        // User doesn't exist, create it
      }
      
      // Create admin user
      final credential = await FirebaseService.createUserWithEmailAndPassword(
        email: adminEmail,
        password: adminPassword,
      );
      
      if (credential?.user != null) {
        // Create admin profile in Firestore
        await FirebaseService.createUserProfile(
          uid: credential!.user!.uid,
          email: adminEmail,
          name: 'Admin',
          role: 'admin',
          phone: '+92 300 0000000',
          address: 'Admin Office',
        );
        
        // Admin user created successfully
      }
    } catch (e) {
      // Error setting up admin user
    }
  }
  
  static Future<void> setupSampleProducts() async {
    try {
      final products = [
        {
          'id': 'product_1',
          'name': 'Premium Water Bottle',
          'size': '1L',
          'price': 300,
          'description': 'High quality purified water',
          'isAvailable': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'product_2',
          'name': 'Standard Water Bottle',
          'size': '500ml',
          'price': 150,
          'description': 'Standard purified water',
          'isAvailable': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'product_3',
          'name': 'Large Water Bottle',
          'size': '2L',
          'price': 500,
          'description': 'Large size purified water',
          'isAvailable': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      ];
      
      for (final productData in products) {
        try {
          await FirebaseFirestore.instance
              .collection('products')
              .doc(productData['id'] as String)
              .set(productData);
        } catch (e) {
          // Error creating product
        }
      }
      
      // Sample products created successfully
    } catch (e) {
      // Error setting up sample products
    }
  }
  
  static Future<void> setupSampleEmployees() async {
    try {
      final employees = [
        {
          'email': 'driver1@rathisoft.pk',
          'password': '123456',
          'name': 'Ali Ahmed',
          'role': 'driver',
          'phone': '+92 300 1111111',
          'assignedAreas': ['Model Town', 'Garden Town'],
        },
        {
          'email': 'driver2@rathisoft.pk',
          'password': '123456',
          'name': 'Hassan Khan',
          'role': 'driver',
          'phone': '+92 300 2222222',
          'assignedAreas': ['Clifton', 'DHA'],
        },
        {
          'email': 'employee1@rathisoft.pk',
          'password': '123456',
          'name': 'Sara Malik',
          'role': 'employee',
          'phone': '+92 300 3333333',
        },
      ];
      
      for (final employeeData in employees) {
        try {
          // Create employee using the proper method that handles sign out
          await FirebaseService.createEmployee(
            name: employeeData['name'] as String,
            email: employeeData['email'] as String,
            password: employeeData['password'] as String,
            role: employeeData['role'] as String,
            phone: employeeData['phone'] as String?,
            address: employeeData['assignedAreas'] != null 
                ? (employeeData['assignedAreas'] as List).join(', ')
                : null,
          );
        } catch (e) {
          // Error creating employee
        }
      }
      
      // Sample employees created successfully
    } catch (e) {
      // Error setting up sample employees
    }
  }
  
  static Future<void> runInitialSetup() async {
    await setupAdminUser();
    await setupSampleProducts();
    await setupSampleEmployees();
    
    // Sign out admin after setup
    await FirebaseService.signOut();
  }
}
