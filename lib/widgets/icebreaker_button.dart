import 'package:flutter/material.dart';

class IcebreakerButton extends StatelessWidget {
  final VoidCallback onTap;
  
  const IcebreakerButton({super.key, required this.onTap});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.lightbulb_outline),
        label: const Text('Get Icebreaker'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amber,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
    );
  }
}