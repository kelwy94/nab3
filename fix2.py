import codecs

with codecs.open('lib/screens/product_details_screen.dart', 'r', 'utf-8') as f:
    content = f.read()

original = '''                        if (auth.user?.role == UserRole.farmer) {
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
}'''

new_text = '''                        if (auth.user?.role == UserRole.farmer) {
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
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.read<AppStateProvider>().addToCart(widget.product);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تمت إضافة المنتج للسلة بنجاح! 🛒'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.shopping_cart_checkout_rounded, color: Colors.white),
                  label: const Text(
                    'أضف للسلة',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NabaTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final url = Uri.parse('whatsapp://send?text=شاهد هذا المنتج الرائع على تطبيق نبع: ' + widget.product.name + ' بسعر ' + widget.product.price.toString() + ' ج.م');
                    try {
                      await launchUrl(url);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تطبيق واتساب غير مثبت أو غير متاح')),
                      );
                    }
                  },
                  icon: const Icon(Icons.share_rounded, color: Colors.teal),
                  label: const Text('مشاركة', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.teal),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}'''

content = content.replace(original, new_text)

# And imports
imports_orig = '''import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';'''
imports_new = '''import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';'''

content = content.replace(imports_orig, imports_new)

with codecs.open('lib/screens/product_details_screen.dart', 'w', 'utf-8') as f:
    f.write(content)
