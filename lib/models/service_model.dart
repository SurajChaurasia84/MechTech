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
  final VehicleType vehicleType;
  final String vehicleModel;
  final List<ServiceItem> selectedServices;
  final DateTime bookingDate;
  final String status;

  ServiceBooking({
    required this.id,
    required this.customerName,
    required this.vehicleType,
    required this.vehicleModel,
    required this.selectedServices,
    required this.bookingDate,
    this.status = 'Pending',
  });

  double get totalAmount => selectedServices.fold(0, (sum, item) => sum + item.price);
}
