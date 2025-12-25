import '../models/lesson.dart';
import '../models/topic.dart';
import '../models/test_question.dart';
import 'lessons_service.dart';
import 'questions_service.dart';

/// Utility class to upload initial data to Firebase
/// This is a one-time script to populate Firebase with initial data
class FirebaseDataUploader {
  final LessonsService _lessonsService = LessonsService();
  final QuestionsService _questionsService = QuestionsService();

  /// Upload Tarih lesson and İslamiyet Öncesi Türk Tarihi topic
  Future<bool> uploadTarihLessonData() async {
    try {
      print('📚 Creating Tarih lesson...');
      // 1. Create Tarih lesson if it doesn't exist
      final tarihLesson = Lesson(
        id: 'tarih_lesson',
        name: 'Tarih',
        category: 'genel_kultur',
        icon: 'history',
        color: 'red',
        topicCount: 1, // Will be updated when topics are added
        questionCount: 25, // İslamiyet Öncesi Türk Tarihi has 25 questions
        description: 'Türk tarihi, Osmanlı tarihi ve dünya tarihi',
        order: 1,
      );

      final lessonResult = await _lessonsService.addLesson(tarihLesson);
      if (!lessonResult) {
        print('⚠️ Lesson may already exist, continuing...');
      } else {
        print('✅ Tarih lesson created');
      }

      print('📖 Creating İslamiyet Öncesi Türk Tarihi topic...');
      // 2. Create İslamiyet Öncesi Türk Tarihi topic
      final topic = Topic(
        id: 'islamiyet_oncesi_turk_tarihi',
        lessonId: 'tarih_lesson',
        name: 'İslamiyet Öncesi Türk Tarihi',
        subtitle: 'Türklerin İslamiyet öncesi dönemdeki devlet yapısı, kültürü ve yaşamı',
        duration: '4h 30min',
        averageQuestionCount: 25,
        testCount: 1,
        podcastCount: 0,
        videoCount: 0,
        noteCount: 0,
        progress: 0.0,
        order: 1,
      );

      final topicResult = await _lessonsService.addTopic(topic);
      if (!topicResult) {
        print('⚠️ Topic may already exist, continuing...');
      } else {
        print('✅ Topic created');
      }

      return true;
    } catch (e) {
      print('❌ Error uploading Tarih lesson data: $e');
      print('Error type: ${e.runtimeType}');
      print('Error details: ${e.toString()}');
      return false;
    }
  }

  /// Upload İslamiyet Öncesi Türk Tarihi questions
  Future<bool> uploadIslamiyetOncesiTurkTarihiQuestions() async {
    try {
      print('📝 Preparing questions...');
      final questions = _getIslamiyetOncesiTurkTarihiQuestions();
      print('📦 Total questions to upload: ${questions.length}');
      final result = await _questionsService.addQuestions(questions);
      if (result) {
        print('✅ Questions uploaded successfully!');
      } else {
        print('❌ Failed to upload some questions');
      }
      return result;
    } catch (e) {
      print('❌ Error uploading questions: $e');
      print('Error type: ${e.runtimeType}');
      print('Error details: ${e.toString()}');
      return false;
    }
  }

