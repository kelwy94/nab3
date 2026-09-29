import codecs
import re

with codecs.open('lib/screens/product_details_screen.dart', 'r', 'utf-8') as f:
    content = f.read()

# Remove \r
content = content.replace('\r', '')

original_pattern = r'                        return const SizedBox\.shrink\(\);\n                      }\n                    \),\n                  \],\n                \),\n              \),\n            \],\n          \),\n        \),\n      \),\n    \);\n  }\n}'

new_text = '''                        return const SizedBox.shrink();
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

content = re.sub(original_pattern, new_text, content)

imports_orig = r"import '../providers/auth_provider\.dart';"
imports_new = '''import '../providers/app_state_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';'''

content = re.sub(imports_orig, imports_new, content)

with codecs.open('lib/screens/product_details_screen.dart', 'w', 'utf-8') as f:
    f.write(content)
