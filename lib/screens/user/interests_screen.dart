import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import 'home_screen.dart';

class InterestsScreen extends StatefulWidget {
  final bool isEditing;
  const InterestsScreen({super.key, this.isEditing = false});

  @override
  State<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends State<InterestsScreen> {
  final Set<String> _selected = {};
  bool _isSaving = false;

  static const Map<String, List<String>> _categories = {
    'Music': ['Pop', 'Rock', 'Hip-Hop', 'Jazz', 'Classical', 'EDM', 'R&B', 'Country'],
    'Sports': ['Football', 'Basketball', 'Tennis', 'Swimming', 'Gym', 'Running', 'Cycling', 'Yoga'],
    'Arts': ['Photography', 'Painting', 'Drawing', 'Sculpting', 'Design', 'Writing', 'Poetry'],
    'Food': ['Cooking', 'Baking', 'Coffee', 'Wine', 'Vegan', 'Street Food', 'Fine Dining'],
    'Travel': ['Adventure', 'Backpacking', 'Beaches', 'Mountains', 'City Trips', 'Road Trips'],
    'Tech': ['Gaming', 'Coding', 'AI', 'Gadgets', 'Crypto', 'Sci-Fi'],
    'Lifestyle': ['Movies', 'Anime', 'Books', 'Podcasts', 'Meditation', 'Volunteering', 'Pets'],
    'Outdoors': ['Hiking', 'Camping', 'Fishing', 'Surfing', 'Rock Climbing', 'Skiing'],
  };

  static const Map<String, IconData> _categoryIcons = {
    'Music': Icons.music_note,
    'Sports': Icons.sports_soccer,
    'Arts': Icons.palette,
    'Food': Icons.restaurant,
    'Travel': Icons.flight,
    'Tech': Icons.devices,
    'Lifestyle': Icons.self_improvement,
    'Outdoors': Icons.park,
  };

  Future<void> _saveInterests() async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick at least one interest!')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'interests': _selected.toList(),
      });
      await Provider.of<AuthService>(context, listen: false).refreshCurrentUserModel();
      if (!mounted) return;
      if (widget.isEditing) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.deepPurple.shade400,
              Colors.purple.shade700,
              Colors.deepPurple.shade900,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.isEditing)
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        padding: EdgeInsets.zero,
                      ),
                    const SizedBox(height: 8),
                    const Text(
                      'What are you\ninto?',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pick your interests — you\'ll match with people who share them.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_selected.length} selected',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (_selected.isNotEmpty)
                          TextButton(
                            onPressed: () => setState(() => _selected.clear()),
                            child: Text(
                              'Clear all',
                              style: TextStyle(color: Colors.white.withOpacity(0.7)),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories.keys.elementAt(index);
                      final items = _categories[category]!;
                      final icon = _categoryIcons[category] ?? Icons.star;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(icon, size: 18, color: Colors.deepPurple),
                              const SizedBox(width: 8),
                              Text(
                                category,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: items.map((item) {
                              final isSelected = _selected.contains(item);
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      _selected.remove(item);
                                    } else {
                                      _selected.add(item);
                                    }
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.deepPurple
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.deepPurple
                                          : Colors.grey.shade300,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: Colors.deepPurple.withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            )
                                          ]
                                        : [],
                                  ),
                                  child: Text(
                                    item,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.black87,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: SizedBox(
          width: double.infinity,
          child: FloatingActionButton.extended(
            onPressed: _isSaving ? null : _saveInterests,
            backgroundColor: Colors.deepPurple,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            label: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    widget.isEditing ? 'Save Interests' : 'Continue',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
