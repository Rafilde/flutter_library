import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/books.dart';
import 'package:flutter_application_1/dowloadScreen.dart';
import 'package:http/http.dart' as http;
import 'package:vocsy_epub_viewer/epub_viewer.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Books> favorite = [];
  List<Books> books = [];

  Future<List<Books>> getBooks() async {
    const url = "https://escribo.com/books.json";
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      List<Books> bookList = data
          .map((item) => Books(
                title: item['title'],
                author: item['author'],
                coverUrl: item['cover_url'],
                downloadUrl: item['download_url'],
                id: item['id'],
              ))
          .toList();
      return bookList;
    } else {
      throw Exception("Error ${response.statusCode}");
    }
  }

  bool loading = false;
  Dio dio = Dio();
  String filePath = "";

  startDownload(String book) async {
    Directory? appDocDir = Platform.isAndroid
        ? await getExternalStorageDirectory()
        : await getApplicationDocumentsDirectory();

    String path = appDocDir!.path + '/sample.epub';
    File file = File(path);
    if (File(path).existsSync()) {
      await file.create();
      await dio.download(
        book,
        path,
        deleteOnError: true,
        onReceiveProgress: (receivedBytes, totalBytes) {
          setState(() {
            loading = true;
            filePath = path;
          });
        },
      ).whenComplete(() {
        setState(() {
          loading = false;
          filePath = path;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    VocsyEpub.setConfig(
      themeColor: Colors.blue,
      identifier: "iosBook",
      scrollDirection: EpubScrollDirection.ALLDIRECTIONS,
      allowSharing: true,
      enableTts: true,
      nightMode: true,
    );
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Lista de Livros'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Livros'),
              Tab(text: 'Favoritos'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            FutureBuilder<List<Books>>(
              future: getBooks(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text("Erro ao carregar dados ${snapshot.error}"),
                  );
                }
                if (snapshot.hasData) {
                  books = snapshot.data!;
                  return ListView.builder(
                    itemCount: books.length,
                    itemBuilder: (context, index) {
                      final book = books[index];
                      return GestureDetector(
                        onTap: () async {
                          try {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => homeScreen()),
                            );
                            await startDownload(book.downloadUrl);
                            VocsyEpub.open(
                              filePath,
                              lastLocation: EpubLocator.fromJson({
                                "bookId": book.id.toString(),
                                "href": "/OEBPS/ch06.xhtml",
                                "created":
                                    DateTime.now().millisecondsSinceEpoch,
                                "locations": {
                                  "cfi": "epubcfi(/0!/4/4[simple_book]/2/2/6)",
                                }
                              }),
                            );
                          } catch (e) {
                            print("Error opening the book: $e");
                          }
                          Navigator.pop(context);
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              children: [
                                Card(
                                  elevation: 10,
                                  margin: const EdgeInsets.all(10),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8.0),
                                    child: Image.network(
                                      book.coverUrl,
                                      width: 250,
                                      height: 400,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: GestureDetector(
                                    onTap: () {
                                      bool thereIsAnyBook = favorite.any(
                                          (favBook) => favBook.id == book.id);
                                      if (!thereIsAnyBook) {
                                        setState(() {
                                          favorite.add(Books(
                                              author: book.author,
                                              coverUrl: book.coverUrl,
                                              downloadUrl: book.downloadUrl,
                                              id: book.id,
                                              title: book.title));
                                        });
                                      }
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                            BorderRadiusDirectional.only(
                                                topEnd: Radius.circular(8)),
                                      ),
                                      padding: const EdgeInsets.all(8),
                                      child: Text(
                                        'Clique',
                                        style: TextStyle(
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              margin: EdgeInsetsDirectional.only(bottom: 50),
                              alignment: AlignmentDirectional.center,
                              width: 300,
                              child: Column(
                                children: [
                                  Text(
                                    book.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  Text(
                                    book.author,
                                    style: TextStyle(
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }
                return Center(
                  child: CircularProgressIndicator(),
                );
              },
            ),
            // Tela de Favoritos
            Container(
              child: favorite.isEmpty
                  ? Center(
                      child: Text("Adicione livros aos favoritos"),
                    )
                  : ListView.builder(
                      itemCount: favorite.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () async {
                          try {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => homeScreen()),
                            );
                            await startDownload(favorite[index].downloadUrl);
                            VocsyEpub.open(
                              filePath,
                              lastLocation: EpubLocator.fromJson({
                                "bookId": favorite[index].id.toString(),
                                "href": "/OEBPS/ch06.xhtml",
                                "created":
                                    DateTime.now().millisecondsSinceEpoch,
                                "locations": {
                                  "cfi": "epubcfi(/0!/4/4[simple_book]/2/2/6)",
                                }
                              }),
                            );
                          } catch (e) {
                            print("Error opening the book: $e");
                          }
                          Navigator.pop(context);
                        },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Stack(
                                children: [
                                  Card(
                                    elevation: 10,
                                    margin: const EdgeInsets.all(10),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8.0),
                                      child: Image.network(
                                        favorite[index].coverUrl,
                                        width: 250,
                                        height: 400,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 10,
                                    right: 10,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          favorite.removeAt(index);
                                        });
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color.fromARGB(
                                              255, 255, 0, 0),
                                          borderRadius:
                                              BorderRadiusDirectional.only(
                                                  topEnd: Radius.circular(8)),
                                        ),
                                        padding: const EdgeInsets.all(8),
                                        child: Text(
                                          'remover',
                                          style: TextStyle(
                                            color: const Color.fromARGB(
                                                255, 255, 255, 255),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                margin: EdgeInsetsDirectional.only(bottom: 50),
                                width: 300,
                                child: Column(
                                  children: [
                                    Text(
                                      favorite[index].title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    Text(
                                      favorite[index].author,
                                      style: TextStyle(
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: HomeScreen(),
  ));
}
