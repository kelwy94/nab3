import sys

def main():
    path = r'd:\\antigravity\\nab3_gded\\lib\\screens\\farmer_dashboard.dart'
    with open(path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
        
    start_idx = -1
    end_idx = -1
    
    # Find start
    for i, line in enumerate(lines):
        if '// Quick Actions\n' in line and 'const SizedBox(height: 8),' in lines[i-1]:
            start_idx = i - 1
            break
            
    # Find end
    if start_idx != -1:
        for i in range(start_idx, len(lines)):
            if '// Calendar\n' in lines[i]:
                end_idx = i - 1 # The line before // Calendar, which is const SizedBox(height: 16),
                break

    if start_idx == -1 or end_idx == -1:
        print('Could not find bounds for extraction.')
        return
        
    extracted_lines = lines[start_idx:end_idx]
    
    # We will modify the extracted lines to include "مشترياتي وتتبعها" and "استشارات هندسية"
    # Search inside extracted lines for where the first row ends.
    row_end_idx = -1
    for i, line in enumerate(extracted_lines):
        if '                ),' in line and i > 25: # the end of the children of Row
            row_end_idx = i + 1
            break
            
    if row_end_idx != -1:
        new_row = [
            "                Padding(\n",
            "                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),\n",
            "                  child: Row(\n",
            "                    children: [\n",
            "                      Expanded(\n",
            "                        child: _buildQuickActionCard(\n",
            "                          context,\n",
            "                          title: 'مشترياتي وتتبعها',\n",
            "                          icon: Icons.shopping_bag_rounded,\n",
            "                          color: Colors.teal.shade500,\n",
            "                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersHistoryScreen())),\n",
            "                        ),\n",
            "                      ),\n",
            "                      const SizedBox(width: 12),\n",
            "                      Expanded(\n",
            "                        child: _buildQuickActionCard(\n",
            "                          context,\n",
            "                          title: 'استشارات هندسية',\n",
            "                          icon: Icons.workspace_premium_rounded,\n",
            "                          color: Colors.teal.shade500,\n",
            "                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConsultationMarketScreen())),\n",
            "                        ),\n",
            "                      ),\n",
            "                    ],\n",
            "                  ),\n",
            "                ),\n"
        ]
        
        # We need to find the Padding widget bounds that wraps the first row
        padding_end_idx = -1
        for i in range(row_end_idx, len(extracted_lines)):
            if '              ),' in extracted_lines[i] or '              )' in extracted_lines[i]:
                padding_end_idx = i + 1
                break
                
        if padding_end_idx != -1:
            extracted_lines = extracted_lines[:padding_end_idx] + new_row + extracted_lines[padding_end_idx:]

    new_method = [
        "  Widget _buildQuickActionsAndTracking(BuildContext context, AuthProvider auth) {\n",
        "    return Column(\n",
        "      crossAxisAlignment: CrossAxisAlignment.stretch,\n",
        "      children: [\n"
    ]
    for l in extracted_lines:
        if len(l) > 14:
            new_method.append(l[14:]) # Strip 14 spaces to fix indentation
        else:
            new_method.append(l)
    new_method.append("      ],\n")
    new_method.append("    );\n")
    new_method.append("  }\n\n")

    # Replace extracted lines with function call
    call_line = "              _buildQuickActionsAndTracking(context, auth),\n"
    lines = lines[:start_idx] + [call_line] + lines[end_idx:]
    
    # Now find where to insert the new_method (before `String _getStatusLabel(String status) {`)
    method_idx = -1
    for i, line in enumerate(lines):
        if '  String _getStatusLabel(String status) {' in line:
            method_idx = i
            break
            
    if method_idx != -1:
        lines = lines[:method_idx] + new_method + lines[method_idx:]
        
    # Inject it for "empty wells" branch.
    # Find `onTap: () { Navigator.push( context, MaterialPageRoute( builder: (_) => const WellSearchScreen()));`
    inject_idx = -1
    for i, line in enumerate(lines):
        if 'title: \'التسجيل في بئر\'' in line:
            for j in range(i, i+30):
                if '            ],' in lines[j] and '          ),' in lines[j+1] and '        ),' in lines[j+2]:
                    inject_idx = j
                    break
            break
            
    if inject_idx != -1:
        inject_lines = [
            "              const SizedBox(height: 32),\n",
            "              _buildQuickActionsAndTracking(context, auth),\n"
        ]
        # Insert them right before `            ],`
        lines = lines[:inject_idx] + inject_lines + lines[inject_idx:]
        with open(path, 'w', encoding='utf-8') as f:
            f.writelines(lines)
        print('Successfully refactored.')
    else:
        print('Could not find inject_idx')

if __name__ == '__main__':
    main()
