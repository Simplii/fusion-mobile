import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart';

enum FusionStreamEventConnectionStatus {
  connectionInitiated,
  connected,
  disconnected,
  error,
}

class FusionStreamEvents {
  String _TAG = "MDBM FusionStreamEvents";
  FusionStreamEvents._internal();
  static final FusionStreamEvents instance = FusionStreamEvents._internal();
  factory FusionStreamEvents() {
    return instance;
  }
  Client? _client;
  StreamController<FusionStreamEventData>? _streamController;
  bool _isExplicitDisconnect = false;
  StreamSubscription? _streamSubscription;

  void connect(
    String method,
    Uri url,
    Map<String, String> headerOptions, {
    Function()? onConnectionClose,
    bool autoReconnect = false,
    required Function(FusionStreamEventResponse?) onSuccessCallback,
    Function(String)? onError,
  }) {
    _isExplicitDisconnect = false;
    Map<String, String> header = {
      'Accept': 'text/event-stream',
      'Connection': 'keep-alive',
      'Accept-Encoding': 'gzip, deflate, br',
      'Keep-Alive': 'timeout=60, max=1000',
      ...headerOptions
    };
    _start(
      method,
      url,
      header,
      onSuccessCallback: onSuccessCallback,
      autoReconnect: autoReconnect,
    );
  }

  void _start(
    String method,
    Uri url,
    Map<String, String> header, {
    Function()? onConnectionClose,
    bool autoReconnect = false,
    required Function(FusionStreamEventResponse?) onSuccessCallback,
    Function(String)? onError,
    int retryCount = 0,
  }) {
    _client = Client();
    _isExplicitDisconnect = false;
    _streamController = StreamController<FusionStreamEventData>();
    RegExp lineRegex = RegExp(r'^([^:]*)(?::)?(?: )?(.*)?$');
    FusionStreamEventData currentFusionEventData = FusionStreamEventData(
      data: '',
      id: '',
      event: '',
    );
    Request request = Request(method, url);
    request.headers.addAll(header);
    Future<StreamedResponse> response = _client!.send(request);
    print('$_TAG Connection Initiated');
    print('$_TAG Request headers=${request.headers}');
    response.then(
      (data) async {
        if (data.statusCode < 200 || data.statusCode >= 300) {
          print(
              '$_TAG Connection failed Connection Error Status:${data.statusCode}, Connection Error Reason: ${data.reasonPhrase}');
          if (data.statusCode == 401) {
            //TODO: renew auth signature
            print(
                '$_TAG Connection failed Connection Error Status:${data.statusCode}, Connection Error Reason: ${data.reasonPhrase}');
          }
          if (onError != null) {
            onError(
                'Connection Error Status:${data.statusCode}, Connection Error Reason: ${data.reasonPhrase}');
          }
        }

        if (autoReconnect && data.statusCode != 200) {
          // _reconnectWithDelay(
          //   _isExplicitDisconnect,
          //   autoReconnect,
          //   type,
          //   url,
          //   header,
          //   onSuccessCallback,
          //   onError: onError,
          //   onConnectionClose: onConnectionClose,
          //   body: body,
          // );
          print("$_TAG autoReconnect is active");
          return;
        }

        _streamSubscription = data.stream
            .transform(const Utf8Decoder())
            .transform(const LineSplitter())
            .listen(
              (dataLine) {
                print("$_TAG data line $dataLine");
                if (dataLine.isEmpty) {
                  /// When the data line is empty, it indicates that the complete event set has been read.
                  /// The event is then added to the stream.
                  _streamController?.add(currentFusionEventData);
                  currentFusionEventData =
                      FusionStreamEventData(data: '', id: '', event: '');
                  return;
                }

                Match match = lineRegex.firstMatch(dataLine)!;
                var field = match.group(1);
                if (field!.isEmpty) {
                  return;
                }
                var value = '';
                if (field == 'data') {
                  /// If the field is data, we get the data through the substring
                  value = dataLine.substring(5);
                } else {
                  value = match.group(2) ?? '';
                }
                switch (field) {
                  case 'event':
                    currentFusionEventData.event = value;
                    break;
                  case 'data':
                    currentFusionEventData.data =
                        '${currentFusionEventData.data}$value\n';
                    print("$_TAG Data=${currentFusionEventData.data}");
                    break;
                  case 'id':
                    currentFusionEventData.id = value;
                    break;
                  case 'retry':
                    break;
                }
              },
              cancelOnError: true,
              onDone: () async {
                await _stop();
                print('$_TAG Stream closed');

                /// When the stream is closed, onClose can be called to execute a function.
                if (onConnectionClose != null) onConnectionClose();
              },
              onError: (error, s) async {
                log("$_TAG ${error.toString()}");
                await _stop();

                print(
                    '$_TAG Data Stream Listen Error: ${data.statusCode} error: $error ');

                if (onError != null) {
                  onError("$_TAG error: ${error.toString()}");
                }
                if (retryCount >= 5) {
                  return print(
                      '$_TAG Data Stream error, retried to reconnect 5 times');
                } else {
                  _reconnectWithDelay(
                    _isExplicitDisconnect,
                    autoReconnect,
                    method,
                    url,
                    header,
                    onSuccessCallback,
                    onError: onError,
                    onConnectionClose: onConnectionClose,
                  );
                }
              },
            );
        if (data.statusCode == 200) {
          onSuccessCallback(
            FusionStreamEventResponse(
              status: FusionStreamEventConnectionStatus.connected,
              stream: _streamController!.stream,
            ),
          );
        }
      },
    ).catchError((e) async {
      if (onError != null) {
        onError(e.toString());
      }
      log("$_TAG ${e.toString()}");
      await _stop();
    });
  }

