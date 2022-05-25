/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2022 Famedly GmbH
 *
 *   This program is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Affero General Public License as
 *   published by the Free Software Foundation, either version 3 of the
 *   License, or (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *   GNU Affero General Public License for more details.
 *
 *   You should have received a copy of the GNU Affero General Public License
 *   along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:async';

import '../matrix.dart';

class RoomList {
  final Client client;
  final void Function()? onUpdate;
  final void Function(int index)? onChange;
  final void Function(int index)? onInsert;
  final void Function(int index)? onRemove;

  StreamSubscription<SyncUpdate>? _onSyncSub;

  late List<Room> _roomsIds;

  RoomList(this.client,
      {this.onUpdate, this.onRemove, this.onChange, this.onInsert})
      : _roomsIds = client.rooms.toList() {
    _onSyncSub =
        client.onSync.stream.where((up) => up.rooms != null).listen(_onSync);
  }

  bool _syncContainRooms(SyncUpdate update, Room room) {
    if (update.rooms == null) return false;

    if ((update.rooms?.invite?.keys.contains(room.id) ?? false) ||
        (update.rooms?.join?.keys.contains(room.id) ?? false) ||
        (update.rooms?.leave?.keys.contains(room.id) ?? false)) return true;

    return false;
  }

  void _onSync(SyncUpdate sync) {
    // first we trigger instertion and deletion
    final newRooms = client.rooms.toList();

    for (var i = 0; i < rooms.length; i++) {
      final room = newRooms[i];
      if (!_roomsIds.contains(room)) {
        _roomsIds.insert(i, room);
        onInsert?.call(i);
      }
    }

    for (var i = 0; i < _roomsIds.length; i++) {
      if (!newRooms.contains(_roomsIds[i])) {
        _roomsIds.removeAt(i);
        onRemove?.call(i);
        i--;
      }
    }

    _seeIfRoomChanged(sync: sync, list: _roomsIds, newList: newRooms);
    onUpdate?.call();
  }

  void _seeIfRoomChanged(
      {required SyncUpdate sync,
      required List<Room> list,
      required List<Room> newList}) {
    final n = list.length;
    final modifications = List.filled(list.length, 0);

    var i = 0;
    while (i < n) {
      final pos = list.indexOf(newList[i]);

      var index = 1;
      while (pos + index < n &&
          i + index < n &&
          list[pos + index] == newList[i + index]) {
        index++;
      }

      for (var j = 0; j < index; j++) {
        modifications[i + j] = index;
      }
      i += index;
    }

    // apply modifications

    // if there is too much isolated elements, the B algorithm is sub optimal as
    // stuck in long-running loops.
    // TODO: see why exactly what is the lower limit.
    var sum = 0;
    modifications.forEach((element) {
      sum += element;
    });
    sum -= n;

    final disableB = sum < n;

    var modif = 0;
    i = 0;
    while (i < list.length) {
      if (list[i] != newList[i]) {
        final pos = list.indexOf(newList[i]);
        final pos_inversed = newList.indexOf(list[i]);

        if (disableB || modifications[i] <= modifications[pos_inversed]) {
          // A
          final element = list[pos];
          list.removeAt(pos);
          onRemove?.call(pos);

          list.insert(i, element);
          onInsert?.call(i);

          if (i > pos) {
            // never happens
            i++;
          }
          modif++;
        } else {
          // B
          final element = list[i];
          list.removeAt(i);
          onRemove?.call(i);

          list.insert(pos_inversed, element);
          onInsert?.call(pos_inversed);

          if (i > pos_inversed) {
            // never happens
            i++;
          }
          modif++;
        }
      } else {
        if (_syncContainRooms(sync, newList[i])) {
          onChange?.call(i);
        }
        i++;
      }

      if (modif > 2 * n) {
        // TODO: here we hit an error, we should rerender all the list
        _roomsIds = client.rooms;
        onUpdate?.call();
        break;
      }
    }
  }

  void dispose() => _onSyncSub?.cancel();

  List<Room> get rooms => _roomsIds;
}