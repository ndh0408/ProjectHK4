// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'registration_question.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RegistrationQuestion _$RegistrationQuestionFromJson(
        Map<String, dynamic> json) =>
    RegistrationQuestion(
      id: json['id'] as String,
      questionText: json['questionText'] as String,
      questionType: $enumDecode(_$QuestionTypeEnumMap, json['questionType']),
      options:
          (json['options'] as List<dynamic>?)?.map((e) => e as String).toList(),
      required: json['required'] as bool? ?? false,
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$RegistrationQuestionToJson(
        RegistrationQuestion instance) =>
    <String, dynamic>{
      'id': instance.id,
      'questionText': instance.questionText,
      'questionType': _$QuestionTypeEnumMap[instance.questionType]!,
      'options': instance.options,
      'required': instance.required,
      'displayOrder': instance.displayOrder,
    };

const _$QuestionTypeEnumMap = {
  QuestionType.text: 'TEXT',
  QuestionType.textarea: 'TEXTAREA',
  QuestionType.singleChoice: 'SINGLE_CHOICE',
  QuestionType.multipleChoice: 'MULTIPLE_CHOICE',
};

RegistrationAnswer _$RegistrationAnswerFromJson(Map<String, dynamic> json) =>
    RegistrationAnswer(
      questionId: json['questionId'] as String,
      answer: json['answer'] as String,
    );

Map<String, dynamic> _$RegistrationAnswerToJson(RegistrationAnswer instance) =>
    <String, dynamic>{
      'questionId': instance.questionId,
      'answer': instance.answer,
    };
