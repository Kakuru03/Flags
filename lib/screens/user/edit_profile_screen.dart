import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/storage_service.dart';

class EditProfileScreen extends StatefulWidget {
  final bool isFirstTime;
  const EditProfileScreen({super.key, this.isFirstTime = false});

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final StorageService _storageService = StorageService();

  bool _isPrivate = false;
  bool _isFrozen = false;

  late TextEditingController _displayNameController;
  late TextEditingController _bioController;
  late TextEditingController _interestsController;

  // Store selected images as File (mobile) or Uint8List (web)
  final List<dynamic> _selectedImages = [];
  List<String> _existingImages = [];
  DateTime? _selectedDate;
  String? _selectedGender;
  String? _selectedSeeking;

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isDirty = false;

  String? _initialDisplayName;
  String? _initialBio;
  String? _initialInterestsCsv;
  DateTime? _initialDate;
  String? _initialGender;
  String? _initialSeeking;
  bool _initialPrivate = false;
  List<String> _initialPhotos = [];

  void _recomputeDirty() {
    final display = _displayNameController.text.trim();
    final bio = _bioController.text.trim();
    final interestsCsv = _interestsController.text.trim();

    final interestsNormalized = interestsCsv
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .join(', ');

    final initialInterestsNormalized = (_initialInterestsCsv ?? '')
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .join(', ');

    final initialDateIso = _initialDate?.toIso8601String();
    final selectedDateIso = _selectedDate?.toIso8601String();

    final photosChanged =
        !_listEquals(_existingImages, _initialPhotos) || _selectedImages.isNotEmpty;

    final dirty =
        display != (_initialDisplayName ?? '') ||
            bio != (_initialBio ?? '') ||
            interestsNormalized != initialInterestsNormalized ||
            selectedDateIso != initialDateIso ||
            _selectedGender != _initialGender ||
            _selectedSeeking != _initialSeeking ||
            _isPrivate != _initialPrivate ||
            photosChanged;

    if (_isDirty != dirty) {
      setState(() => _isDirty = dirty);
    }
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<bool> _onWillPop() async {
    if (!_isDirty) return true;
    if (_isLoading || _isSaving) return false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved changes. Save before leaving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop(false);
              await _saveProfile();
            },
            child: const Text('Save'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthService>(context, listen: false).currentUserModel;

    _initialDisplayName = user?.displayName ?? '';
    _initialBio = user?.bio ?? '';
    _initialInterestsCsv = user?.interests.join(', ') ?? '';
    _initialDate = user?.dateOfBirth;
    _initialGender = user?.gender;
    _initialSeeking = user?.seeking;
    _initialPrivate = user?.isPrivate ?? false;
    _initialPhotos = List<String>.from(user?.photos ?? []);
    _isFrozen = user?.isFrozen ?? false;

    _displayNameController = TextEditingController(text: _initialDisplayName);
    _bioController = TextEditingController(text: _initialBio);
    _interestsController = TextEditingController(text: _initialInterestsCsv);

    _selectedDate = _initialDate;
    _selectedGender = _initialGender;
    _selectedSeeking = _initialSeeking;
    _existingImages = List<String>.from(_initialPhotos);
    _isPrivate = _initialPrivate;

    _displayNameController.addListener(_recomputeDirty);
    _bioController.addListener(_recomputeDirty);
    _interestsController.addListener(_recomputeDirty);
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _interestsController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    if (images.isEmpty) return;

    for (final x in images) {
      if (kIsWeb) {
        final bytes = await x.readAsBytes();
        setState(() => _selectedImages.add(bytes));
      } else {
        setState(() => _selectedImages.add(File(x.path)));
      }
    }
    _recomputeDirty();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _recomputeDirty();
    }
  }

