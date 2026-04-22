import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/design_tokens/design_tokens.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/registration_question.dart';
import '../../../../shared/widgets/app_components.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../home/presentation/screens/home_screen.dart';
import 'payment_screen.dart';

class RegistrationFormScreen extends ConsumerStatefulWidget {
  const RegistrationFormScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
    required this.isFree,
    this.ticketPrice,
    this.ticketTypeId,
    this.ticketTypeName,
    this.quantity = 1,
  });

  final String eventId;
  final String eventTitle;
  final bool isFree;
  final double? ticketPrice;
  final String? ticketTypeId;
  final String? ticketTypeName;
  final int quantity;

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

  // Profile Form Fields
  final _jobTitleController = TextEditingController();
  final _companyController = TextEditingController();
  final _industryController = TextEditingController();
  final _experienceController = TextEditingController();
  final _goalsController = TextEditingController();
  final _expectationsController = TextEditingController();
  final _linkedinController = TextEditingController();

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
      if (regStatus.isRegistered &&
          regStatus.requiresPayment &&
          regStatus.registrationId != null) {
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

      // Paid events skip the form: reuse an existing registration if there
      // is one (from a prior unfinished checkout), otherwise create a fresh
      // one up-front so PaymentScreen has a real id to call /payment-intent
      // with. An empty id collapses the path and the request 404s into the
      // generic 500 handler.
      if (!widget.isFree &&
          widget.ticketPrice != null &&
          widget.ticketPrice! > 0) {
        String registrationId;
        if (regStatus.isRegistered && regStatus.registrationId != null) {
          registrationId = regStatus.registrationId!;
        } else {
          final registration = await api.registerForEvent(
            widget.eventId,
            ticketTypeId: widget.ticketTypeId,
            quantity: widget.quantity,
          );
          registrationId = registration.id;
        }
        if (!mounted) return;
        final total = widget.ticketPrice! * widget.quantity;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentScreen(
              registrationId: registrationId,
              eventTitle: widget.eventTitle,
              amount: total,
              tierName: widget.ticketTypeName,
              unitPrice: widget.ticketPrice,
              quantity: widget.quantity,
            ),
          ),
        );
        return;
      }

      // Free events still need the questions form
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
    // Validate Profile Form
    if (_jobTitleController.text.trim().isEmpty) {
      _showError('Please enter your job title');
      return false;
    }
    if (_companyController.text.trim().isEmpty) {
      _showError('Please enter your company');
      return false;
    }

    // Validate Custom Questions
    for (final question in _questions) {
      if (!question.required) continue;

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
      if (regStatus.isRegistered && regStatus.registrationId != null) {
        if (regStatus.requiresPayment) {
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

      final answersList = _questions.map((q) {
        final answer = _answers[q.id];
        final answerText = q.questionType == QuestionType.multipleChoice
            ? (answer as List<String>).join(', ')
            : answer as String;
        return RegistrationAnswer(
          questionId: q.id,
          answer: answerText,
        );
      }).toList();

      // Prepare profile data
      final profileData = <String, dynamic>{
        'jobTitle': _jobTitleController.text.trim(),
        'company': _companyController.text.trim(),
        'industry': _industryController.text.trim(),
        'experienceLevel': _experienceController.text.trim(),
        'registrationGoals': _goalsController.text.trim(),
        'expectations': _expectationsController.text.trim(),
        'linkedinUrl': _linkedinController.text.trim(),
      };

      final registration = await api.registerForEventWithAnswersAndProfile(
        widget.eventId,
        answersList,
        profileData,
        ticketTypeId: widget.ticketTypeId,
        quantity: widget.quantity,
      );

      if (!widget.isFree &&
          widget.ticketPrice != null &&
          widget.ticketPrice! > 0) {
        if (!mounted) return;
        final total = widget.ticketPrice! * widget.quantity;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentScreen(
              registrationId: registration.id,
              eventTitle: widget.eventTitle,
              amount: total,
              tierName: widget.ticketTypeName,
              unitPrice: widget.ticketPrice,
              quantity: widget.quantity,
            ),
          ),
        );
      } else if (mounted) {
        ref.invalidate(myFutureRegistrationsProvider);
        ref.invalidate(myPastRegistrationsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.successfullyRegistered),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.registrationForm),
      ),
      body: _buildBody(context, l10n),
      bottomNavigationBar: _buildSubmitBar(context, l10n),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    if (_isLoading) {
      return const LoadingState(
        message: 'Loading registration form...',
      );
    }

    if (_errorMessage != null) {
      return ErrorState(
        message: _errorMessage!,
        onRetry: _loadQuestions,
      );
    }

    return ListView(
      padding: AppSpacing.screenPadding.copyWith(bottom: 140),
      children: [
        _buildSummaryCard(context, l10n),
        const SizedBox(height: AppSpacing.xl),
        _buildProfileForm(context, l10n),
        if (_questions.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          _buildCustomQuestionsSection(context, l10n),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildProfileForm(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.person_outline, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Professional Profile',
              style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Help organizers understand your background and goals',
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          controller: _jobTitleController,
          label: 'Job Title *',
          hint: 'e.g., Product Manager',
          keyboardType: TextInputType.text,
          required: true,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _companyController,
          label: 'Company *',
          hint: 'e.g., Google',
          keyboardType: TextInputType.text,
          required: true,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _industryController,
          label: 'Industry',
          hint: 'e.g., Technology',
          keyboardType: TextInputType.text,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _experienceController,
          label: 'Experience Level',
          hint: 'e.g., Mid-level, Senior, Executive',
          keyboardType: TextInputType.text,
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Icon(Icons.lightbulb_outline, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Goals & Expectations',
              style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _goalsController,
          label: 'Why do you want to attend this event?',
          hint: 'Tell us about your goals...',
          keyboardType: TextInputType.multiline,
          maxLines: 3,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _expectationsController,
          label: 'What are your expectations?',
          hint: 'What do you hope to gain?',
          keyboardType: TextInputType.multiline,
          maxLines: 3,
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Icon(Icons.link, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Online Profile',
              style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _linkedinController,
          label: 'LinkedIn URL (Optional)',
          hint: 'https://linkedin.com/in/yourname',
          keyboardType: TextInputType.url,
        ),
      ],
    );
  }

  Widget _buildCustomQuestionsSection(
      BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.quiz, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Event-Specific Questions',
              style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Additional questions from the organizer',
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        ...List.generate(
          _questions.length,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: _buildQuestionCard(context, _questions[index], index + 1),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(BuildContext context, AppLocalizations l10n) {
    final total = (widget.ticketPrice ?? 0) * widget.quantity;

    return AppCard(
      background: AppColors.primarySoft,
      borderColor: AppColors.primary.withValues(alpha: 0.12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.eventTitle,
            style: AppTypography.h2.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Complete the short form below to secure your registration and keep checkout friction low.',
            style: AppTypography.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              StatusChip(
                label: widget.isFree ? 'Free entry' : 'Paid ticket',
                variant: widget.isFree
                    ? StatusChipVariant.success
                    : StatusChipVariant.primary,
              ),
              if (widget.ticketTypeName != null)
                StatusChip(
                  label: widget.ticketTypeName!,
                  variant: StatusChipVariant.neutral,
                ),
              if (widget.quantity > 1)
                StatusChip(
                  label: '${widget.quantity} attendees',
                  variant: StatusChipVariant.info,
                ),
            ],
          ),
          if (!widget.isFree && widget.ticketPrice != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Text(
                  l10n.registrationFee,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  '\$${total.toStringAsFixed(2)}',
                  style: AppTypography.h3.copyWith(color: AppColors.primary),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestionCard(
    BuildContext context,
    RegistrationQuestion question,
    int number,
  ) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$number',
                  style: AppTypography.label.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question.questionText,
                      style: AppTypography.h4.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      question.required
                          ? 'Required information'
                          : 'Optional information',
                      style: AppTypography.caption.copyWith(
                        color: question.required
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildAnswerInput(context, question),
        ],
      ),
    );
  }

  Widget _buildAnswerInput(
    BuildContext context,
    RegistrationQuestion question,
  ) {
    final l10n = AppLocalizations.of(context)!;

    switch (question.questionType) {
      case QuestionType.text:
        return AppTextField(
          hint: l10n.enterYourAnswer,
          initialValue: _answers[question.id] as String?,
          required: question.required,
          onChanged: (value) => _answers[question.id] = value,
        );

      case QuestionType.textarea:
        return AppTextField(
          hint: l10n.enterYourAnswer,
          initialValue: _answers[question.id] as String?,
          maxLines: 5,
          required: question.required,
          onChanged: (value) => _answers[question.id] = value,
        );

      case QuestionType.singleChoice:
        final groupValue = _answers[question.id] as String?;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final option in question.options ?? <String>[])
              ChoiceChip(
                label: Text(option),
                selected: groupValue == option,
                onSelected: (_) {
                  setState(() {
                    _answers[question.id] = option;
                  });
                },
                selectedColor: AppColors.primarySoft,
                labelStyle: AppTypography.body.copyWith(
                  color: groupValue == option
                      ? AppColors.primary
                      : AppColors.textPrimary,
                  fontWeight:
                      groupValue == option ? FontWeight.w700 : FontWeight.w500,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.allPill,
                  side: BorderSide(
                    color: groupValue == option
                        ? AppColors.primary
                        : AppColors.border,
                  ),
                ),
              ),
          ],
        );

      case QuestionType.multipleChoice:
        final selectedOptions = _answers[question.id] as List<String>? ?? [];
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final option in question.options ?? <String>[])
              FilterChip(
                label: Text(option),
                selected: selectedOptions.contains(option),
                onSelected: (selected) {
                  setState(() {
                    final list = List<String>.from(selectedOptions);
                    if (selected) {
                      list.add(option);
                    } else {
                      list.remove(option);
                    }
                    _answers[question.id] = list;
                  });
                },
                selectedColor: AppColors.primarySoft,
                checkmarkColor: AppColors.primary,
                labelStyle: AppTypography.body.copyWith(
                  color: selectedOptions.contains(option)
                      ? AppColors.primary
                      : AppColors.textPrimary,
                  fontWeight: selectedOptions.contains(option)
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.allPill,
                  side: BorderSide(
                    color: selectedOptions.contains(option)
                        ? AppColors.primary
                        : AppColors.border,
                  ),
                ),
              ),
          ],
        );
    }
  }

  Widget _buildSubmitBar(BuildContext context, AppLocalizations l10n) {
    final total = (widget.ticketPrice ?? 0) * widget.quantity;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageX,
          AppSpacing.md,
          AppSpacing.pageX,
          AppSpacing.pageY,
        ),
        child: AppCard(
          shadow: AppShadows.md,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isFree ? 'Ready to confirm' : 'Next step',
                          style: AppTypography.label.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          widget.isFree
                              ? 'Submit registration'
                              : 'Continue to payment',
                          style: AppTypography.h4.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!widget.isFree && widget.ticketPrice != null)
                    Text(
                      '\$${total.toStringAsFixed(2)}',
                      style: AppTypography.h3.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: widget.isFree
                    ? l10n.submitRegistration
                    : l10n.continueToPayment,
                icon: widget.isFree
                    ? Icons.check_circle_outline_rounded
                    : Icons.arrow_forward_rounded,
                loading: _isSubmitting,
                expanded: true,
                size: AppButtonSize.lg,
                onPressed: _isSubmitting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
