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

  const ServiceItem({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    required this.duration,
    required this.vehicleType,
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