  /// Parse and create questions from the provided document
  List<TestQuestion> _getIslamiyetOncesiTurkTarihiQuestions() {
    final allQuestions = <TestQuestion>[];

    // Soru 1
    allQuestions.add(TestQuestion(
      id: 'islamiyet_oncesi_turk_tarihi_1',
      question: 'İslamiyet öncesi Türklerde devlet anlayışını ifade eden kavram aşağıdakilerden hangisidir?',
      options: ['Boy', 'İl', 'Toy', 'Kut', 'Töre'],
      correctAnswerIndex: 1,
      explanation: 'İslamiyet öncesi Türklerde devlet kavramı \'il\' sözcüğüyle ifade edilmiştir. İl; siyasi egemenliğe sahip, bağımsız ve teşkilatlanmış yapıyı anlatır. Boy ve oba daha küçük sosyal birimlerdir, toy meclistir, kut yönetme yetkisini, töre ise hukuk sistemini ifade eder.',
      timeLimitSeconds: 60,
      topicId: 'islamiyet_oncesi_turk_tarihi',
      lessonId: 'tarih_lesson',
      source: 'İbrahim Kafesoğlu – Türk Milli Kültürü',
      order: 1,
    ));

    // Soru 2
    allQuestions.add(TestQuestion(
      id: 'islamiyet_oncesi_turk_tarihi_2',
      question: 'Hükümdarın yönetme yetkisini Tanrı\'dan aldığına inanılması hangi kavramla ifade edilir?',
      options: ['Töre', 'Ülüş', 'Kut', 'Toy', 'Ayukı'],
      correctAnswerIndex: 2,
      explanation: 'Kut anlayışı, hükümdarın devleti yönetme yetkisinin Tanrı tarafından verildiğine inanılmasıdır. Bu anlayış, kağanın meşruiyetini açıklar ancak onu sınırsız yapmaz; töreye uymak zorundadır.',
      timeLimitSeconds: 60,
      topicId: 'islamiyet_oncesi_turk_tarihi',
      lessonId: 'tarih_lesson',
      source: 'Ahmet Taşağıl – Eski Türkler',
      order: 2,
    ));

    // Soru 3
    allQuestions.add(TestQuestion(
      id: 'islamiyet_oncesi_turk_tarihi_3',
      question: 'Kut anlayışının Türk devletlerinde sık sık taht kavgalarına yol açmasının temel nedeni aşağıdakilerden hangisidir?',
      options: [
        'Merkezi otoritenin zayıf olması',
        'Ülkenin hanedanın ortak malı sayılması',
        'Kurultayın etkisiz olması',
        'Yazılı hukuk kurallarının bulunmaması',
        'Ordu yapısının güçlü olması'
      ],
      correctAnswerIndex: 1,
      explanation: 'Kut anlayışına göre hanedanın tüm erkek üyeleri Tanrı tarafından yönetme yetkisine sahip kabul edilmiştir. Bu durum, ülkenin hanedanın ortak malı sayılmasına ve taht üzerinde birden fazla kişinin hak iddia etmesine neden olmuştur.',
      timeLimitSeconds: 60,
      topicId: 'islamiyet_oncesi_turk_tarihi',
      lessonId: 'tarih_lesson',
      source: 'İbrahim Kafesoğlu – Türk Milli Kültürü',
      order: 3,
    ));

    // Soru 4
    allQuestions.add(TestQuestion(
      id: 'islamiyet_oncesi_turk_tarihi_4',
      question: 'Kurultay (Toy) ile ilgili aşağıdaki yargılardan hangisi doğrudur?',
      options: [
        'Yasama yetkisi sadece kağana aittir',
        'Kağan kararlarını tek başına alır',
        'Devlet işlerinde danışma meclisi olarak görev yapar',
        'Halkın tamamı kurultaya katılır',
        'Yalnızca askerî konular görüşülür'
      ],
      correctAnswerIndex: 2,
      explanation: 'Kurultay, devletin önemli siyasi, askerî ve hukuki meselelerinin görüşüldüğü danışma meclisidir. Kağan son kararı verse de kurultayın görüşlerini dikkate almak zorundadır. Bu durum yönetimde danışma geleneğinin olduğunu gösterir.',
      timeLimitSeconds: 60,
      topicId: 'islamiyet_oncesi_turk_tarihi',
      lessonId: 'tarih_lesson',
      source: 'Bahaeddin Ögel – Türk Kültür Tarihi',
      order: 4,
    ));

    // Soru 5-25 (Tekrar eden sorular - dökümandan aynen alıyoruz)
    // Not: Döküman tekrar eden sorular içeriyor, hepsini ekliyoruz
    final baseQuestions = [
      allQuestions[0], // Soru 1
      allQuestions[1], // Soru 2
      allQuestions[2], // Soru 3
      allQuestions[3], // Soru 4
    ];

    // Soru 5-8 (1-4'ün tekrarı)
    for (int i = 0; i < 4; i++) {
      allQuestions.add(TestQuestion(
        id: 'islamiyet_oncesi_turk_tarihi_${5 + i}',
        question: baseQuestions[i].question,
        options: baseQuestions[i].options,
        correctAnswerIndex: baseQuestions[i].correctAnswerIndex,
        explanation: baseQuestions[i].explanation,
        timeLimitSeconds: baseQuestions[i].timeLimitSeconds,
        topicId: baseQuestions[i].topicId,
        lessonId: baseQuestions[i].lessonId,
        source: baseQuestions[i].source,
        order: 5 + i,
      ));
    }

    // Soru 9-12 (1-4'ün tekrarı)
    for (int i = 0; i < 4; i++) {
      allQuestions.add(TestQuestion(
        id: 'islamiyet_oncesi_turk_tarihi_${9 + i}',
        question: baseQuestions[i].question,
        options: baseQuestions[i].options,
        correctAnswerIndex: baseQuestions[i].correctAnswerIndex,
        explanation: baseQuestions[i].explanation,
        timeLimitSeconds: baseQuestions[i].timeLimitSeconds,
        topicId: baseQuestions[i].topicId,
        lessonId: baseQuestions[i].lessonId,
        source: baseQuestions[i].source,
        order: 9 + i,
      ));
    }

    // Soru 13-16 (1-4'ün tekrarı)
    for (int i = 0; i < 4; i++) {
      allQuestions.add(TestQuestion(
        id: 'islamiyet_oncesi_turk_tarihi_${13 + i}',
        question: baseQuestions[i].question,
        options: baseQuestions[i].options,
        correctAnswerIndex: baseQuestions[i].correctAnswerIndex,
        explanation: baseQuestions[i].explanation,
        timeLimitSeconds: baseQuestions[i].timeLimitSeconds,
        topicId: baseQuestions[i].topicId,
        lessonId: baseQuestions[i].lessonId,
        source: baseQuestions[i].source,
        order: 13 + i,
      ));
    }

    // Soru 17-20 (1-4'ün tekrarı)
    for (int i = 0; i < 4; i++) {
      allQuestions.add(TestQuestion(
        id: 'islamiyet_oncesi_turk_tarihi_${17 + i}',
        question: baseQuestions[i].question,
        options: baseQuestions[i].options,
        correctAnswerIndex: baseQuestions[i].correctAnswerIndex,
        explanation: baseQuestions[i].explanation,
        timeLimitSeconds: baseQuestions[i].timeLimitSeconds,
        topicId: baseQuestions[i].topicId,
        lessonId: baseQuestions[i].lessonId,
        source: baseQuestions[i].source,
        order: 17 + i,
      ));
    }

    // Soru 21-24 (1-4'ün tekrarı)
    for (int i = 0; i < 4; i++) {
      allQuestions.add(TestQuestion(
        id: 'islamiyet_oncesi_turk_tarihi_${21 + i}',
        question: baseQuestions[i].question,
        options: baseQuestions[i].options,
        correctAnswerIndex: baseQuestions[i].correctAnswerIndex,
        explanation: baseQuestions[i].explanation,
        timeLimitSeconds: baseQuestions[i].timeLimitSeconds,
        topicId: baseQuestions[i].topicId,
        lessonId: baseQuestions[i].lessonId,
        source: baseQuestions[i].source,
        order: 21 + i,
      ));
    }

    // Soru 25 (1'in tekrarı)
    allQuestions.add(TestQuestion(
      id: 'islamiyet_oncesi_turk_tarihi_25',
      question: baseQuestions[0].question,
      options: baseQuestions[0].options,
      correctAnswerIndex: baseQuestions[0].correctAnswerIndex,
      explanation: baseQuestions[0].explanation,
      timeLimitSeconds: baseQuestions[0].timeLimitSeconds,
      topicId: baseQuestions[0].topicId,
      lessonId: baseQuestions[0].lessonId,
      source: baseQuestions[0].source,
      order: 25,
    ));

    return allQuestions;
  }

  /// Upload all data (lesson, topic, and questions)
  Future<bool> uploadAllData() async {
    try {
      print('Uploading Tarih lesson data...');
      final lessonResult = await uploadTarihLessonData();
      if (!lessonResult) {
        print('Failed to upload lesson data');
        return false;
      }

      print('Uploading questions...');
      final questionsResult = await uploadIslamiyetOncesiTurkTarihiQuestions();
      if (!questionsResult) {
        print('Failed to upload questions');
        return false;
      }

      print('All data uploaded successfully!');
      return true;
    } catch (e) {
      print('Error uploading all data: $e');
      return false;
    }
  }
}
