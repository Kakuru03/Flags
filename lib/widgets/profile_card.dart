import 'package:flutter/material.dart';
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
  _ProfileCardState createState() => _ProfileCardState();
}

class _ProfileCardState extends State<ProfileCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Offset _dragStart = Offset.zero;
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  void _onPanStart(DragStartDetails details) {
    _dragStart = details.localPosition;
    _isDragging = true;
  }
  
  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset = details.localPosition - _dragStart;
    });
  }
  
  void _onPanEnd(DragEndDetails details) {
    const double swipeThreshold = 100;
    
    if (_dragOffset.dx > swipeThreshold) {
      // Swipe right (like)
      _animateAndComplete(widget.onSwipeRight);
    } else if (_dragOffset.dx < -swipeThreshold) {
      // Swipe left (dislike)
      _animateAndComplete(widget.onSwipeLeft);
    } else {
      // Reset position
      setState(() {
        _dragOffset = Offset.zero;
        _isDragging = false;
      });
    }
  }
  
  void _animateAndComplete(VoidCallback callback) {
    _controller.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 200), () {
      callback();
      setState(() {
        _dragOffset = Offset.zero;
        _isDragging = false;
      });
    });
  }
  
  double get _rotation => _dragOffset.dx / 20;
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
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
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      // Profile image
                      if (widget.user.photos.isNotEmpty)
                        Image.network(
                          widget.user.photos[0],
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(color: Colors.grey.shade300),
                        )
                      else
                        Container(color: Colors.grey.shade300),
                      
                      // Gradient overlay for text
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [0.0, 0.4, 1.0],
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.3),
                                Colors.black.withOpacity(0.9),
                              ],
                            ),
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    widget.user.displayName ?? 'User',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (widget.user.dateOfBirth != null)
                                    Text(
                                      '${DateTime.now().difference(widget.user.dateOfBirth!).inDays ~/ 365}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (widget.user.bio != null)
                                Text(
                                  widget.user.bio!,
                                  style: const TextStyle(color: Colors.white, fontSize: 16),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              const SizedBox(height: 8),
                              if (widget.user.interests.isNotEmpty) ...[
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: widget.user.interests.take(5).map((interest) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.25),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.6),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.tag,
                                              size: 10, color: Colors.white70),
                                          const SizedBox(width: 3),
                                          Text(
                                            interest,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                                if (widget.user.interests.length > 5)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      '+${widget.user.interests.length - 5} more',
                                      style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 11),
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      
                      // Swipe indicators
                      if (_isDragging)
                        Positioned(
                          top: 50,
                          left: _dragOffset.dx < -50 ? null : 20,
                          right: _dragOffset.dx > 50 ? null : 20,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: _dragOffset.dx > 0 ? Colors.green : Colors.red,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              _dragOffset.dx > 0 ? 'LIKE' : 'NOPE',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}