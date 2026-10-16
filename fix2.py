import codecs
import re
with codecs.open('lib/screens/marketplace_screen.dart', 'r', 'utf-8') as f:
    mc = f.read()

mc = re.sub(r"              Positioned\(\s*bottom:\s*16,\s*left:\s*80,\s*right:\s*80,\s*child:\s*_buildFloatingBottomBar\(\),\s*\),", "", mc)
mc = re.sub(r"  Widget _buildFloatingBottomBar\(\) \{[\s\S]*?  \}\n\n", "", mc)
# one more thing, let's fix Lands tab in farmer dashboard
with codecs.open('lib/screens/farmer_dashboard.dart', 'r', 'utf-8') as f:
    fc = f.read()
fc = re.sub(r"appBar:\s*NabaAppBar\(\s*title:\s*'قطع الأراضي'[\s\S]*?      \),", '''appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: SafeArea(
          child: NabaTopHeader(
            title: 'قطع الأراضي',
            trailing: IconButton(
              icon: const Icon(Icons.add_circle_rounded),
              onPressed: () => _showAddPlotDialog(context),
            ),
          ),
        ),
      ),''', fc)
with codecs.open('lib/screens/marketplace_screen.dart', 'w', 'utf-8') as f:
    f.write(mc)
with codecs.open('lib/screens/farmer_dashboard.dart', 'w', 'utf-8') as f:
    f.write(fc)
print("Removed floating bottom bar and fixed Lands tab")
