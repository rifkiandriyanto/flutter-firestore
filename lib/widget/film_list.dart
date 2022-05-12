import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_firebase/widget/movie_item.dart';
import 'package:flutter_firebase/model/movie_model.dart';

enum MovieQuery {
  year,
  likesAsc,
  likesDesc,
  rated,
  sciFi,
  fantasy,
}

extension on Query<MovieModel> {
  /// Create a firebase query from a [MovieQuery]
  Query<MovieModel> queryBy(MovieQuery query) {
    switch (query) {
      case MovieQuery.fantasy:
        return where('genre', arrayContainsAny: ['Fantasy']);

      case MovieQuery.sciFi:
        return where('genre', arrayContainsAny: ['Sci-Fi']);

      case MovieQuery.likesAsc:
      case MovieQuery.likesDesc:
        return orderBy('likes', descending: query == MovieQuery.likesDesc);

      case MovieQuery.year:
        return orderBy('year', descending: true);

      case MovieQuery.rated:
        return orderBy('rated', descending: true);
    }
  }
}

final moviesRef = FirebaseFirestore.instance
    .collection('firestore-example-app')
    .withConverter<MovieModel>(
      fromFirestore: (snapshots, _) => MovieModel.fromJson(snapshots.data()!),
      toFirestore: (movie, _) => movie.toJson(),
    );

class FilmList extends StatefulWidget {
  const FilmList({Key? key}) : super(key: key);

  @override
  _FilmListState createState() => _FilmListState();
}

class _FilmListState extends State<FilmList> {
  MovieQuery query = MovieQuery.year;

  Future<void> _resetLikes() async {
    final movies = await moviesRef.get();
    WriteBatch batch = FirebaseFirestore.instance.batch();

    for (final movie in movies.docs) {
      batch.update(movie.reference, {'likes': 0});
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Firestore Example: Movies'),

            // This is a example use for 'snapshots in sync'.
            // The view reflects the time of the last Firestore sync; which happens any time a field is updated.
            StreamBuilder(
              stream: FirebaseFirestore.instance.snapshotsInSync(),
              builder: (context, _) {
                return Text(
                  'Latest Snapshot: ${DateTime.now()}',
                  style: Theme.of(context).textTheme.caption,
                );
              },
            )
          ],
        ),
        actions: <Widget>[
          PopupMenuButton<MovieQuery>(
            onSelected: (value) => setState(() => query = value),
            icon: const Icon(Icons.sort),
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem(
                  value: MovieQuery.year,
                  child: Text('Sort by Year'),
                ),
                const PopupMenuItem(
                  value: MovieQuery.rated,
                  child: Text('Sort by Rated'),
                ),
                const PopupMenuItem(
                  value: MovieQuery.likesAsc,
                  child: Text('Sort by Likes ascending'),
                ),
                const PopupMenuItem(
                  value: MovieQuery.likesDesc,
                  child: Text('Sort by Likes descending'),
                ),
                const PopupMenuItem(
                  value: MovieQuery.fantasy,
                  child: Text('Filter genre Fantasy'),
                ),
                const PopupMenuItem(
                  value: MovieQuery.sciFi,
                  child: Text('Filter genre Sci-Fi'),
                ),
              ];
            },
          ),
          PopupMenuButton<String>(
            onSelected: (_) => _resetLikes(),
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem(
                  value: 'reset_likes',
                  child: Text('Reset like counts (WriteBatch)'),
                ),
              ];
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<MovieModel>>(
        stream: moviesRef.queryBy(query).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(snapshot.error.toString()),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.requireData;

          return ListView.builder(
            itemCount: data.size,
            itemBuilder: (context, index) {
              return MovieItem(
                movie: data.docs[index].data(),
                reference: data.docs[index].reference,
              );
            },
          );
        },
      ),
    );
  }
}
