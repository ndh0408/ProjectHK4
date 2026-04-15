import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/registration_question.dart';
import '../../../../shared/widgets/empty_state.dart';
import 'payment_screen.dart';

class RegistrationFormScreen extends ConsumerStatefulWidget {
  const RegistrationFormScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
    required this.isFree,
    this.ticketPrice,
  });

  final String eventId;
  final String eventTitle;
  final bool isFree;
  final double? ticketPrice;

  @override
  ConsumerState<RegistrationFormScreen> createState() =>
      _RegistrationFormScreenState();
}

class _RegistrationFormScreenState
    extends ConsumerState<RegistrationFormScreen> {
  List<RegistrationQuestion> _questions = [];
  final Map<String, dynamic> _answers = {};
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkExistingRegistrationAndLoad();
  }

  Future<void> _checkExistingRegistrationAndLoad() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = ref.read(apiServiceProvider);

      final regStatus = await api.getRegistrationStatus(widget.eventId);
      if (regStatus.isRegistered && regStatus.requiresPayment && regStatus.registrationId != null) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentScreen(
              registrationId: regStatus.registrationId!,
              eventTitle: widget.eventTitle,
              amount: regStatus.ticketPrice ?? widget.ticketPrice ?? 0,
            ),
          ),
        );
        return;
      }

      await _loadQuestions();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = ErrorUtils.extractMessage(e);
      });
    }
  }

  Future<void> _loadQuestions() async {
    try {
      final api = ref.read(apiServiceProvider);
      final questions = await api.getRegistrationQuestions(widget.eventId);
      setState(() {
        _questions = questions;
        _isLoading = false;
        for (final q in questions) {
          if (q.questionType == QuestionType.multipleChoice) {
            _answers[q.id] = <String>[];
          } else {
            _answers[q.id] = '';
          }
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = ErrorUtils.extractMessage(e);
      });
    }
  }

  bool _validateForm() {
    for (final question in _questions) {
      if (question.required) {
        final answer = _answers[question.id];
        if (question.questionType == QuestionType.multipleChoice) {
          if ((answer as List<String>).isEmpty) {
            _showError('Please answer: ${question.questionText}');
            return false;
          }
        } else {
          if ((answer as String).trim().isEmpty) {
            _showError('Please answer: ${question.questionText}');
            return false;
          }
        }
      }
    }
    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_validateForm()) return;

    setState(() => _isSubmitting = true);

    try {
      final api = ref.read(apiServiceProvider);

      final regStatus = await api.getRegistrationStatus(widget.eventId);
      debugPrint('=== Registration Status Check ===');
      debugPrint('isRegistered: ${regStatus.isRegistered}');
      debugPrint('registrationId: ${regStatus.registrationId}');
      debugPrint('requiresPayment: ${regStatus.requiresPayment}');
      debugPrint('ticketPrice: ${regStatus.ticketPrice}');
      debugPrint('status: ${regStatus.status}');

      if (regStatus.isRegistered && regStatus.registrationId != null) {
        if (regStatus.requiresPayment) {
          debugPrint('=== Navigating to PaymentScreen (existing registration) ===');
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => PaymentScreen(
                registrationId: regStatus.registrationId!,
                eventTitle: widget.eventTitle,
                amount: regStatus.ticketPrice ?? widget.ticketPrice ?? 0,
              ),
            ),
          );
          return;
        } else {
          debugPrint('=== Already registered, no payment needed ===');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!.alreadyRegistered),
                backgroundColor: AppColors.success,
              ),
            );
            Navigator.pop(context, true);
          }
          return;
        }
      }

      final answersList = _questions.map((q) {
        final answer = _answers[q.id];
        String answerText;
        if (q.questionType == QuestionType.multipleChoice) {
          answerText = (answer as List<String>).join(', ');
        } else {
          answerText = answer as String;
        }
        return RegistrationAnswer(
          questionId: q.id,
          answer: answerText,
        );
      }).toList();

      debugPrint('=== Creating new registration ===');
      final registration = await api.registerForEventWithAnswers(
        widget.eventId,
        answersList,
      );
      debugPrint('=== Registration created: ${registration.id} ===');

      if (!widget.isFree && widget.ticketPrice != null && widget.ticketPrice! > 0) {
        debugPrint('=== Navigating to PaymentScreen (new registration) ===');
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentScreen(
              registrationId: registration.id,
              eventTitle: widget.eventTitle,
              amount: widget.ticketPrice!,
            ),
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.successfullyRegistered),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        _showError(ErrorUtils.extractMessage(e));
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
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.registrationForm),
      ),
      body: _buildBody(),
      bottomNavigationBar: _questions.isNotEmpty ? _buildSubmitButton() : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return LoadingState(message: AppLocalizations.of(context)!.loadingQuestions);
    }

    if (_errorMessage != null) {
      return ErrorState(
        message: _errorMessage!,
        onRetry: _loadQuestions,
      );
    }

    if (_questions.isEmpty) {
      return EmptyState(
        icon: Icons.quiz_outlined,
        title: AppLocalizations.of(context)!.noQuestions,
        subtitle: AppLocalizations.of(context)!.noQuestionsSubtitle,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.eventTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppLocalizations.of(context)!.fillOutFormToComplete,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          ...List.generate(_questions.length, (index) {
            final question = _questions[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: _buildQuestionWidget(question, index + 1),
            );
          }),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildQuestionWidget(RegistrationQuestion question, int number) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  '$number',
                  style: const TextStyle(
                    color: AppColors.textOnPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      text: question.questionText,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                      children: [
                        if (question.required)
                          const TextSpan(
                            text: ' *',
                            style: TextStyle(color: AppColors.error),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildAnswerInput(question),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAnswerInput(RegistrationQuestion question) {
    switch (question.questionType) {
      case QuestionType.text:
        return TextField(
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.enterYourAnswer,
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) {
            _answers[question.id] = value;
          },
        );

      case QuestionType.textarea:
        return TextField(
          maxLines: 4,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.enterYourAnswer,
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) {
            _answers[question.id] = value;
          },
        );

      case QuestionType.singleChoice:
        return Column(
          children: question.options?.map((option) {
                return RadioListTile<String>(
                  title: Text(option),
                  value: option,
                  groupValue: _answers[question.id] as String?,
                  onChanged: (value) {
                    setState(() {
                      _answers[question.id] = value ?? '';
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                );
              }).toList() ??
              [],
        );

      case QuestionType.multipleChoice:
        return Column(
          children: question.options?.map((option) {
                final selectedOptions =
                    _answers[question.id] as List<String>? ?? [];
                return CheckboxListTile(
                  title: Text(option),
                  value: selectedOptions.contains(option),
                  onChanged: (checked) {
                    setState(() {
                      final list =
                          List<String>.from(_answers[question.id] as List);
                      if (checked == true) {
                        list.add(option);
                      } else {
                        list.remove(option);
                      }
                      _answers[question.id] = list;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                );
              }).toList() ??
              [],
        );
    }
  }

  Widget _buildSubmitButton() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.textOnPrimary,
                    ),
                  )
                : Text(
                    widget.isFree ? AppLocalizations.of(context)!.submitRegistration : AppLocalizations.of(context)!.continueToPayment,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
