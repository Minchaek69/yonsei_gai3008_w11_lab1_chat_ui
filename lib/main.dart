import 'dart:math';

import 'package:flutter/material.dart';

void main() => runApp(const ChatLabApp());

class ChatLabApp extends StatelessWidget {
  const ChatLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Chat — 실습 1',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F6FE4)),
        useMaterial3: true,
      ),
      home: const ChatPage(),
    );
  }
}

/// 대화 한 줄의 전송 상태.
enum MessageStatus { sending, sent, failed }

/// 대화 한 줄. 서버 없이 화면만 만들기 위한 최소 모델.
class ChatMessage {
  const ChatMessage({
    required this.text,
    required this.isUser,
    this.status = MessageStatus.sent,
  });

  final String text;
  final bool isUser;
  final MessageStatus status;

  ChatMessage copyWith({MessageStatus? status}) {
    return ChatMessage(
      text: text,
      isUser: isUser,
      status: status ?? this.status,
    );
  }
}

/// 서버 대신 지연과 가끔 발생하는 실패를 흉내 내는 가짜 AI.
class FakeAiService {
  FakeAiService({
    this.delay = const Duration(milliseconds: 900),
    double failureRate = 0.25,
    Random? random,
    bool Function()? shouldFail,
  }) : _shouldFail =
           shouldFail ?? _randomFailure(failureRate, random ?? Random());

  final Duration delay;
  final bool Function() _shouldFail;

  static bool Function() _randomFailure(double rate, Random random) {
    return () => random.nextDouble() < rate;
  }

  Future<String> replyTo(String prompt) async {
    await Future.delayed(delay);
    if (_shouldFail()) throw const FakeAiException();
    return '가짜 AI 응답: $prompt';
  }
}

/// 가짜 AI 응답 실패를 나타내는 예외.
class FakeAiException implements Exception {
  const FakeAiException();

  @override
  String toString() => '가짜 AI 응답 실패';
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, this.service});

  /// 테스트에서 지연 시간을 바꿔 끼울 수 있는 가짜 AI 서비스.
  final FakeAiService? service;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  /// 실습용 가짜 대화 — API를 붙이기 전까지 이 목록으로 화면을 만든다.
  final List<ChatMessage> _messages = [
    const ChatMessage(text: '오늘 뭐 배워?', isUser: true),
    const ChatMessage(text: 'AI 챗봇에 움직이는 응답을 붙입니다.', isUser: false),
    const ChatMessage(text: '타이핑 점은 왜 필요해요?', isUser: true),
    const ChatMessage(text: '응답이 1초를 넘으면 앱이 멈춘 것처럼 보이기 때문입니다.', isUser: false),
  ];

  final TextEditingController _controller = TextEditingController();
  late final FakeAiService _service = widget.service ?? FakeAiService();

  bool get _isWaitingForReply =>
      _messages.any((message) => message.status == MessageStatus.sending);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 서버 없이, 입력한 글을 목록에 추가하고 가짜 AI 응답을 기다린다.
  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isWaitingForReply) return;

    _controller.clear();
    final message = ChatMessage(text: text, isUser: true);
    setState(() {
      _messages.add(message);
    });

    await _requestReply(message);
  }

  /// 가짜 AI를 호출하고 성공/실패에 따라 메시지 상태를 바꾼다.
  Future<void> _requestReply(ChatMessage message) async {
    final index = _messages.indexOf(message);
    if (index == -1) return;

    setState(() {
      _messages[index] = message.copyWith(status: MessageStatus.sending);
    });

    try {
      final reply = await _service.replyTo(message.text);
      if (!mounted) return;
      setState(() {
        _messages[index] = message.copyWith(status: MessageStatus.sent);
        _messages.add(ChatMessage(text: reply, isUser: false));
      });
    } on FakeAiException {
      if (!mounted) return;
      setState(() {
        _messages[index] = message.copyWith(status: MessageStatus.failed);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ 할 일 5 — 키보드가 올라오면 body 높이를 줄여 입력창을 위로 밀어 올린다.
      //    (기본값이 true지만 의도를 드러내기 위해 명시한다.)
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('AI Chat — 실습 1')),
      body: SafeArea(
        child: Column(
          children: [
            // ─────────────────────────────────────────────────────────
            // ✅ 할 일 1 — ListView.builder + reverse: true
            //    reverse:true면 index 0이 화면 맨 아래(최신)다.
            //    그래서 _messages[length - 1 - i]로 거꾸로 꺼낸다.
            // ─────────────────────────────────────────────────────────
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount:
                          _messages.length + (_isWaitingForReply ? 1 : 0),
                      itemBuilder: (context, index) {
                        // reverse:true라 index 0이 맨 아래 — 가장 최신 자리에
                        // 타이핑 표시를 먼저 보여 준다.
                        if (_isWaitingForReply && index == 0) {
                          return const _TypingBubble();
                        }
                        final offset = _isWaitingForReply ? 1 : 0;
                        final message =
                            _messages[_messages.length - 1 - (index - offset)];
                        return _Bubble(message: message);
                      },
                    ),
                  ),
                  // ✅ 할 일 4 — 목록이 비었을 때만 빈 상태 문구를 겹쳐 보여 준다.
                  if (_messages.isEmpty)
                    Center(
                      child: Text(
                        '무엇이든 물어보세요',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ─────────────────────────────────────────────────────────
            // ✅ 할 일 3 — 입력창 (TextField + 전송 버튼)
            // ─────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: '메시지를 입력하세요',
                        filled: true,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isWaitingForReply ? null : _send,
                    tooltip: '전송',
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ───────────────────────────────────────────────────────────────
/// ✅ 할 일 2 — 말풍선 2종 (사용자 오른쪽 / AI 왼쪽)
///
/// · Align으로 좌우를 나누고, 사용자는 primaryContainer,
///   AI는 surfaceContainerHighest 색을 쓴다.
/// · 색은 Theme.of(context).colorScheme에서 꺼내 다크 모드에서도 안전하다.
/// · maxWidth만 잡아 주면 긴 글은 자동으로 줄바꿈된다.
/// ───────────────────────────────────────────────────────────────
class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isUser = message.isUser;
    final isFailed = message.status == MessageStatus.failed;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: const BoxConstraints(maxWidth: 420),
            decoration: BoxDecoration(
              color: isUser
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              message.text,
              style: TextStyle(
                height: 1.35,
                color: isUser
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurface,
              ),
            ),
          ),
          if (isFailed)
            Padding(
              padding: EdgeInsets.only(
                left: isUser ? 0 : 20,
                right: isUser ? 20 : 0,
                bottom: 4,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 16, color: colorScheme.error),
                  const SizedBox(width: 4),
                  Text(
                    '전송 실패',
                    style: TextStyle(fontSize: 12, color: colorScheme.error),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// AI가 응답을 만드는 동안 보여 주는 타이핑/로딩 말풍선.
class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '답변 작성 중…',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
