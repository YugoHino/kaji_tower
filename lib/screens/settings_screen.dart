
import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isRaisingChildren = false;
  final List<Map<String, dynamic>> _familyMembers = [];

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  String? _selectedGender;
  String? _selectedRelationship;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _addFamilyMember() {
    if (_nameController.text.isNotEmpty &&
        _ageController.text.isNotEmpty &&
        _selectedGender != null &&
        _selectedRelationship != null) {
      setState(() {
        _familyMembers.add({
          'name': _nameController.text,
          'age': int.parse(_ageController.text),
          'gender': _selectedGender,
          'relationship': _selectedRelationship,
        });
        _nameController.clear();
        _ageController.clear();
        _selectedGender = null;
        _selectedRelationship = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Raising Children Option
        SwitchListTile(
          title: const Text('育児をしている'),
          value: _isRaisingChildren,
          onChanged: (bool value) {
            setState(() {
              _isRaisingChildren = value;
            });
          },
        ),
        const Divider(),

        // Family Composition Section
        Text(
          '家族構成',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),

        // Add Family Member Form
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: '名前'),
        ),
        TextField(
          controller: _ageController,
          decoration: const InputDecoration(labelText: '年齢'),
          keyboardType: TextInputType.number,
        ),
        DropdownButtonFormField<String>(
          value: _selectedGender,
          hint: const Text('性別'),
          items: <String>['男性', '女性', 'その他']
              .map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedGender = newValue;
            });
          },
        ),
        DropdownButtonFormField<String>(
          value: _selectedRelationship,
          hint: const Text('関係性'),
          items: <String>['夫', '妻', '実父母', '義父母', '子ども', '親戚']
              .map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedRelationship = newValue;
            });
          },
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _addFamilyMember,
          child: const Text('家族メンバーを追加'),
        ),
        const SizedBox(height: 24),

        // List of Family Members
        Text(
          '登録済みの家族メンバー',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        _familyMembers.isEmpty
            ? const Text('まだ家族メンバーが登録されていません。')
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _familyMembers.length,
                itemBuilder: (context, index) {
                  final member = _familyMembers[index];
                  return ListTile(
                    title: Text('${member['name']} (${member['age']}歳)'),
                    subtitle: Text('${member['relationship']} - ${member['gender']}'),
                  );
                },
              ),
      ],
    );
  }
}

