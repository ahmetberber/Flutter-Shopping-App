import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:Intern/models/Message.dart';
import 'package:Intern/models/User.dart';
import 'package:Intern/models/Item.dart';
import 'package:Intern/services/authenticator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:Intern/main.dart' as ref;

class DatabaseService {
  final CollectionReference userCollRef =
      Firestore.instance.collection('users');
  final CollectionReference itemCollRef =
      Firestore.instance.collection('items');
  final CollectionReference chatCollRef =
      Firestore.instance.collection('chats');
  final AuthService authService = AuthService();

  DocumentSnapshot lastItemDc;
  DocumentSnapshot lastUserDc;

  Future updateUser(User user) async {
    return await userCollRef.document(user.uid).setData({
      'uid': user.uid,
      'name': user.name,
      'email': user.email,
      'password': user.password,
      'img_url': user.img_url
    });
  }

  Future<User> getSpesificUser(String uid) async {
    DocumentSnapshot dc = await userCollRef.document(uid).get();
    return User(
        uid: dc.documentID,
        name: dc.data['name'],
        email: dc.data['email'],
        password: dc.data['password'],
        img_url: dc.data['img_url']);
  }

  Future<List<User>> users({int limit, bool isFirst}) async {
    List<User> userList = List();
    QuerySnapshot querySnapshot;
    if (isFirst || lastUserDc == null)
      querySnapshot = await userCollRef
          .orderBy('name', descending: false)
          .limit(limit)
          .getDocuments();
    else
      querySnapshot = await userCollRef
          .orderBy('name', descending: false)
          .startAfterDocument(lastUserDc)
          .getDocuments();

    for (var dc in querySnapshot.documents) {
      userList.add(User(
          uid: dc.documentID,
          name: dc.data['name'],
          email: dc.data['email'],
          password: dc.data['password'],
          img_url: dc.data['img_url']));
      lastUserDc = dc;
    }
    return userList;
  }

  Future<List<User>> searchUser(String key) async {
    List<User> userList = List();

    QuerySnapshot querySnapshot =
        await userCollRef.orderBy('name', descending: false).getDocuments();

    for (var dc in querySnapshot.documents.where((element) =>
        element.data.toString().toLowerCase().contains(key.toLowerCase()))) {
      userList.add(User(
          uid: dc.documentID,
          name: dc.data['name'],
          email: dc.data['email'],
          password: dc.data['password'],
          img_url: dc.data['img_url']));
    }
    return userList;
  }

  List<Message> _messageListFromSnapshot(QuerySnapshot querySnapshot) {
    return querySnapshot.documents.map((e) {
      return Message(
          uid: e.data['uid'],
          senderId: e.data['senderId'],
          content: e.data['content'],
          time: e.data['time']);
    }).toList();
  }

  Stream<List<Message>> messages(String chatId) {
    return chatCollRef
        .document(chatId)
        .collection(chatId)
        .orderBy('time', descending: false)
        .snapshots()
        .map(_messageListFromSnapshot);
  }

  Future insertMessage(Message message, String chatId) async {
    return await chatCollRef.document(chatId).collection(chatId).add({
      'senderId': message.senderId,
      'content': message.content,
      'time': message.time
    });
  }

  Future deleteMessages(String chatId) async {
    QuerySnapshot querySnapshot =
        await chatCollRef.document(chatId).collection(chatId).getDocuments();

    for (var dc in querySnapshot.documents) {
      dc.reference.delete();
    }
  }

  Future changeName(String name) async {
    FirebaseUser user = await ref.auth.currentUser();
    userCollRef.document(user.uid).setData({
      "name": name,
    }, merge: true);
  }

  Future changeEmail(String email) async {
    FirebaseUser user = await ref.auth.currentUser();
    user.updateEmail(email);
    userCollRef.document(user.uid).setData({
      "email": email,
    }, merge: true);
  }

