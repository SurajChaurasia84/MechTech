import '../utils/payment_config.dart';

enum VehicleType {
  car,
  bike,
  ev,
}

extension VehicleTypeExtension on VehicleType {
  String get displayName {
    switch (this) {
      case VehicleType.car:
        return 'Car';
      case VehicleType.bike:
        return 'Bike';
      case VehicleType.ev:
        return 'Electric Vehicle (EV)';
    }
  }
}

class VehicleModel {
  final String name;
  final VehicleType type;

  const VehicleModel({
    required this.name,
    required this.type,
  });
}

class ServiceItem {
  final String id;
  final String name;
  final double price;
  final String description;
  final VehicleType vehicleType;
  final String category;

  const ServiceItem({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    required this.vehicleType,
    required this.category,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServiceItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class JobPost {
  final String id;
  final String mechanicId;
  final String mechanicName;
  final String mechanicPhotoUrl;
  final String title;
  final String rate;
  final String experience;
  final String desc;
  final String location;
  final List<String> categories;
  final List<String> tags;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;
  final String vehicleCategory;
  final Map<String, int> specializationRates;
  final Map<String, List<Map<String, dynamic>>> specializationSubCategories;
  final String? vehicleModel;

  JobPost({
    required this.id,
    required this.mechanicId,
    required this.mechanicName,
    required this.mechanicPhotoUrl,
    required this.title,
    required this.rate,
    required this.experience,
    required this.desc,
    required this.location,
    required this.categories,
    required this.tags,
    this.latitude,
    this.longitude,
    required this.createdAt,
    required this.vehicleCategory,
    this.specializationRates = const {},
    this.specializationSubCategories = const {},
    this.vehicleModel,
  });
}

class ServiceBooking {
  final String id;
  final String customerName;
  final String? customerId;
  final String? customerPhone;
  final String? customerEmail;
  final VehicleType vehicleType;
  final String vehicleModel;
  final List<ServiceItem> selectedServices;
  final DateTime bookingDate;
  final String status;
  final String? mechanicId;
  final String? mechanicName;
  final String? mechanicPhotoUrl;
  final double? latitude;
  final double? longitude;
  final String? bookingLocation;
  final String? paymentId;
  final String? paymentStatus;
  final double discount;

  ServiceBooking({
    required this.id,
    required this.customerName,
    this.customerId,
    this.customerPhone,
    this.customerEmail,
    required this.vehicleType,
    required this.vehicleModel,
    required this.selectedServices,
    required this.bookingDate,
    this.status = 'Pending',
    this.mechanicId,
    this.mechanicName,
    this.mechanicPhotoUrl,
    this.latitude,
    this.longitude,
    this.bookingLocation,
    this.paymentId,
    this.paymentStatus,
    this.discount = 0.0,
  });

  double get serviceTotal => selectedServices.fold(0.0, (sum, item) => sum + item.price);
  double get commission => serviceTotal * PaymentConfig.commissionRate;
  double get platformFee => PaymentConfig.platformFee;
  double get totalAmount => (serviceTotal + platformFee - discount).clamp(0.0, double.infinity);
  double get mechanicEarnings => serviceTotal - commission;
}
