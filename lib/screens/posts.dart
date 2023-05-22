import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class Posts extends StatefulWidget {
  @override
  _PostsState createState() => _PostsState();
}

class _PostsState extends State<Posts> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _textController = TextEditingController();

  final StreamController<QuerySnapshot> _streamController =
      StreamController<QuerySnapshot>();

  File? _image;

  @override
  void initState() {
    super.initState();
    _titleController.text = '';
    _textController.text = '';
    _startStream();
  }

  Future<void> _saveData() async {
    final title = _titleController.text;
    final text = _textController.text;
    final timestamp = Timestamp.now();

    String? imageUrl;
    if (_image != null) {
      imageUrl = await _uploadImageToFirebase(_image!);
    }

    try {
      await FirebaseFirestore.instance.collection("Stattes").add({
        'title': title,
        'text': text,
        'image': imageUrl,
        'date': timestamp,
      });

      _titleController.clear();
      _textController.clear();
      setState(() {
        _image = null;
      });
      _startStream();
    } catch (error) {
      print('Помилка збереження даних: $error');
    }
  }

  Future<String> _uploadImageToFirebase(File image) async {
    final imageName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final imagePath = 'images/$imageName';

    try {
      await firebase_storage.FirebaseStorage.instance
          .ref(imagePath)
          .putFile(image);
      final imageUrl = await firebase_storage.FirebaseStorage.instance
          .ref(imagePath)
          .getDownloadURL();
      return imageUrl;
    } catch (error) {
      print('Помилка завантаження зображення: $error');
      return '';
    }
  }

  void _startStream() {
    FirebaseFirestore.instance
        .collection('Stattes')
        .snapshots()
        .listen((snapshot) {
      _streamController.add(snapshot);
    });
  }

  @override
  void dispose() {
    _streamController.close();
    super.dispose();
  }

  Future<void> _deletePost(String postId) async {
    try {
      await FirebaseFirestore.instance
          .collection('Stattes')
          .doc(postId)
          .delete();
    } catch (error) {
      print('Помилка видалення поста: $error');
    }
  }

  Future<void> _getImage() async {
    final pickedImage =
        await ImagePicker().getImage(source: ImageSource.gallery);
    if (pickedImage != null) {
      setState(() {
        _image = File(pickedImage.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Пости'),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(15),
          child: Column(
            children: [
              StreamBuilder<QuerySnapshot>(
                stream: _streamController.stream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Text('Помилка отримання даних з Firestore');
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }

                  final data = snapshot.data!.docs.reversed.toList();

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: data.length,
                    itemBuilder: (context, index) {
                      final post = data[index].data() as Map<String, dynamic>;
                      final title = post['title'];
                      final text = post['text'];
                      final date = post['date'] as Timestamp?;
                      final imageUrl = post['image'];
                      final formattedDate = date != null
                          ? DateFormat('dd MMM, yyyy').format(date.toDate())
                          : 'Невідомо';
                      final formattedTime = date != null
                          ? DateFormat('HH:mm:ss').format(date.toDate())
                          : 'Невідомо';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Slidable(
                          key: ValueKey(data[index].id),
                          startActionPane: ActionPane(
                              dismissible:
                                  DismissiblePane(onDismissed: () async {
                                final postId = data[index].id;
                                await _deletePost(postId);
                              }),
                              motion: const ScrollMotion(),
                              children: [
                                SlidableAction(
                                  flex: 2,
                                  onPressed: (BuildContext context) {},
                                  backgroundColor: const Color(0xFFFE4A49),
                                  foregroundColor: Colors.white,
                                  icon: Icons.delete,
                                  label: 'Видалити',
                                )
                              ]),
                          endActionPane: ActionPane(
                              motion: const ScrollMotion(),
                              children: [
                                SlidableAction(
                                  flex: 2,
                                  onPressed: (BuildContext context) {},
                                  backgroundColor:
                                      Color.fromARGB(255, 0, 242, 255),
                                  foregroundColor: Colors.white,
                                  icon: Icons.share,
                                  label: 'Поширити',
                                )
                              ]),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            width: double.infinity,
                            child: ListTile(
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black),
                                  ),
                                  Text(
                                    text,
                                    style: const TextStyle(
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  if (imageUrl != null)
                                    Image.network(
                                      imageUrl,
                                      width: 100,
                                      height: 100,
                                    ),
                                  Text(
                                    'Дата: $formattedDate',
                                    style: const TextStyle(
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    'Час: $formattedTime',
                                    style: const TextStyle(
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(
                height: 20,
              ),
              FloatingActionButton(
                onPressed: () {
                  showModalBottomSheet(
                    showDragHandle: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20.0),
                      ),
                    ),
                    context: context,
                    builder: (BuildContext context) {
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Container(
                          height: MediaQuery.of(context).size.height * 0.8,
                          padding: const EdgeInsets.all(15),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextFormField(
                                controller: _titleController,
                                decoration: const InputDecoration(
                                    labelText: 'Заголовок', filled: true),
                              ),
                              TextFormField(
                                controller: _textController,
                                decoration: const InputDecoration(
                                    labelText: 'Текст', filled: true),
                              ),
                              ElevatedButton(
                                onPressed: _getImage,
                                child: const Text('Додати зображення'),
                              ),
                              if (_image != null) Image.file(_image!),

                              ElevatedButton(
                                onPressed: _saveData,
                                child: const Text('Зберегти'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                child: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