  Future changePassword(String password) async {
    FirebaseUser user = await ref.auth.currentUser();
    user.updatePassword(password);
    userCollRef.document(user.uid).setData({
      "password": password,
    }, merge: true);
  }

  Future<List<Item>> items({int limit, bool isFirst}) async {
    List<Item> itemList = List();
    QuerySnapshot querySnapshot;
    if (isFirst || lastItemDc == null)
      querySnapshot = await itemCollRef
          .orderBy('date', descending: true)
          .limit(limit)
          .getDocuments();
    else
      querySnapshot = await itemCollRef
          .orderBy('date', descending: true)
          .startAfterDocument(lastItemDc)
          .limit(limit)
          .getDocuments();

    for (var dc in querySnapshot.documents) {
      User author = await getSpesificUser(dc.data['author_id']);
      itemList.add(Item.withAuthor(
          item_uid: dc.documentID,
          author: author,
          title: dc.data['title'],
          explanation: dc.data['explanation'],
          category: dc.data['category'],
          price: dc.data['price'],
          date: dc.data['date'],
          img_url: dc.data['img_url'],
          latitude: dc.data['latitude'],
          longitude: dc.data['longitude']));
      lastItemDc = dc;
    }
    return itemList;
  }

  Future<List<Item>> getSpesificItem(String author_id) async {
    List<Item> itemList = List();
    QuerySnapshot querySnapshot;
    querySnapshot = await itemCollRef
        .where('author_id', isEqualTo: author_id)
        .getDocuments();

    for (var dc in querySnapshot.documents) {
      User author = await getSpesificUser(dc.data['author_id']);
      itemList.add(Item.withAuthor(
          item_uid: dc.documentID,
          author: author,
          title: dc.data['title'],
          explanation: dc.data['explanation'],
          category: dc.data['category'],
          price: dc.data['price'],
          date: dc.data['date'],
          img_url: dc.data['img_url'],
          latitude: dc.data['latitude'],
          longitude: dc.data['longitude']));
    }
    return itemList;
  }

  Future insertItem(Item item) async {
    var map = {
      'author_id': item.author_id,
      'title': item.title,
      'explanation': item.explanation,
      'category': item.category,
      'price': item.price,
      'date': item.date,
      'img_url': item.img_url,
      'latitude': item.latitude,
      'longitude': item.longitude
    };
    await itemCollRef.add(map);
  }

  Future updateItem(Item item) async {
    FirebaseUser firebaseUser = await authService.getCurrentUser();
    if (firebaseUser.uid == item.author.uid) {
      if (item.title != null) {
        await itemCollRef.document(item.item_uid).setData({
          'title': item.title,
        }, merge: true);
      }

      if (item.explanation != null) {
        await itemCollRef.document(item.item_uid).setData({
          'explanation': item.explanation,
        }, merge: true);
      }

      if (item.category != null) {
        await itemCollRef.document(item.item_uid).setData({
          'category': item.category,
        }, merge: true);
      }

      if (item.price != null) {
        await itemCollRef.document(item.item_uid).setData({
          'price': item.price,
        }, merge: true);
      }

      if (item.latitude != null) {
        await itemCollRef.document(item.item_uid).setData({
          'latitude': item.latitude,
        }, merge: true);
      }

      if (item.longitude != null) {
        await itemCollRef.document(item.item_uid).setData({
          'longitude': item.longitude,
        }, merge: true);
      }

      return 1;
    } else
      return null;
  }

  Future deleteItem(Item item) async {
    FirebaseUser firebaseUser = await authService.getCurrentUser();
    if (firebaseUser.uid == item.author.uid) {
      await itemCollRef.document(item.item_uid).delete();
      StorageReference imgRef = await FirebaseStorage.instance
          .ref()
          .getStorage()
          .getReferenceFromUrl(item.img_url);
      await imgRef.delete();
      return 1;
    } else
      return null;
  }
}
