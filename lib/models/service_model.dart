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
  final String duration;
  final VehicleType vehicleType;
  final String category;

  const ServiceItem({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    required this.duration,
    required this.vehicleType,
    required this.category,
  });
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
  final double? latitude;
  final double? longitude;
  final String? bookingLocation;

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
    this.latitude,
    this.longitude,
    this.bookingLocation,
  });

  double get totalAmount => selectedServices.fold(0, (sum, item) => sum + item.price);
}
