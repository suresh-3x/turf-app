import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Provider;

import '../models/service.dart';
import '../models/slot.dart';

final vendorServiceProvider = Provider((ref) => VendorService());

final allServicesProvider = FutureProvider<List<Service>>((ref) async {
  return ref.watch(vendorServiceProvider).getAllServices();
});

final serviceProvider = FutureProvider.family<Service, String>((ref, id) async {
  return ref.watch(vendorServiceProvider).getServiceById(id);
});

final slotsProvider = FutureProvider.family<List<Slot>, String>((ref, serviceId) async {
  return ref.watch(vendorServiceProvider).getAvailableSlots(serviceId);
});

final vendorServicesProvider = FutureProvider.family<List<Service>, String>((ref, vendorId) async {
  return ref.watch(vendorServiceProvider).getVendorServices(vendorId);
});

final serviceSlotsProvider = FutureProvider.family<List<Slot>, String>((ref, serviceId) async {
  return ref.watch(vendorServiceProvider).getAllSlots(serviceId);
});

class VendorService {
  final _supabase = Supabase.instance.client;

  // Fetch all services for customer browsing
  Future<List<Service>> getAllServices() async {
    final response = await _supabase.from('services').select();
    return (response as List)
        .map((json) => Service(
              id: json['id'].toString(),
              vendorId: json['vendor_id'].toString(),
              name: json['name'] ?? '',
              description: json['description'] ?? '',
              category: json['category'] ?? '',
              location: json['location'] ?? '',
            ))
        .toList();
  }

  // Fetch services for a vendor
  Future<List<Service>> getVendorServices(String vendorId) async {
    final response = await _supabase.from('services').select().eq('vendor_id', vendorId);
    return (response as List)
        .map((json) => Service(
              id: json['id'].toString(),
              vendorId: json['vendor_id'].toString(),
              name: json['name'] ?? '',
              description: json['description'] ?? '',
              category: json['category'] ?? '',
              location: json['location'] ?? '',
            ))
        .toList();
  }

  // Create a new service
  Future<void> createService(Service service) async {
    await _supabase.from('services').insert({
      'vendor_id': service.vendorId,
      'name': service.name,
      'description': service.description,
      'category': service.category,
      'location': service.location,
    });
  }

  // Update a service
  Future<void> updateService(Service service) async {
    await _supabase.from('services').update({
      'name': service.name,
      'description': service.description,
      'category': service.category,
      'location': service.location,
    }).eq('id', service.id);
  }

  Future<Service> getServiceById(String id) async {
    final response = await _supabase.from('services').select().eq('id', id).single();
    return Service(
      id: response['id'].toString(),
      vendorId: response['vendor_id'].toString(),
      name: response['name'] ?? '',
      description: response['description'] ?? '',
      category: response['category'] ?? '',
      location: response['location'] ?? '',
    );
  }

  Future<List<Slot>> getAvailableSlots(String serviceId) async {
    final response = await _supabase.from('slots').select().eq('service_id', serviceId).eq('is_booked', false);
    return (response as List)
        .map((json) => Slot(
              id: json['id'].toString(),
              serviceId: json['service_id'].toString(),
              startTime: DateTime.parse(json['start_time']),
              endTime: DateTime.parse(json['end_time']),
              isBooked: json['is_booked'] ?? false,
            ))
        .toList();
  }

  // Fetch all slots for a service (including booked)
  Future<List<Slot>> getAllSlots(String serviceId) async {
    final response = await _supabase.from('slots').select().eq('service_id', serviceId);
    return (response as List)
        .map((json) => Slot(
              id: json['id'].toString(),
              serviceId: json['service_id'].toString(),
              startTime: DateTime.parse(json['start_time']),
              endTime: DateTime.parse(json['end_time']),
              isBooked: json['is_booked'] ?? false,
            ))
        .toList();
  }

  // Create a new slot
  Future<void> createSlot({
    required String serviceId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    await _supabase.from('slots').insert({
      'service_id': serviceId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'is_booked': false,
    });
  }
} 