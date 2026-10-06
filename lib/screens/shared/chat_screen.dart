import 'package:flutter/material.dart';
import '../../core/repository.dart';
import '../../core/theme.dart';

class _Msg {
  final String texto;
  final bool mio;
  _Msg(this.texto, this.mio);
}

/// Chat con "Cingo", el asistente de IA de Limpiecingo (/api/ai/chat).
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgs = <_Msg>[_Msg('¡Hola! 👋 Soy Cingo, el asistente virtual de Limpiecingo. ¿En qué puedo ayudarte?', false)];
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  int? _conversationId;
  bool _enviando = false;

  Future<void> _enviar() async {
    final t = _ctrl.text.trim();
    if (t.isEmpty || _enviando) return;
    setState(() {
      _msgs.add(_Msg(t, true));
      _enviando = true;
      _ctrl.clear();
    });
    _bajar();
    try {
      final r = await Repo.chat(t, _conversationId);
      _conversationId = r['conversation_id'];
      final texto = (r['message'] ?? '').toString().replaceFirst(RegExp(r'^assistant\s*', caseSensitive: false), '').trim();
      setState(() => _msgs.add(_Msg(texto, false)));
    } catch (e) {
      setState(() => _msgs.add(_Msg('No pude responder ahora: $e', false)));
    } finally {
      if (mounted) setState(() => _enviando = false);
      _bajar();
    }
  }

  void _bajar() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent + 80, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
        child: ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.all(12),
          itemCount: _msgs.length + (_enviando ? 1 : 0),
          itemBuilder: (_, i) {
            if (i == _msgs.length) {
              return const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.all(8), child: Text('Cingo está escribiendo…', style: TextStyle(color: Colors.grey))));
            }
            final m = _msgs[i];
            return Align(
              alignment: m.mio ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78),
                decoration: BoxDecoration(
                  color: m.mio ? AppTheme.primary : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
                ),
                child: Text(m.texto, style: TextStyle(color: m.mio ? Colors.white : Colors.black87)),
              ),
            );
          },
        ),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Row(children: [
            Expanded(child: TextField(controller: _ctrl, onSubmitted: (_) => _enviar(), decoration: const InputDecoration(hintText: 'Escribe tu consulta…', contentPadding: EdgeInsets.symmetric(horizontal: 16)))),
            const SizedBox(width: 8),
            IconButton.filled(onPressed: _enviando ? null : _enviar, icon: const Icon(Icons.send)),
          ]),
        ),
      ),
    ]);
  }
}
