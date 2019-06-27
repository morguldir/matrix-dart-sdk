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

import 'package:flutter_test/flutter_test.dart';
import 'package:famedlysdk/src/Client.dart';
import 'package:famedlysdk/src/Room.dart';
import 'package:famedlysdk/src/Timeline.dart';
import 'package:famedlysdk/src/sync/EventUpdate.dart';
import 'package:famedlysdk/src/utils/ChatTime.dart';
import 'FakeMatrixApi.dart';

void main() {
  /// All Tests related to the MxContent
  group("Timeline", () {
    final String roomID = "!1234:example.com";
    final testTimeStamp = ChatTime.now().toTimeStamp();
    int updateCount = 0;
    List<int> insertList = [];

    Client client = Client("testclient", debug: true);
    client.connection.httpClient = FakeMatrixApi();
    client.homeserver = "https://fakeServer.notExisting";

    Room room = Room(id: roomID, client: client);
    Timeline timeline = Timeline(
        room: room,
        events: [],
        onUpdate: () {
          updateCount++;
        },
        onInsert: (int insertID) {
          insertList.add(insertID);
        });

    test("Create", () async {
      client.connection.onEvent.add(EventUpdate(
          type: "timeline",
          roomID: roomID,
          eventType: "m.room.message",
          content: {
            "type": "m.room.message",
            "content": {"msgtype": "m.text", "body": "Testcase"},
            "sender": "@alice:example.com",
            "status": 2,
            "event_id": "1",
            "origin_server_ts": testTimeStamp
          }));

      client.connection.onEvent.add(EventUpdate(
          type: "timeline",
          roomID: roomID,
          eventType: "m.room.message",
          content: {
            "type": "m.room.message",
            "content": {"msgtype": "m.text", "body": "Testcase"},
            "sender": "@alice:example.com",
            "status": 2,
            "event_id": "2",
            "origin_server_ts": testTimeStamp - 1000
          }));

      expect(timeline.sub != null, true);

      await new Future.delayed(new Duration(milliseconds: 50));

      expect(updateCount, 2);
      expect(insertList, [0, 0]);
      expect(insertList.length, timeline.events.length);
      expect(timeline.events.length, 2);
      expect(timeline.events[0].id, "1");
      expect(timeline.events[0].sender.id, "@alice:example.com");
      expect(timeline.events[0].time.toTimeStamp(), testTimeStamp);
      expect(timeline.events[0].environment, "m.room.message");
      expect(timeline.events[0].getBody(), "Testcase");
      expect(timeline.events[0].time > timeline.events[1].time, true);
    });

    test("Send message", () async {
      room.sendTextEvent("test", txid: "1234");

      await new Future.delayed(new Duration(milliseconds: 50));

      expect(updateCount, 4);
      expect(insertList, [0, 0, 0]);
      expect(insertList.length, timeline.events.length);
      expect(timeline.events[0].content["txid"], "1234");
      expect(timeline.events[0].id, "42");
      expect(timeline.events[0].status, 1);

      client.connection.onEvent.add(EventUpdate(
          type: "timeline",
          roomID: roomID,
          eventType: "m.room.message",
          content: {
            "type": "m.room.message",
            "content": {"msgtype": "m.text", "body": "test"},
            "sender": "@alice:example.com",
            "status": 2,
            "event_id": "42",
            "unsigned": {"transaction_id": "1234"},
            "origin_server_ts": DateTime.now().millisecondsSinceEpoch
          }));

      await new Future.delayed(new Duration(milliseconds: 50));

      expect(updateCount, 5);
      expect(insertList, [0, 0, 0]);
      expect(insertList.length, timeline.events.length);
      expect(timeline.events[0].id, "42");
      expect(timeline.events[0].status, 2);
    });

    test("Send message with error", () async {
      client.connection.onEvent.add(EventUpdate(
          type: "timeline",
          roomID: roomID,
          eventType: "m.room.message",
          content: {
            "type": "m.room.message",
            "content": {"msgtype": "m.text", "body": "Testcase"},
            "sender": "@alice:example.com",
            "status": 0,
            "event_id": "abc",
            "origin_server_ts": testTimeStamp
          }));
      await new Future.delayed(new Duration(milliseconds: 50));
      room.sendTextEvent("test", txid: "errortxid");
      await new Future.delayed(new Duration(milliseconds: 50));
      room.sendTextEvent("test", txid: "errortxid2");
      await new Future.delayed(new Duration(milliseconds: 50));
      room.sendTextEvent("test", txid: "errortxid3");
      await new Future.delayed(new Duration(milliseconds: 50));

      expect(updateCount, 12);
      expect(insertList, [0, 0, 0, 0, 0, 0, 0]);
      expect(insertList.length, timeline.events.length);
      expect(timeline.events[0].content["txid"], "errortxid3");
      expect(timeline.events[0].status, -1);
      expect(timeline.events[1].content["txid"], "errortxid2");
      expect(timeline.events[1].status, -1);
      expect(timeline.events[2].content["txid"], "errortxid");
      expect(timeline.events[2].status, -1);
    });

    test("Remove message", () async {
      timeline.events[0].remove();

      await new Future.delayed(new Duration(milliseconds: 50));

      expect(updateCount, 13);

      expect(insertList, [0, 0, 0, 0, 0, 0, 0]);
      expect(timeline.events.length, 6);
      expect(timeline.events[0].content["txid"], "errortxid2");
      expect(timeline.events[0].status, -1);
    });

    test("Resend message", () async {
      timeline.events[0].sendAgain(txid: "1234");

      await new Future.delayed(new Duration(milliseconds: 50));

      expect(updateCount, 16);

      expect(insertList, [0, 0, 0, 0, 0, 0, 0, 0]);
      expect(timeline.events.length, 6);
      expect(timeline.events[0].content["txid"], "1234");
      expect(timeline.events[0].status, 1);
    });
  });
}