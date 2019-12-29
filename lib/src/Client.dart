/*
 * Copyright (c) 2019 Zender & Kurtz GbR.
 *
 * Authors:
 *   Christian Pauly <krille@famedly.com>
 *   Marcel Radzio <mtrnord@famedly.com>
 *
 * This file is part of famedlysdk.
 *
 * famedlysdk is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * famedlysdk is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with famedlysdk.  If not, see <http://www.gnu.org/licenses/>.
 */

import 'dart:async';
import 'dart:core';

import 'package:famedlysdk/famedlysdk.dart';
import 'package:famedlysdk/src/AccountData.dart';
import 'package:famedlysdk/src/Presence.dart';
import 'package:famedlysdk/src/StoreAPI.dart';
import 'package:famedlysdk/src/sync/UserUpdate.dart';
import 'package:famedlysdk/src/utils/MatrixFile.dart';

import 'Connection.dart';
import 'Room.dart';
import 'RoomList.dart';
//import 'Store.dart';
import 'RoomState.dart';
import 'User.dart';
import 'requests/SetPushersRequest.dart';
import 'responses/PushrulesResponse.dart';
import 'utils/Profile.dart';

typedef AccountDataEventCB = void Function(AccountData accountData);
typedef PresenceCB = void Function(Presence presence);

/// Represents a Matrix client to communicate with a
/// [Matrix](https://matrix.org) homeserver and is the entry point for this
/// SDK.
class Client {
  /// Handles the connection for this client.
  Connection connection;

  /// Optional persistent store for all data.
  StoreAPI store;

  Client(this.clientName, {this.debug = false, this.store}) {
    connection = Connection(this);

    if (this.clientName != "testclient") store = null; //Store(this);
    connection.onLoginStateChanged.stream.listen((loginState) {
      print("LoginState: ${loginState.toString()}");
    });
  }

  /// Whether debug prints should be displayed.
  final bool debug;

  /// The required name for this client.
  final String clientName;

  /// The homeserver this client is communicating with.
  String homeserver;

  /// The Matrix ID of the current logged user.
  String userID;

  /// This is the access token for the matrix client. When it is undefined, then
  /// the user needs to sign in first.
  String accessToken;

  /// This points to the position in the synchronization history.
  String prevBatch;

  /// The device ID is an unique identifier for this device.
  String deviceID;

  /// The device name is a human readable identifier for this device.
  String deviceName;

  /// Which version of the matrix specification does this server support?
  List<String> matrixVersions;

  /// Wheither the server supports lazy load members.
  bool lazyLoadMembers = false;

  /// Returns the current login state.
  bool isLogged() => accessToken != null;

  /// A list of all rooms the user is participating or invited.
  RoomList roomList;

  /// Key/Value store of account data.
  Map<String, AccountData> accountData = {};

  /// Presences of users by a given matrix ID
  Map<String, Presence> presences = {};

  /// Callback will be called on account data updates.
  AccountDataEventCB onAccountData;

  /// Callback will be called on presences.
  PresenceCB onPresence;

  void handleUserUpdate(UserUpdate userUpdate) {
    if (userUpdate.type == "account_data") {
      AccountData newAccountData = AccountData.fromJson(userUpdate.content);
      accountData[newAccountData.typeKey] = newAccountData;
      if (onAccountData != null) onAccountData(newAccountData);
    }
    if (userUpdate.type == "presence") {
      Presence newPresence = Presence.fromJson(userUpdate.content);
      presences[newPresence.sender] = newPresence;
      if (onPresence != null) onPresence(newPresence);
    }
  }

  Map<String, dynamic> get directChats =>
      accountData["m.direct"] != null ? accountData["m.direct"].content : {};

  /// Returns the (first) room ID from the store which is a private chat with the user [userId].
  /// Returns null if there is none.
  String getDirectChatFromUserId(String userId) {
    if (accountData["m.direct"] != null &&
        accountData["m.direct"].content[userId] is List<dynamic> &&
        accountData["m.direct"].content[userId].length > 0) {
      if (roomList.getRoomById(accountData["m.direct"].content[userId][0]) !=
          null) return accountData["m.direct"].content[userId][0];
      (accountData["m.direct"].content[userId] as List<dynamic>)
          .remove(accountData["m.direct"].content[userId][0]);
      connection.jsonRequest(
          type: HTTPType.PUT,
          action: "/client/r0/user/${userID}/account_data/m.direct",
          data: directChats);
      return getDirectChatFromUserId(userId);
    }
    for (int i = 0; i < roomList.rooms.length; i++)
      if (roomList.rooms[i].membership == Membership.invite &&
          roomList.rooms[i].states[userID]?.senderId == userId &&
          roomList.rooms[i].states[userID].content["is_direct"] == true)
        return roomList.rooms[i].id;
    return null;
  }

