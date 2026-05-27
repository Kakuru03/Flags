import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // for haptic feedback
import '../models/user_model.dart';

class ProfileCard extends StatefulWidget {
  final UserModel user;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;

  const ProfileCard({
    super.key,
    required this.user,
    required this.onSwipeLeft,
    required this.onSwipeRight,
  });

  @override
  State<ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<ProfileCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _resetController;
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  bool _isSwiping = false;

  static const double _swipeThreshold = 120.0;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _resetController.addListener(_onResetTick);
  }

  void _onResetTick() {
    if (!_resetController.isAnimating) return;
    final t = _resetController.value;
    final eased = 1.0 - Curves.easeOutQuad.transform(t);
    setState(() {
      _dragOffset = Offset(_dragOffset.dx * eased, _dragOffset.dy * eased);
    });
    if (_resetController.isCompleted) {
      _dragOffset = Offset.zero;
      _isDragging = false;
    }
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    if (_isSwiping) return;
    _isDragging = true;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isSwiping) return;
    setState(() {
      _dragOffset += details.delta;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isSwiping) return;

    final swipeDistance = _dragOffset.dx.abs();
    if (swipeDistance >= _swipeThreshold) {
      _isSwiping = true;
      HapticFeedback.mediumImpact();

      final offScreenOffset = Offset(
        _dragOffset.dx > 0 ? 1000.0 : -1000.0,
        0.0,
      );
      setState(() {
        _dragOffset = offScreenOffset;
      });

      Future.delayed(const Duration(milliseconds: 200), () {
        if (_dragOffset.dx > 0) {
          widget.onSwipeRight();
        } else {
          widget.onSwipeLeft();
        }
      });
    } else {
      _resetController.forward(from: 0.0);
    }
  }

  double get _rotation => (_dragOffset.dx / _swipeThreshold).clamp(-0.5, 0.5);

  int get _age {
    if (widget.user.dateOfBirth == null) return 0;
    final now = DateTime.now();
    final birth = widget.user.dateOfBirth!;
    int age = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      age--;
    }
    return age;
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: _dragOffset,
      child: Transform.rotate(
        angle: _rotation,
        child: GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---------- IMAGE SECTION (60% of card height) ----------
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.48,
                    width: double.infinity,
                    child: widget.user.photos.isNotEmpty
                        ? Image.network(
                      widget.user.photos.first,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.broken_image, size: 60),
                      ),
                    )
                        : Container(
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.person, size: 80),
                    ),
                  ),

                  // ---------- CONTENT SECTION (white background) ----------
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name and age
                        Row(
                          children: [
                            Text(
                              widget.user.displayName ?? 'Anonymous',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (_age > 0)
                              Text(
                                '$_age',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Bio
                        if (widget.user.bio != null && widget.user.bio!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              widget.user.bio!,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.black54,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                        // Interests chips
                        if (widget.user.interests.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: widget.user.interests.take(5).map((interest) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.deepPurple.shade100,
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  interest,
                                  style: TextStyle(
                                    color: Colors.deepPurple.shade700,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          if (widget.user.interests.length > 5)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                '+${widget.user.interests.length - 5} more',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}