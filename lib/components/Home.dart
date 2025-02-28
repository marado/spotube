import 'dart:io';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oauth2/oauth2.dart' show AuthorizationException;
import 'package:spotify/spotify.dart' hide Image, Player, Search;
import 'package:spotube/components/Category/CategoryCard.dart';
import 'package:spotube/components/Login.dart';
import 'package:spotube/components/Lyrics.dart';
import 'package:spotube/components/Search/Search.dart';
import 'package:spotube/components/Shared/PageWindowTitleBar.dart';
import 'package:spotube/components/Player/Player.dart';
import 'package:spotube/components/Settings.dart';
import 'package:spotube/components/Library/UserLibrary.dart';
import 'package:spotube/helpers/image-to-url-string.dart';
import 'package:spotube/helpers/oauth-login.dart';
import 'package:spotube/models/LocalStorageKeys.dart';
import 'package:spotube/models/sideBarTiles.dart';
import 'package:spotube/provider/Auth.dart';
import 'package:spotube/provider/SpotifyDI.dart';

List<String> spotifyScopes = [
  "user-library-read",
  "user-library-modify",
  "user-read-private",
  "user-read-email",
  "user-follow-read",
  "user-follow-modify",
  "playlist-read-collaborative"
];

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final PagingController<int, Category> _pagingController =
      PagingController(firstPageKey: 0);

  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance?.addPostFrameCallback((timeStamp) async {
      SharedPreferences localStorage = await SharedPreferences.getInstance();
      String? clientId = localStorage.getString(LocalStorageKeys.clientId);
      String? clientSecret =
          localStorage.getString(LocalStorageKeys.clientSecret);
      String? accessToken =
          localStorage.getString(LocalStorageKeys.accessToken);
      String? refreshToken =
          localStorage.getString(LocalStorageKeys.refreshToken);
      String? expirationStr =
          localStorage.getString(LocalStorageKeys.expiration);
      DateTime? expiration =
          expirationStr != null ? DateTime.parse(expirationStr) : null;
      try {
        Auth authProvider = context.read<Auth>();

        if (clientId != null && clientSecret != null) {
          SpotifyApi spotifyApi = SpotifyApi(
            SpotifyApiCredentials(
              clientId,
              clientSecret,
              accessToken: accessToken,
              refreshToken: refreshToken,
              expiration: expiration,
              scopes: spotifyScopes,
            ),
          );
          SpotifyApiCredentials credentials = await spotifyApi.getCredentials();
          if (credentials.accessToken?.isNotEmpty ?? false) {
            authProvider.setAuthState(
              clientId: clientId,
              clientSecret: clientSecret,
              accessToken:
                  credentials.accessToken, // accessToken can be new/refreshed
              refreshToken: refreshToken,
              expiration: credentials.expiration,
              isLoggedIn: true,
            );
          }
        }
        _pagingController.addPageRequestListener((pageKey) async {
          try {
            SpotifyDI data = context.read<SpotifyDI>();
            Page<Category> categories = await data.spotifyApi.categories
                .list(country: "US")
                .getPage(15, pageKey);

            var items = categories.items!.toList();
            if (pageKey == 0) {
              Category category = Category();
              category.id = "user-featured-playlists";
              category.name = "Featured";
              items.insert(0, category);
            }

            if (categories.isLast && categories.items != null) {
              _pagingController.appendLastPage(items);
            } else if (categories.items != null) {
              _pagingController.appendPage(items, categories.nextOffset);
            }
          } catch (e) {
            _pagingController.error = e;
          }
        });
      } on AuthorizationException catch (e) {
        if (clientId != null && clientSecret != null) {
          oauthLogin(
            context,
            clientId: clientId,
            clientSecret: clientSecret,
          );
        }
      } catch (e, stack) {
        print("[Home.initState]: $e");
        print(stack);
      }
    });
  }

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Auth authProvider = Provider.of<Auth>(context);
    if (!authProvider.isLoggedIn) {
      return const Login();
    }

    return Scaffold(
      body: Column(
        children: [
          WindowTitleBarBox(
            child: Row(
              children: [
                Expanded(
                    child: Row(
                  children: [
                    Container(
                      constraints: const BoxConstraints(maxWidth: 256),
                      color:
                          Theme.of(context).navigationRailTheme.backgroundColor,
                      child: MoveWindow(),
                    ),
                    Expanded(child: MoveWindow()),
                    if (!Platform.isMacOS) const TitleBarActionButtons(),
                  ],
                )),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                NavigationRail(
                  destinations: sidebarTileList
                      .map((e) => NavigationRailDestination(
                            icon: Icon(e.icon),
                            label: Text(
                              e.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ))
                      .toList(),
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (value) => setState(() {
                    _selectedIndex = value;
                  }),
                  extended: true,
                  leading: Padding(
                    padding: const EdgeInsets.only(left: 15),
                    child: Row(children: [
                      Image.asset(
                        "assets/spotube-logo.png",
                        height: 50,
                        width: 50,
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      Text("Spotube",
                          style: Theme.of(context).textTheme.headline4),
                    ]),
                  ),
                  trailing:
                      Consumer<SpotifyDI>(builder: (context, data, widget) {
                    return FutureBuilder<User>(
                      future: data.spotifyApi.me.get(),
                      builder: (context, snapshot) {
                        var avatarImg = imageToUrlString(snapshot.data?.images,
                            index: (snapshot.data?.images?.length ?? 1) - 1);
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundImage:
                                        CachedNetworkImageProvider(avatarImg),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    snapshot.data?.displayName ?? "User's name",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                  icon: const Icon(Icons.settings_outlined),
                                  onPressed: () {
                                    Navigator.of(context)
                                        .push(MaterialPageRoute(
                                      builder: (context) {
                                        return const Settings();
                                      },
                                    ));
                                  }),
                            ],
                          ),
                        );
                      },
                    );
                  }),
                ),
                // contents of the spotify
                if (_selectedIndex == 0)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: PagedListView(
                        pagingController: _pagingController,
                        builderDelegate: PagedChildBuilderDelegate<Category>(
                          itemBuilder: (context, item, index) {
                            return CategoryCard(item);
                          },
                        ),
                      ),
                    ),
                  ),
                if (_selectedIndex == 1) const Search(),
                if (_selectedIndex == 2) const UserLibrary(),
                if (_selectedIndex == 3) const Lyrics(),
              ],
            ),
          ),
          // player itself
          const Player()
        ],
      ),
    );
  }
}
