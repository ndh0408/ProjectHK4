class TicketType {
  const TicketType({
    required this.id,
    required this.eventId,
    required this.name,
    this.description,
    required this.price,
    this.currency = 'USD',
    required this.quantity,
    required this.soldCount,
    required this.availableQuantity,
    required this.maxPerOrder,
    this.saleStartDate,
    this.saleEndDate,
    required this.isVisible,
    required this.displayOrder,
    required this.status,
    required this.isFree,
  });

  factory TicketType.fromJson(Map<String, dynamic> json) {
    return TicketType(
      id: json['id']?.toString() ?? '',
      eventId: json['eventId']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'USD',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      soldCount: (json['soldCount'] as num?)?.toInt() ?? 0,
      availableQuantity: (json['availableQuantity'] as num?)?.toInt() ?? 0,
      maxPerOrder: (json['maxPerOrder'] as num?)?.toInt() ?? 10,
      saleStartDate: json['saleStartDate'] != null
          ? DateTime.tryParse(json['saleStartDate'] as String)
          : null,
      saleEndDate: json['saleEndDate'] != null
          ? DateTime.tryParse(json['saleEndDate'] as String)
          : null,
      isVisible: json['isVisible'] as bool? ?? true,
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'AVAILABLE',
      isFree: json['isFree'] as bool? ?? ((json['price'] as num?)?.toDouble() ?? 0) == 0,
    );
  }

  final String id;
  final String eventId;
  final String name;
  final String? description;
  final double price;
  final String currency;
  final int quantity;
  final int soldCount;
  final int availableQuantity;
  final int maxPerOrder;
  final DateTime? saleStartDate;
  final DateTime? saleEndDate;
  final bool isVisible;
  final int displayOrder;
  final String status;
  final bool isFree;

  bool get isAvailable => isVisible && availableQuantity > 0;
  bool get isSoldOut => availableQuantity <= 0;
  bool get isNotStarted => false;
  bool get isEnded => false;

  int get maxAllowedPurchase {
    if (!isAvailable) return 0;
    return availableQuantity < maxPerOrder ? availableQuantity : maxPerOrder;
  }
}
