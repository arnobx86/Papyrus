class Shop {
  final String id;
  final String name;
  final String? phone;
  final String? address;
  final String? logo;
  final String ownerUserId;
  final Map<String, dynamic>? metadata;

  Shop({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.logo,
    required this.ownerUserId,
    this.metadata,
  });

  factory Shop.fromJson(Map<String, dynamic> json) {
    return Shop(
      id: json['id'],
      name: json['name'],
      phone: json['phone'],
      address: json['address'],
      logo: json['logo'],
      ownerUserId: json['owner_user_id'] ?? '',
      metadata: json['metadata'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'logo': logo,
      'owner_user_id': ownerUserId,
      'metadata': metadata,
    };
  }
}