  Future<FusionStreamEventConnectionStatus> _stop() async {
    print('$_TAG Disconnecting');
    try {
      _streamSubscription?.cancel();
      _streamController?.close();
      _client?.close();
      Future.delayed(const Duration(seconds: 1), () {});
      print('$_TAG Disconnected');
      return FusionStreamEventConnectionStatus.disconnected;
    } catch (error) {
      print('$_TAG Disconnected error:$error');
      return FusionStreamEventConnectionStatus.error;
    }
  }

  void _reconnectWithDelay(
    /// If _isExplicitDisconnect is `true`, it does not attempt to reconnect. This is to prevent reconnection if the user has explicitly disconnected.
    bool isExplicitDisconnect,
    bool autoReconnect,
    String method,
    Uri url,
    Map<String, String> header,
    Function(FusionStreamEventResponse?) onSuccessCallback, {
    Function(String)? onError,
    Function()? onConnectionClose,
  }) async {
    print(
        "$_TAG autoReconnect=$autoReconnect isExplicitDisconnect=$isExplicitDisconnect");
    if (autoReconnect && !isExplicitDisconnect) {
      print("$_TAG autoReconnecting in 2sec");
      await Future.delayed(const Duration(seconds: 2), () {
        print("$_TAG autoReconnect starting");
        _start(
          method,
          url,
          header,
          onSuccessCallback: onSuccessCallback,
          autoReconnect: autoReconnect,
          onError: onError,
          onConnectionClose: onConnectionClose,
        );
      });
    }
  }
}

class FusionStreamEventData {
  /// Event ID
  String id = '';

  /// Event Name
  String event = '';

  /// Event Data
  String data = '';

  FusionStreamEventData({
    required this.data,
    required this.id,
    required this.event,
  });
  FusionStreamEventData.fromData(String data) {
    id = data.split("\n")[0].split('id:')[1];
    event = data.split("\n")[1].split('event:')[1];
    this.data = data.split("\n")[2].split('data:')[1];
  }
}

class FusionStreamEventResponse {
  final FusionStreamEventConnectionStatus status;
  final Stream<FusionStreamEventData>? stream;
  final String? errorMessage;

  FusionStreamEventResponse({
    required this.status,
    this.stream,
    this.errorMessage,
  });
}
