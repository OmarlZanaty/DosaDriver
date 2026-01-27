import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../widgets/custom_button.dart';

/// Client Ride Completion Screen with Rating
class ClientRideCompleteScreen extends StatefulWidget {
  final String rideId;
  final String captainName;
  final double fare;

  const ClientRideCompleteScreen({
    super.key,
    required this.rideId,
    required this.captainName,
    required this.fare,
  });

  @override
  State<ClientRideCompleteScreen> createState() =>
      _ClientRideCompleteScreenState();
}

class _ClientRideCompleteScreenState extends State<ClientRideCompleteScreen> {
  int _rating = 0;
  int _selectedTip = -1;
  final Set<String> _selectedTags = {};
  bool _isSubmitting = false;

  final List<String> _feedbackTags = [
    'Great conversation',
    'Clean car',
    'Safe driving',
    'Professional',
    'On time',
    'Friendly',
  ];

  final List<double> _tipOptions = [2.0, 5.0, 10.0];

  Future<void> _submitRating() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      double tipAmount = _selectedTip >= 0 ? _tipOptions[_selectedTip] : 0;

      await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .update({
        'clientRating': _rating,
        'clientFeedback': _selectedTags.toList(),
        'tipAmount': tipAmount,
        'ratedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting rating: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Success Icon
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: AppColors.white,
                  size: 48,
                ),
              ),

              const SizedBox(height: 24),

              // Title
              Text(
                'Ride Completed!',
                style: AppTextStyles.headline1,
              ),

              const SizedBox(height: 32),

              // Fare Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.lightGray,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      'Trip Fare',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.mediumGray,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '\$${widget.fare.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkGray,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Distance: 5.2 km • Duration: 18 min',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Rate Captain Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  children: [
                    Text(
                      'Rate your captain',
                      style: AppTextStyles.headline3,
                    ),

                    const SizedBox(height: 16),

                    // Captain Info
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.lightGray,
                            border: Border.all(
                              color: AppColors.divider,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.person,
                            color: AppColors.mediumGray,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          widget.captainName,
                          style: AppTextStyles.headline3,
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Star Rating
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return GestureDetector(
                          onTap: () {
                            setState(() => _rating = index + 1);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              index < _rating ? Icons.star : Icons.star_border,
                              color: index < _rating
                                  ? AppColors.warning
                                  : AppColors.divider,
                              size: 40,
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Feedback Tags
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'What went well?',
                  style: AppTextStyles.headline3,
                ),
              ),

              const SizedBox(height: 12),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _feedbackTags.map((tag) {
                  final isSelected = _selectedTags.contains(tag);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedTags.remove(tag);
                        } else {
                          _selectedTags.add(tag);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.success.withOpacity(0.1)
                            : AppColors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.success
                              : AppColors.divider,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        tag,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: isSelected
                              ? AppColors.success
                              : AppColors.darkGray,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 32),

              // Tip Section
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Add a tip',
                  style: AppTextStyles.headline3,
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  ...List.generate(_tipOptions.length, (index) {
                    final isSelected = _selectedTip == index;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedTip = isSelected ? -1 : index;
                          });
                        },
                        child: Container(
                          margin: EdgeInsets.only(
                            right: index < _tipOptions.length - 1 ? 8 : 0,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.lightGray,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.divider,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '\$${_tipOptions[index].toInt()}',
                              style: AppTextStyles.bodyLarge.copyWith(
                                color: isSelected
                                    ? AppColors.white
                                    : AppColors.darkGray,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final controller = TextEditingController();
                        final tip = await showDialog<double>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: Text('Enter custom tip'),
                            content: TextField(controller: controller, keyboardType: TextInputType.numberWithOptions(decimal: true)),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
                              TextButton(onPressed: () => Navigator.pop(context, double.tryParse(controller.text) ?? 0.0), child: Text('OK')),
                            ],
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.lightGray,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Center(
                          child: Text(
                            'Custom',
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Submit Button
              PrimaryButton(
                text: 'Submit',
                onPressed: _submitRating,
                isLoading: _isSubmitting,
              ),

              const SizedBox(height: 16),

              // Skip Button
              TextButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: Text(
                  'Skip',
                  style: AppTextStyles.link,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
