import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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

  final List<File> _selectedImages = [];
  List<String> _existingImages = [];
  DateTime? _selectedDate;
  String? _selectedGender;
  String? _selectedSeeking;

  bool _isLoading = false;

  bool _isDirty = false;
  bool _isSaving = false;
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

    _displayNameController = TextEditingController(text: _initialDisplayName);
    _bioController = TextEditingController(text: _initialBio);
    _interestsController = TextEditingController(text: _initialInterestsCsv);

    _selectedDate = _initialDate;
    _selectedGender = _initialGender;
    _selectedSeeking = _initialSeeking;
    _existingImages = List<String>.from(_initialPhotos);
    _isPrivate = _initialPrivate;
    _isFrozen = user?.isFrozen ?? false;

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
    
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images.map((xfile) => File(xfile.path)));
      });
    }
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
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser!.uid;
    
    try {
      // Upload new images
      List<String> allImageUrls = List.from(_existingImages);
      if (_selectedImages.isNotEmpty) {
        final newUrls = await _storageService.uploadMultipleImages(_selectedImages, userId);
        allImageUrls.addAll(newUrls);
      }
      
      // Parse interests
      List<String> interests = _interestsController.text
          .split(',')
          .map((i) => i.trim())
          .where((i) => i.isNotEmpty)
          .toList();
      
      // Update user profile
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'displayName': _displayNameController.text.trim(),
        'bio': _bioController.text.trim(),
        'dateOfBirth': _selectedDate?.toIso8601String(),
        'gender': _selectedGender,
        'seeking': _selectedSeeking,
        'interests': interests,
        'photos': allImageUrls,
        'isPrivate': _isPrivate,
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );

      // Refresh cached profile so ProfileScreen updates immediately
      await authService.refreshCurrentUserModel();

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e, stackTrace) {
      // Log full error details to console (including FirebaseException code/message)
      // so permission/config issues are immediately visible.
      // ignore: avoid_print
      debugPrint('=== EditProfileScreen error ===');
      debugPrint('context: _saveProfile');
      debugPrint('error runtimeType: ${e.runtimeType}');
      debugPrint('error toString: $e');
      debugPrint('error (full): ${e.toString()}');
      debugPrint('stackTrace: $stackTrace');

      // If Firebase returned a FirebaseException, also print its structured fields.
      // ignore: avoid_print
      final dynamic eDynamic = e;
      try {
        // ignore: avoid_print
        debugPrint('--- Firebase structured error (if available) ---');
        debugPrint('firebaseErrorCode: ${eDynamic.code}');
        debugPrint('firebaseMessage: ${eDynamic.message}');
        debugPrint('firebaseStatus: ${eDynamic.status}');
        debugPrint('firebaseDetails: ${eDynamic.details}');
      } catch (_) {
        // ignore: avoid_print
        debugPrint('No FirebaseException structured fields available for: ${e.runtimeType}');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error updating profile. Check console for details.'),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
      _isSaving = false;
      _recomputeDirty();
    }
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
              onPressed: _isLoading ? null : _saveProfile,
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
                  // Photos
                  const Text('Photos', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
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
                                  },
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ],
                        )),
                        ..._selectedImages.map((file) => Stack(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                image: DecorationImage(
                                  image: FileImage(file),
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
                                      _selectedImages.remove(file);
                                    });
                                  },
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ],
                        )),
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
                    initialValue: _selectedGender,
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
                    onChanged: (value) => setState(() => _selectedGender = value),
                  ),
                  const SizedBox(height: 16),
                  
                  // Seeking
                  DropdownButtonFormField<String>(
                    initialValue: _selectedSeeking,
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
                    onChanged: (value) => setState(() => _selectedSeeking = value),
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
                    onChanged: (value) => setState(() => _isPrivate = value),
                    title: const Text('Private account'),
                    subtitle: Text(_isPrivate ? 'Only matches can see you' : 'Everyone can see you'),
                  ),
                ],
              ),
            ),
      ),
    );
  }
}
