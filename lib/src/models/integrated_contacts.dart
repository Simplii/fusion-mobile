import 'package:fusion_mobile_revamped/src/backend/fusion_connection.dart';
import 'package:fusion_mobile_revamped/src/models/coworkers.dart';

import 'carbon_date.dart';
import 'contact.dart';
import 'fusion_model.dart';
import 'fusion_store.dart';

class IntegratedContactsStore extends FusionStore<Contact> {
  IntegratedContactsStore(FusionConnection fusionConnection)
      : super(fusionConnection);

  search(
      String query, int limit, int offset, Function(List<Contact>, bool, bool?) callback) {
    query = query.toLowerCase();
    List<Contact> matched = getRecords()
        .where((Contact c) {
          return (c.name! + " " + c.company!).toLowerCase().contains(query);
        })
        .toList()
        .cast<Contact>();

    if (matched.length > 0) {
      var future = new Future.delayed(const Duration(milliseconds: 10), () {
        callback(matched, false, true);
      });
    }

    fusionConnection.apiV1Call("post", "/clients/filtered_crm_contacts", {
      'page': (offset / limit).round(),
      'page_size': limit,
      'sort_dir': 'asc',
      'search_query': query,
      'sort_by': 'name',
    }, callback: (Map<String, dynamic> datas) {
      List<Contact> response = [];

      datas['items'].forEach((dynamic c) {
        Contact contact = Contact(c['contact'] as Map<String, dynamic>);
        contact.lastCommunication = c['last_communication'];
        contact.unread = int.parse(c['unread'].toString());
        response.add(contact);
        storeRecord(contact);
      });

      bool? hasMore = datas['agg']['count'] > (limit + offset);

      callback(response, true, hasMore);
    });
  }
}