  /// Checks the supported versions of the Matrix protocol and the supported
  /// login types. Returns false if the server is not compatible with the
  /// client. Automatically sets [matrixVersions] and [lazyLoadMembers].
  /// Throws FormatException, TimeoutException and MatrixException on error.
  Future<bool> checkServer(serverUrl) async {
    try {
      homeserver = serverUrl;
      final versionResp = await connection.jsonRequest(
          type: HTTPType.GET, action: "/client/versions");

      final List<String> versions = List<String>.from(versionResp["versions"]);

      for (int i = 0; i < versions.length; i++) {
        if (versions[i] == "r0.5.0")
          break;
        else if (i == versions.length - 1) {
          return false;
        }
      }

      matrixVersions = versions;

      if (versionResp.containsKey("unstable_features") &&
          versionResp["unstable_features"].containsKey("m.lazy_load_members")) {
        lazyLoadMembers = versionResp["unstable_features"]
                ["m.lazy_load_members"]
            ? true
            : false;
      }

      final loginResp = await connection.jsonRequest(
          type: HTTPType.GET, action: "/client/r0/login");

      final List<dynamic> flows = loginResp["flows"];

      for (int i = 0; i < flows.length; i++) {
        if (flows[i].containsKey("type") &&
            flows[i]["type"] == "m.login.password")
          break;
        else if (i == flows.length - 1) {
          return false;
        }
      }
      return true;
    } catch (_) {
      this.homeserver = this.matrixVersions = null;
      rethrow;
    }
  }

  /// Handles the login and allows the client to call all APIs which require
  /// authentication. Returns false if the login was not successful. Throws
  /// MatrixException if login was not successful.
  Future<bool> login(String username, String password) async {
    final loginResp = await connection
        .jsonRequest(type: HTTPType.POST, action: "/client/r0/login", data: {
      "type": "m.login.password",
      "user": username,
      "identifier": {
        "type": "m.id.user",
        "user": username,
      },
      "password": password,
      "initial_device_display_name": "Famedly Talk"
    });

    final userID = loginResp["user_id"];
    final accessToken = loginResp["access_token"];
    if (userID == null || accessToken == null) {
      return false;
    }

    await connection.connect(
        newToken: accessToken,
        newUserID: userID,
        newHomeserver: homeserver,
        newDeviceName: "",
        newDeviceID: "",
        newMatrixVersions: matrixVersions,
        newLazyLoadMembers: lazyLoadMembers);
    return true;
  }

  /// Sends a logout command to the homeserver and clears all local data,
  /// including all persistent data from the store.
  Future<void> logout() async {
    try {
      await connection.jsonRequest(
          type: HTTPType.POST, action: "/client/r0/logout");
    } catch (exception) {
      rethrow;
    } finally {
      await connection.clear();
    }
  }

  /// Get the combined profile information for this user. This API may be used to
  /// fetch the user's own profile information or other users; either locally
  /// or on remote homeservers.
  Future<Profile> getProfileFromUserId(String userId) async {
    final dynamic resp = await connection.jsonRequest(
        type: HTTPType.GET, action: "/client/r0/profile/${userId}");
    return Profile.fromJson(resp);
  }

  /// Creates a new [RoomList] object.
  RoomList getRoomList(
      {onRoomListUpdateCallback onUpdate,
      onRoomListInsertCallback onInsert,
      onRoomListRemoveCallback onRemove}) {
    List<Room> rooms = roomList.rooms;
    return RoomList(
        client: this,
        onlyLeft: false,
        onUpdate: onUpdate,
        onInsert: onInsert,
        onRemove: onRemove,
        rooms: rooms);
  }

