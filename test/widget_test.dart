import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lab1_chat_ui/main.dart';

void main() {
  testWidgets('앱이 뜨고 가짜 대화와 입력창이 보인다', (WidgetTester tester) async {
    await tester.pumpWidget(const ChatLabApp());

    // 제목
    expect(find.text('AI Chat — 실습 1'), findsOneWidget);

    // 할 일 1이 끝났다면 목록이 그려진다
    expect(find.byType(ListView), findsOneWidget);
    expect(find.text('오늘 뭐 배워?'), findsOneWidget);

    // 할 일 3이 끝났다면 입력창과 전송 버튼이 있다
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byTooltip('전송'), findsOneWidget);

    // 입력한 메시지가 목록에 추가된다
    await tester.enterText(find.byType(TextField), '안녕하세요');
    await tester.tap(find.byTooltip('전송'));
    await tester.pump();

    expect(find.text('안녕하세요'), findsOneWidget);

    // 가짜 AI 응답 대기(성공/실패는 무작위)가 끝난다
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('답변 작성 중…'), findsNothing);
  });

  testWidgets('응답을 기다리는 동안 타이핑 표시가 보인다', (WidgetTester tester) async {
    final service = FakeAiService(
      delay: const Duration(seconds: 1),
      shouldFail: () => false,
    );
    await tester.pumpWidget(MaterialApp(home: ChatPage(service: service)));

    await tester.enterText(find.byType(TextField), '로딩 테스트');
    await tester.tap(find.byTooltip('전송'));
    await tester.pump();

    expect(find.text('답변 작성 중…'), findsOneWidget);
    expect(find.text('가짜 AI 응답: 로딩 테스트'), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.text('답변 작성 중…'), findsNothing);
    expect(find.text('가짜 AI 응답: 로딩 테스트'), findsOneWidget);
  });

  testWidgets('가짜 AI 응답이 실패하면 전송 실패 상태가 보인다', (WidgetTester tester) async {
    final service = FakeAiService(
      delay: const Duration(seconds: 1),
      shouldFail: () => true,
    );
    await tester.pumpWidget(MaterialApp(home: ChatPage(service: service)));

    await tester.enterText(find.byType(TextField), '실패 테스트');
    await tester.tap(find.byTooltip('전송'));
    await tester.pump();

    expect(find.text('답변 작성 중…'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.text('전송 실패'), findsOneWidget);
    expect(find.text('답변 작성 중…'), findsNothing);
    expect(find.text('가짜 AI 응답: 실패 테스트'), findsNothing);
  });

  testWidgets('실패한 메시지를 재시도하면 다시 응답을 요청한다', (WidgetTester tester) async {
    var shouldFail = true;
    final service = FakeAiService(
      delay: const Duration(seconds: 1),
      shouldFail: () => shouldFail,
    );
    await tester.pumpWidget(MaterialApp(home: ChatPage(service: service)));

    await tester.enterText(find.byType(TextField), '재시도 테스트');
    await tester.tap(find.byTooltip('전송'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.text('전송 실패'), findsOneWidget);
    expect(find.text('재시도'), findsOneWidget);

    // 이번에는 성공하도록 바꾸고 재시도한다.
    shouldFail = false;
    await tester.tap(find.text('재시도'));
    await tester.pump();

    expect(find.text('답변 작성 중…'), findsOneWidget);
    expect(find.text('전송 실패'), findsNothing);
    expect(find.text('재시도'), findsNothing);
    expect(find.text('재시도 테스트'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.text('가짜 AI 응답: 재시도 테스트'), findsOneWidget);
    expect(find.text('전송 실패'), findsNothing);
    expect(find.text('재시도'), findsNothing);
  });
}
