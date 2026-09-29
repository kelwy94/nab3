import codecs

with codecs.open('lib/screens/product_details_screen.dart', 'r', 'utf-8', errors='ignore') as f:
    content = f.read()

content = content.replace('    ! ??', 'تمت إضافة المنتج للسلة بنجاح! 🛒')
content = content.replace(' ', 'أضف للسلة')
content = content.replace('      : ', 'شاهد هذا المنتج الرائع على تطبيق نبع: ')
content = content.replace('  ', ' بسعر ')
content = content.replace(' .', ' ج.م')
content = content.replace('      ', 'تطبيق واتساب غير مثبت أو غير متاح')
content = content.replace('', 'مشاركة')
content = content.replace('.', 'ج.م')

with codecs.open('lib/screens/product_details_screen.dart', 'w', 'utf-8') as f:
    f.write(content)
