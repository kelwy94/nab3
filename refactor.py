import codecs
import re

with codecs.open('lib/screens/marketplace_screen.dart', 'r', 'utf-8') as f:
    text = f.read()

# Refactor the build() method
# Find the start of build()
start_idx = text.find('Widget build(BuildContext context) {')
# Find the end of build() which is right before void _showFilterBottomSheet
end_idx = text.find('void _showFilterBottomSheet(BuildContext context) {')

build_content = text[start_idx:end_idx]

# Replace Column with CustomScrollView
# The structure is Scaffold -> body: SafeArea -> child: Column(children: [
new_build_content = build_content.replace(
    'child: Column(',
    'child: CustomScrollView(\n          slivers: [\n            SliverToBoxAdapter(\n              child: Column('
)
# Now we need to find `Expanded(child: _buildProductGrid()),` and replace it with closing the SliverToBoxAdapter and adding `_buildProductGrid()` directly since we'll make it return a Sliver.
new_build_content = new_build_content.replace(
    'Expanded(child: _buildProductGrid()),',
    ']\n              ),\n            ),\n            _buildProductGrid(),'
)
# Also fix the right overflow in the AppBar:
# The user's name Row:
# children: [ Consumer<AuthProvider>(... avatar ...), SizedBox(width: 12), Column( ... name ... ) ]
# We need to wrap the Column in an Expanded.
# Let's find the Column with crossAxisAlignment: CrossAxisAlignment.start and the text 'السوق' (which shows as ?????).
# Let's use regex to find this block and wrap it in Expanded.

# Instead of complex regex, let's just make the changes using script reading lines.
