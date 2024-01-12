import 'package:flutter/services.dart';
import 'package:fusion_mobile_revamped/src/backend/fusion_connection.dart';

import 'fusion_model.dart';

class FusionStore<T extends FusionModel> {
  FusionConnection _fusionConnection;
  MethodChannel? methodChannel;
  Map<String?, T> _records = {};
  String _id_field = 'id';

  FusionStore(this._fusionConnection,{this.methodChannel});

  FusionConnection get fusionConnection => _fusionConnection;

  storeRecord(T record) {
    if (_records == null) {
      _records = {};
    }
    _records[record.getId()] = record;
  }

  hasRecord(String? id) {
    return _records.containsKey(id);
  }

  removeRecord(String id) {
    _records.remove(id);
  }

  clearRecords() {
    _records.clear();
  }

  getRecord(String? id, Function(T?) callback) {
    if (_records.containsKey(id)) {
      callback(_records[id]);
    }
  }

  lookupRecord(String? id) {
    return _records[id];
  }

  getRecords() {
    return _records.values.toList();
  }
}