  Future<List<Room>> get archive async {
    List<Room> archiveList = [];
    String syncFilters =
        '{"room":{"include_leave":true,"timeline":{"limit":10}}}';
    String action = "/client/r0/sync?filter=$syncFilters&timeout=0";
    final sync =
        await connection.jsonRequest(type: HTTPType.GET, action: action);
    if (sync["rooms"]["leave"] is Map<String, dynamic>) {
      for (var entry in sync["rooms"]["leave"].entries) {
        final String id = entry.key;
        final dynamic room = entry.value;
        print(id);
        print(room.toString());
        Room leftRoom = Room(
            id: id,
            membership: Membership.leave,
            client: this,
            roomAccountData: {},
            mHeroes: []);
        if (room["account_data"] is Map<String, dynamic> &&
            room["account_data"]["events"] is List<dynamic>) {
          for (dynamic event in room["account_data"]["events"]) {
            leftRoom.roomAccountData[event["type"]] =
                RoomAccountData.fromJson(event, leftRoom);
          }
        }
        if (room["timeline"] is Map<String, dynamic> &&
            room["timeline"]["events"] is List<dynamic>) {
          for (dynamic event in room["timeline"]["events"]) {
            leftRoom.setState(RoomState.fromJson(event, leftRoom));
          }
        }
        if (room["state"] is Map<String, dynamic> &&
            room["state"]["events"] is List<dynamic>) {
          for (dynamic event in room["state"]["events"]) {
            leftRoom.setState(RoomState.fromJson(event, leftRoom));
          }
        }
        archiveList.add(leftRoom);
      }
    }
    return archiveList;
  }

  /// Searches in the roomList and in the archive for a room with the given [id].
  Room getRoomById(String id) => roomList.getRoomById(id);

  Future<dynamic> joinRoomById(String id) async {
    return await connection.jsonRequest(
        type: HTTPType.POST, action: "/client/r0/join/$id");
  }

  /// Loads the contact list for this user excluding the user itself.
  /// Currently the contacts are found by discovering the contacts of
  /// the famedlyContactDiscovery room, which is
  /// defined by the autojoin room feature in Synapse.
  Future<List<User>> loadFamedlyContacts() async {
    List<User> contacts = [];
    Room contactDiscoveryRoom = roomList
        .getRoomByAlias("#famedlyContactDiscovery:${userID.split(":")[1]}");
    if (contactDiscoveryRoom != null)
      contacts = await contactDiscoveryRoom.requestParticipants();
    else {
      Map<String, bool> userMap = {};
      for (int i = 0; i < roomList.rooms.length; i++) {
        List<User> roomUsers = roomList.rooms[i].getParticipants();
        for (int j = 0; j < roomUsers.length; j++) {
          if (userMap[roomUsers[j].id] != true) contacts.add(roomUsers[j]);
          userMap[roomUsers[j].id] = true;
        }
      }
    }
    return contacts;
  }

  @Deprecated('Please use [createRoom] instead!')
  Future<String> createGroup(List<User> users) => createRoom(invite: users);

  /// Creates a new group chat and invites the given Users and returns the new
  /// created room ID. If [params] are provided, invite will be ignored. For the
  /// moment please look at https://matrix.org/docs/spec/client_server/r0.5.0#post-matrix-client-r0-createroom
  /// to configure [params].
  Future<String> createRoom(
      {List<User> invite, Map<String, dynamic> params}) async {
    List<String> inviteIDs = [];
    if (params == null && invite != null)
      for (int i = 0; i < invite.length; i++) inviteIDs.add(invite[i].id);

    try {
      final dynamic resp = await connection.jsonRequest(
          type: HTTPType.POST,
          action: "/client/r0/createRoom",
          data: params == null
              ? {
                  "invite": inviteIDs,
                }
              : params);
      return resp["room_id"];
    } catch (e) {
      rethrow;
    }
  }

  /// Uploads a new user avatar for this user.
  Future<void> setAvatar(MatrixFile file) async {
    final uploadResp = await connection.upload(file);
    await connection.jsonRequest(
        type: HTTPType.PUT,
        action: "/client/r0/profile/$userID/avatar_url",
        data: {"avatar_url": uploadResp});
    return;
  }

  /// Fetches the pushrules for the logged in user.
  /// These are needed for notifications on Android
  Future<PushrulesResponse> getPushrules() async {
    final dynamic resp = await connection.jsonRequest(
      type: HTTPType.GET,
      action: "/client/r0/pushrules/",
    );

    return PushrulesResponse.fromJson(resp);
  }

  /// This endpoint allows the creation, modification and deletion of pushers for this user ID.
  Future<void> setPushers(SetPushersRequest data) async {
    await connection.jsonRequest(
      type: HTTPType.POST,
      action: "/client/r0/pushers/set",
      data: data.toJson(),
    );
    return;
  }
}
