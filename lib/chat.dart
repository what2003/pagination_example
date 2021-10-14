import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_firebase_chat_core/flutter_firebase_chat_core.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_chat_core_pagination.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    Key? key,
    required this.room,
  }) : super(key: key);

  final types.Room room;

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  bool _isAttachmentUploading = false;

  void _handleAtachmentPressed() {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: SizedBox(
            height: 144,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _handleImageSelection();
                  },
                  child: const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Photo'),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _handleFileSelection();
                  },
                  child: const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('File'),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleFileSelection() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );

    if (result != null) {
      _setAttachmentUploading(true);
      final name = result.files.single.name;
      final filePath = result.files.single.path;
      final file = File(filePath!);

      try {
        final reference = FirebaseStorage.instance.ref(name);
        await reference.putFile(file);
        final uri = await reference.getDownloadURL();

        final message = types.PartialFile(
          mimeType: lookupMimeType(filePath),
          name: name,
          size: result.files.single.size,
          uri: uri,
        );

        FirebaseChatCore.instance.sendMessage(message, widget.room.id);
        _setAttachmentUploading(false);
      } finally {
        _setAttachmentUploading(false);
      }
    }
  }

  void _handleImageSelection() async {
    final result = await ImagePicker().pickImage(
      imageQuality: 70,
      maxWidth: 1440,
      source: ImageSource.gallery,
    );

    if (result != null) {
      _setAttachmentUploading(true);
      final file = File(result.path);
      final size = file.lengthSync();
      final bytes = await result.readAsBytes();
      final image = await decodeImageFromList(bytes);
      final name = result.name;

      try {
        final reference = FirebaseStorage.instance.ref(name);
        await reference.putFile(file);
        final uri = await reference.getDownloadURL();

        final message = types.PartialImage(
          height: image.height.toDouble(),
          name: name,
          size: size,
          uri: uri,
          width: image.width.toDouble(),
        );

        FirebaseChatCore.instance.sendMessage(
          message,
          widget.room.id,
        );
        _setAttachmentUploading(false);
      } finally {
        _setAttachmentUploading(false);
      }
    }
  }

  void _handleMessageTap(types.Message message) async {
    if (message is types.FileMessage) {
      var localPath = message.uri;

      if (message.uri.startsWith('http')) {
        final client = http.Client();
        final request = await client.get(Uri.parse(message.uri));
        final bytes = request.bodyBytes;
        final documentsDir = (await getApplicationDocumentsDirectory()).path;
        localPath = '$documentsDir/${message.name}';

        if (!File(localPath).existsSync()) {
          final file = File(localPath);
          await file.writeAsBytes(bytes);
        }
      }

      await OpenFile.open(localPath);
    }
  }

  void _handlePreviewDataFetched(
    types.TextMessage message,
    types.PreviewData previewData,
  ) {
    final updatedMessage = message.copyWith(previewData: previewData);

    FirebaseChatCore.instance.updateMessage(updatedMessage, widget.room.id);
  }

  void _handleSendPressed(types.PartialText message) {
    FirebaseChatCore.instance.sendMessage(
      message,
      widget.room.id,
    );
  }

  void _setAttachmentUploading(bool uploading) {
    setState(() {
      _isAttachmentUploading = uploading;
    });
  }
//-----------------------------the part I have edited for pagination example----------------------------------

// docsTemp for temp store every new fetch page's docs which use FethcMessages()
  List<QueryDocumentSnapshot<Map<String, dynamic>>>? docsTemp = [];

  //docAnchorForStream is first page's first doc,
  QueryDocumentSnapshot<Map<String, dynamic>>? docAnchorForStream;

  //all pages meassages without new one from stream
  List<types.Message> messagesToShow = [];

  bool _isLastPage = false;
  bool _isLoading = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          systemOverlayStyle: SystemUiOverlayStyle.light,
          title: const Text('Chat'),
        ),
        body: StreamBuilder<types.Room>(
            initialData: widget.room,
            stream: FirebaseChatCore.instance.room(widget.room.id),
            builder: (context, snapshot) {
              return _isLoading
                  ? Stack(
                      children: [
                        chatWidget([]),
                        const Center(
                          child: CircularProgressIndicator(),
                        )
                      ],
                    )
                  : StreamBuilder<List<types.Message>>(
                      initialData: const [],
                      stream: PaginationCore.messages(
                          snapshot.data!, docAnchorForStream),
                      builder: (context, snapshot) {
                        return chatWidget([
                          ...snapshot.data ?? [],
                          ...messagesToShow,
                        ]);
                      },
                    );
            }));
  }

  SafeArea chatWidget(List<types.Message> messages) {
    return SafeArea(
      bottom: false,
      child: Chat(
        isAttachmentUploading: _isAttachmentUploading,
        messages: messages,
        onAttachmentPressed: _handleAtachmentPressed,
        onMessageTap: _handleMessageTap,
        onPreviewDataFetched: _handlePreviewDataFetched,
        onSendPressed: _handleSendPressed,
        user: types.User(
          id: FirebaseChatCore.instance.firebaseUser?.uid ?? '',
        ),
        onEndReached: _onEndReached,
        onEndReachedThreshold: 1,
        isLastPage: _isLastPage,
      ),
    );
  }

  Future<void> _onEndReached() async {
    if (!_isLastPage) {
      docsTemp = await PaginationCore.fetchMessages(widget.room,
          docWhere: docsTemp!.isEmpty ? null : docsTemp!.last, pageSize: 7);
      if (docsTemp!.isEmpty) {
        _isLastPage = true;
      } else {
        messagesToShow = messagesDealt(docsTemp!, messagesToShow);
        setState(() {});
      }
    }
  }

  List<types.Message> messagesDealt(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docsTemp,
      List<types.Message> previousMessages) {
    for (var doc in docsTemp) {
      final data = doc.data();
      final author = widget.room.users.firstWhere(
        (u) => u.id == data['authorId'],
        orElse: () => types.User(id: data['authorId'] as String),
      );

      data['author'] = author.toJson();
      data['createdAt'] = data['createdAt']?.millisecondsSinceEpoch;
      data['id'] = doc.id;
      data['updatedAt'] = data['updatedAt']?.millisecondsSinceEpoch;
      previousMessages.add(types.Message.fromJson(data));
    }
    return previousMessages;
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?>?
      firstFetchMessages() async {
    // check it is empty room or has messages
    var lastmessage = await PaginationCore.roomLastMassage(widget.room);
    if (lastmessage == null) {
      _isLoading = false;
    } else {
      docsTemp = await PaginationCore.fetchMessages(widget.room,
          docWhere: docsTemp!.isEmpty ? null : docsTemp!.last, pageSize: 10);

      docAnchorForStream = docsTemp!.first;
      messagesToShow = messagesDealt(docsTemp!, messagesToShow);
      _isLoading = false;
    }
    setState(() {});
    return docAnchorForStream;
  }

  @override
  void initState() {
    firstFetchMessages();
    super.initState();
  }
}