  // ===================== ADVANCED SAVE PROFILE =====================
  Future<void> _saveProfile() async {
    // 1. Form validation
    if (!_formKey.currentState!.validate()) return;
    // 2. Prevent multiple simultaneous saves
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
      _isLoading = true;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser!.uid;

    try {
      debugPrint('📌 Starting profile save for user: $userId');

      // --- Upload new images (with timeout) ---
      List<String> allImageUrls = List.from(_existingImages);
      if (_selectedImages.isNotEmpty) {
        debugPrint('📌 Uploading ${_selectedImages.length} image(s)...');
        final newUrls = await _storageService
            .uploadMultipleImages(_selectedImages, userId)
            .timeout(
          const Duration(seconds: 45),
          onTimeout: () => throw Exception('Image upload timed out after 45 seconds.'),
        );
        debugPrint('📌 Upload complete. New URLs: $newUrls');
        allImageUrls.addAll(newUrls);
      }

      // --- Parse interests ---
      List<String> interests = _interestsController.text
          .split(',')
          .map((i) => i.trim())
          .where((i) => i.isNotEmpty)
          .toList();

      // --- Update Firestore (with timeout) ---
      debugPrint('📌 Updating Firestore document...');
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'displayName': _displayNameController.text.trim(),
        'bio': _bioController.text.trim(),
        'dateOfBirth': _selectedDate?.toIso8601String(),
        'gender': _selectedGender,
        'seeking': _selectedSeeking,
        'interests': interests,
        'photos': allImageUrls,
        'isPrivate': _isPrivate,
        'updatedAt': FieldValue.serverTimestamp(),
      })
          .timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Firestore update timed out.'),
      );
      debugPrint('📌 Firestore update successful.');

      // --- Refresh local user model ---
      debugPrint('📌 Refreshing current user model...');
      await authService.refreshCurrentUserModel();
      debugPrint('📌 User model refreshed.');

      // --- Success feedback ---
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!'), duration: Duration(seconds: 2)),
      );

      // --- Navigate back (only if not first-time onboarding) ---
      if (!widget.isFirstTime && mounted) {
        debugPrint('📌 Navigating back.');
        Navigator.pop(context);
      } else if (widget.isFirstTime && mounted) {
        debugPrint('📌 First-time profile complete, not popping automatically.');
        // You can add navigation to next screen here if needed
      }
    } catch (e, stackTrace) {
      debugPrint('❌ ERROR in _saveProfile:');
      debugPrint('   Error: $e');
      debugPrint('   StackTrace: $stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _isLoading = false;
        });
        _recomputeDirty();
        debugPrint('📌 Saving state reset.');
      }
    }
  }

  /// Helper to build preview image (works for both File and Uint8List)
  Widget _buildImagePreview(dynamic imageData, {VoidCallback? onRemove}) {
    ImageProvider imageProvider;
    if (imageData is Uint8List) {
      imageProvider = MemoryImage(imageData);
    } else if (imageData is File) {
      imageProvider = FileImage(imageData);
    } else {
      // Fallback – should never happen
      imageProvider = const AssetImage('assets/placeholder.png');
    }

    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            image: DecorationImage(
              image: imageProvider,
              fit: BoxFit.cover,
            ),
          ),
        ),
        if (onRemove != null)
          Positioned(
            top: 0,
            right: 8,
            child: CircleAvatar(
              radius: 12,
              backgroundColor: Colors.red,
              child: IconButton(
                icon: const Icon(Icons.close, size: 12, color: Colors.white),
                onPressed: onRemove,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (!mounted) return;
          if (shouldPop) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Profile'),
          actions: [
            TextButton(
              onPressed: (_isLoading || _isSaving) ? null : _saveProfile,
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Photos section
              const Text('Photos', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Existing images (URLs)
                    ..._existingImages.map((url) => Stack(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            image: DecorationImage(
                              image: NetworkImage(url),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 8,
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.red,
                            child: IconButton(
                              icon: const Icon(Icons.close, size: 12, color: Colors.white),
                              onPressed: () {
                                setState(() {
                                  _existingImages.remove(url);
                                });
                                _recomputeDirty();
                              },
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    )),
                    // Newly selected images (preview)
                    ..._selectedImages.asMap().entries.map((entry) {
                      int index = entry.key;
                      dynamic img = entry.value;
                      return _buildImagePreview(
                        img,
                        onRemove: () {
                          setState(() {
                            _selectedImages.removeAt(index);
                          });
                          _recomputeDirty();
                        },
                      );
                    }),
                    // Add button (max 6 total)
                    if (_existingImages.length + _selectedImages.length < 6)
                      GestureDetector(
                        onTap: _pickImages,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: const Icon(Icons.add, size: 40, color: Colors.grey),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Display Name
              TextFormField(
                controller: _displayNameController,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a display name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Bio
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(
                  labelText: 'Bio',
                  border: OutlineInputBorder(),
                  hintText: 'Tell others about yourself...',
                ),
                maxLines: 4,
                maxLength: 500,
              ),
              const SizedBox(height: 16),

              // Date of Birth
              ListTile(
                title: const Text('Date of Birth'),
                subtitle: Text(_selectedDate != null
                    ? '${_selectedDate!.year}-${_selectedDate!.month}-${_selectedDate!.day}'
                    : 'Not set'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(context),
              ),
              const SizedBox(height: 16),

              // Gender
              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: const InputDecoration(
                  labelText: 'Gender',
                  border: OutlineInputBorder(),
                ),
                items: ['Male', 'Female', 'Non-binary', 'Prefer not to say']
                    .map((gender) => DropdownMenuItem(
                  value: gender,
                  child: Text(gender),
                ))
                    .toList(),
                onChanged: (value) => setState(() {
                  _selectedGender = value;
                  _recomputeDirty();
                }),
              ),
              const SizedBox(height: 16),

              // Seeking
              DropdownButtonFormField<String>(
                value: _selectedSeeking,
                decoration: const InputDecoration(
                  labelText: 'Seeking',
                  border: OutlineInputBorder(),
                ),
                items: ['Men', 'Women', 'Everyone']
                    .map((seeking) => DropdownMenuItem(
                  value: seeking,
                  child: Text(seeking),
                ))
                    .toList(),
                onChanged: (value) => setState(() {
                  _selectedSeeking = value;
                  _recomputeDirty();
                }),
              ),
              const SizedBox(height: 16),

              // Interests
              TextFormField(
                controller: _interestsController,
                decoration: const InputDecoration(
                  labelText: 'Interests',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., Music, Travel, Sports (comma separated)',
                ),
              ),
              const SizedBox(height: 16),

              // Private Account
              SwitchListTile(
                value: _isPrivate,
                onChanged: (value) => setState(() {
                  _isPrivate = value;
                  _recomputeDirty();
                }),
                title: const Text('Private account'),
                subtitle: Text(_isPrivate ? 'Only matches can see you' : 'Everyone can see you'),
              ),
              const SizedBox(height: 32),

              // Dedicated Save Button
              ElevatedButton.icon(
                onPressed: (_isLoading || _isSaving) ? null : _saveProfile,
                icon: (_isLoading || _isSaving)
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.save),
                label: Text((_isLoading || _isSaving) ? 'Saving...' : 'Save Changes'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}