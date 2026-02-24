import 'package:hive/hive.dart';

part 'customer.g.dart';

@HiveType(typeId: 0)
class Customer extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  double amount;

  @HiveField(2)
  String paymentMethod;

  @HiveField(3)
  DateTime createdAt;

  Customer({
    required this.name,
    required this.amount,
    required this.paymentMethod,
    required this.createdAt,
  });
}