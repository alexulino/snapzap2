import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() => runApp(const MessengerApp());

class MessengerApp extends StatelessWidget {
  const MessengerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Messenger',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.teal,
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorSchemeSeed: Colors.teal,
          brightness: Brightness.dark,
          useMaterial3: true,
        ),
        home: const LoginScreen(),
      );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _name = TextEditingController();
  final _server = TextEditingController(text: 'ws://192.168.0.10:8080');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    _name.text = p.getString('name') ?? '';
    _server.text = p.getString('server') ?? _server.text;
  }

  Future<void> _join() async {
    final name = _name.text.trim();
    final server = _server.text.trim();
    if (name.isEmpty || server.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    await p.setString('name', name);
    await p.setString('server', server);
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatScreen(name: name, server: server),
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chat_bubble_rounded,
                        size: 64, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 16),
                    Text('Messenger',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _name,
                      decoration: const InputDecoration(
                          labelText: 'Dein Name',
                          border: OutlineInputBorder()),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _server,
                      decoration: const InputDecoration(
                          labelText: 'Server-Adresse',
                          border: OutlineInputBorder()),
                      keyboardType: TextInputType.url,
                      onSubmitted: (_) => _join(),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                          onPressed: _join, child: const Text('Beitreten')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class ChatMessage {
  final String user;
  final String text;
  final DateTime time;
  ChatMessage(this.user, this.text, this.time);
  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        j['user'] as String,
        j['text'] as String,
        DateTime.fromMillisecondsSinceEpoch(j['time'] as int),
      );
}

class ChatScreen extends StatefulWidget {
  final String name;
  final String server;
  const ChatScreen({super.key, required this.name, required this.server});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messages = <ChatMessage>[];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _retry;
  bool _connected = false;
  int _online = 0;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  void _connect() {
    _sub?.cancel();
    try {
      final ch = WebSocketChannel.connect(Uri.parse(widget.server));
      _channel = ch;
      ch.ready.then((_) {
        if (mounted) setState(() => _connected = true);
      }).catchError((_) => _scheduleReconnect());
      _sub = ch.stream.listen(_onData,
          onDone: _scheduleReconnect, onError: (_) => _scheduleReconnect());
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!mounted) return;
    setState(() => _connected = false);
    _retry?.cancel();
    _retry = Timer(const Duration(seconds: 3), () {
      if (mounted) _connect();
    });
  }

  void _onData(dynamic raw) {
    final m = jsonDecode(raw as String) as Map<String, dynamic>;
    setState(() {
      switch (m['type']) {
        case 'history':
          _messages
            ..clear()
            ..addAll((m['messages'] as List)
                .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)));
          break;
        case 'msg':
          _messages.add(ChatMessage.fromJson(m));
          break;
        case 'online':
          _online = m['count'] as int;
          break;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty || !_connected) return;
    _channel?.sink
        .add(jsonEncode({'type': 'msg', 'user': widget.name, 'text': text}));
    _input.clear();
  }

  @override
  void dispose() {
    _retry?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Allgemeiner Chat'),
            Text(
              _connected ? '$_online online' : 'Verbinde …',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final m = _messages[i];
                final mine = m.user == widget.name;
                return Align(
                  alignment:
                      mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: mine
                          ? cs.primaryContainer
                          : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!mine)
                          Text(m.user,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: cs.primary)),
                        Text(m.text),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(_hm(m.time),
                              style: TextStyle(
                                  fontSize: 10,
                                  color: cs.onSurfaceVariant)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Nachricht schreiben',
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                      onPressed: _connected ? _send : null,
                      icon: const Icon(Icons.send_rounded)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
