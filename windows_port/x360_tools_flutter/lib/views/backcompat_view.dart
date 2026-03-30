import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../widgets/premium_card.dart';

class BackcompatView extends StatelessWidget {
  const BackcompatView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Backwards Compatibility", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(
            "Play Original Xbox games on your Xbox 360.",
            style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.5)),
          ),
          const SizedBox(height: 40),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 24,
              crossAxisSpacing: 24,
              childAspectRatio: 0.75,
            ),
            itemCount: state.backcompat.length,
            itemBuilder: (context, index) {
              final pkg = state.backcompat[index];
              return PremiumCard(
                title: pkg['name'],
                subtitle: "Compat File",
                imagePath: "generic_cover.png",
                isSelected: state.selectedPackages.contains(pkg['file']),
                onTap: () => state.togglePackage(pkg['file']),
              );
            },
          ),
        ],
      ),
    );
  }
}
