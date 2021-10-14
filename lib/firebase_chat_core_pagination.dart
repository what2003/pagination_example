import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;

class PaginationCore {
  /// Returns a stream of messages from Firebase for a given room
  @override
  static Stream<List<types.Message>> messages(types.Room room, [doc]) {
    int n = 0;
    var quary = (doc != null
        ? FirebaseFirestore.instance
            .collection('rooms/${room.id}/messages')
            .orderBy('createdAt', descending: true)
            .endBeforeDocument(doc)
        : FirebaseFirestore.instance
            .collection('rooms/${room.id}/messages')
            .orderBy('createdAt', descending: true));
    return quary.snapshots().map(
      (snapshot) {
        return snapshot.docs.fold<List<types.Message>>(
          [],
          (previousValue, doc) {
            print(n++);

            final data = doc.data();
            final author = room.users.firstWhere(
              (u) => u.id == data['authorId'],
              orElse: () => types.User(id: data['authorId'] as String),
            );

            data['author'] = author.toJson();
            data['createdAt'] = data['createdAt']?.millisecondsSinceEpoch;
            data['id'] = doc.id;
            data['updatedAt'] = data['updatedAt']?.millisecondsSinceEpoch;
            return [...previousValue, types.Message.fromJson(data)];
          },
        ).toList();
      },
    );
  }

  static Future fetchMessages(types.Room room,
      {var docWhere, int pageSize = 5}) async {
    List<QueryDocumentSnapshot<Map<String, dynamic>>>? quary;
    if (docWhere == null) {
      await FirebaseFirestore.instance
          .collection('rooms/${room.id}/messages')
          .orderBy('createdAt', descending: true)
          .limit(pageSize)
          .get()
          .then((value) {
        if (value.docs.isEmpty) {
          print('chat empty');
        }
        return (quary = value.docs);
      });
    } else {
      await FirebaseFirestore.instance
          .collection('rooms/${room.id}/messages')
          .orderBy('createdAt', descending: true)
          .startAfterDocument(docWhere)
          .limit(pageSize)
          .get()
          .then((value) {
        quary = value.docs;
        if (value.docs.isEmpty) {
          print('no more data');
        } else {}
      }).onError((error, stackTrace) {
        print('--------捕捉错误,到顶的那种----------');
        print(error.toString());
        print(stackTrace.toString());
        return;
      });
    }
    return quary;
  }

  static Future<QueryDocumentSnapshot<Map<String, dynamic>?>?> roomLastMassage(
    types.Room room,
  ) async {
    QueryDocumentSnapshot<Map<String, dynamic>?>? lastDoc;
    await FirebaseFirestore.instance
        .collection('rooms/${room.id}/messages')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get()
        .then((values) {
      if (values.docs.isNotEmpty) {
        lastDoc = values.docs.last;
      }
    });
    return lastDoc;
  }
}
