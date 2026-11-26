import 'package:flutter/material.dart';
import 'package:bems_farms/core/constants/app_colors.dart';

class RecipeHelperPage extends StatelessWidget {
  const RecipeHelperPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipe Helper', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('What ingredients\ndo you have?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Select your ingredients and we\'ll suggest recipes!', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ingredientChip('Tomato', true),
                _ingredientChip('Onion', true),
                _ingredientChip('Pepper', true),
                _ingredientChip('Carrot', false),
                _ingredientChip('Spinach', false),
                _ingredientChip('Garlic', false),
                _addMoreChip(),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {},
              child: const Text('Find Recipes'),
            ),
            const SizedBox(height: 40),
            const Text('Popular Recipes for You', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildRecipeCard(),
          ],
        ),
      ),
    );
  }

  Widget _ingredientChip(String label, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.accent : Colors.white,
        border: Border.all(color: isSelected ? AppColors.primary : AppColors.surface),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isSelected ? Icons.check : Icons.add, size: 16, color: isSelected ? AppColors.primary : AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: isSelected ? AppColors.primary : AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _addMoreChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.surface),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add, size: 16),
          SizedBox(width: 8),
          Text('Add more'),
        ],
      ),
    );
  }

  Widget _buildRecipeCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surface),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.restaurant, color: AppColors.textHint),
          ),
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tomato Pepper Stew', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('25 mins • Easy', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
