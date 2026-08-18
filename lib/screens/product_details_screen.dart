import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/types.dart';
import '../theme.dart';
import '../widgets/naba_widgets.dart';
import 'package:provider/provider.dart';
import '../providers/catalog_provider.dart';
import '../providers/auth_provider.dart';

class ProductDetailsScreen extends StatefulWidget {
  final CatalogItem product;

  const ProductDetailsScreen({super.key, required this.product});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  void _showRatingDialog() {
    double selectedRating = 5;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تقييم المنتج'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('ما تقييمك لهذا المنتج؟'),
                const SizedBox(height: 16),
                StatefulBuilder(
                  builder: (context, setState) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          icon: Icon(
                            index < selectedRating
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.orange,
                            size: 32,
                          ),
                          onPressed: () {
                            setState(() {
                              selectedRating = index + 1.0;
                            });
                          },
                        );
                      }),
                    );
                  }
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: commentController,
                  decoration: const InputDecoration(
                    hintText: 'اكتب تعليقك هنا (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final auth = Provider.of<AuthProvider>(context, listen: false);
                  final review = Review(
                    id: 'rev_${DateTime.now().millisecondsSinceEpoch}',
                    reviewerUserId: auth.user!.id,
                    reviewedUserId: widget.product.sellerUserId,
                    stars: selectedRating.toInt(),
                    comment: commentController.text,
                    relatedType: 'product',
                    relatedId: widget.product.id,
                    createdAt: DateTime.now(),
                  );
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('شكراً لتقييمك!')),
                  );
                  Navigator.pop(context);
                },
                child: const Text('إرسال التقييم'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NabaTheme.background,
      appBar: const NabaAppBar(title: 'تفاصيل المنتج'),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 250,
                color: Colors.white,
                child: widget.product.photoUrl != null
                    ? Image.memory(
                        base64Decode(widget.product.photoUrl!),
                        fit: BoxFit.cover,
                      )
                    : const Icon(Icons.image_not_supported, size: 80, color: Colors.grey),
              ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            widget.product.name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: NabaTheme.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          '${widget.product.price} ج.م',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: NabaTheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: NabaTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.product.category,
                            style: const TextStyle(color: NabaTheme.primary, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.star, color: Colors.orange, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          widget.product.ratingAvg > 0 ? widget.product.ratingAvg.toStringAsFixed(1) : 'لا يوجد تقييم',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (widget.product.ratingCount > 0)
                          Text(' (${widget.product.ratingCount})', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'مواصفات المنتج',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: NabaTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.product.description != null && widget.product.description!.isNotEmpty
                          ? widget.product.description!
                          : 'لا توجد مواصفات إضافية مسجلة لهذا المنتج.',
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Consumer<AuthProvider>(
                      builder: (context, auth, _) {
                        if (auth.user?.role == UserRole.farmer) {
                          return Center(
                            child: OutlinedButton.icon(
                              onPressed: _showRatingDialog,
                              icon: const Icon(Icons.star_rate_rounded),
                              label: const Text('تقييم هذا المنتج'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.orange,
                                side: const BorderSide(color: Colors.orange),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
