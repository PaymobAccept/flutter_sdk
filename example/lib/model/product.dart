import 'package:flutter/cupertino.dart';

class Product {
  final String name;
  final String subtitle;
  final String description;
  final String price;
  final int priceCents;
  final IconData icon;
  final Color color;

  const Product({
    required this.name,
    required this.subtitle,
    required this.description,
    required this.price,
    required this.priceCents,
    required this.icon,
    required this.color,
  });
}
