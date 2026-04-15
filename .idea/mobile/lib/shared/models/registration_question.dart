import 'package:json_annotation/json_annotation.dart';

part 'registration_question.g.dart';

enum QuestionType {
  @JsonValue('TEXT')
  text,
  @JsonValue('TEXTAREA')
  textarea,
  @JsonValue('SINGLE_CHOICE')
  singleChoice,
  @JsonValue('MULTIPLE_CHOICE')
  multipleChoice,
}

@JsonSerializable()
class RegistrationQuestion {
  const RegistrationQuestion({
    required this.id,
    required this.questionText,
    required this.questionType,
    this.options,
    this.required = false,
    this.displayOrder = 0,
  });

  factory RegistrationQuestion.fromJson(Map<String, dynamic> json) =>
      _$RegistrationQuestionFromJson(json);

  final String id;
  final String questionText;
  final QuestionType questionType;
  final List<String>? options;
  @JsonKey(name: 'required', defaultValue: false)
  final bool required;
  @JsonKey(defaultValue: 0)
  final int displayOrder;

  Map<String, dynamic> toJson() => _$RegistrationQuestionToJson(this);
}

@JsonSerializable()
class RegistrationAnswer {
  const RegistrationAnswer({
    required this.questionId,
    required this.answer,
  });

  factory RegistrationAnswer.fromJson(Map<String, dynamic> json) =>
      _$RegistrationAnswerFromJson(json);

  final String questionId;
  final String answer;

  Map<String, dynamic> toJson() => _$RegistrationAnswerToJson(this);
}
