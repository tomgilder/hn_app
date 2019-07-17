import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'dart:convert' as json;

abstract class RequestDescription {
  Future<http.Response> makeRequest();
}

class Get extends RequestDescription {
  dynamic url;

  Get(this.url);

  Future<http.Response> makeRequest() {
    print("Requesting $url...");
    return http.get(url);
  }
}

enum RequestBuilderStatus {
  uninitialized,
  loading,
  success,
  error
}

class RequestBuilder<T> extends StatefulWidget {
  final RequestDescription request;
  final Widget Function(BuildContext context, T result) builder;
  final T Function(dynamic) map;
  final dynamic Function(String) deserializer;

  const RequestBuilder({
    @required this.request,
    @required this.builder,
    this.map,
    this.deserializer = json.jsonDecode
  });

  @override
  State<StatefulWidget> createState() => RequestBuilderState<T>();
}

class RequestBuilderState<T> extends State<RequestBuilder<T>> {
  RequestBuilderStatus status = RequestBuilderStatus.uninitialized;
  T result;

  @override
  void initState() { 
    super.initState();
    
    _makeRequest();
  }

  Future reload() {
    return _makeRequest();
  }

  Future _makeRequest() async {
    if (status == RequestBuilderStatus.loading) {
      return;
    }

    setState(() => status = RequestBuilderStatus.loading);
    http.Response response;

    try {
      response = await widget.request.makeRequest();
      if (response.statusCode != 200) {
        setState(() => status = RequestBuilderStatus.error);
        return;
      }

      setState(() {
        status = RequestBuilderStatus.success;
        result = widget.map(widget.deserializer(response.body));
      });
    } catch (e) {
      setState(() => status = RequestBuilderStatus.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case RequestBuilderStatus.success:
        return widget.builder(context, result);
        break;

      case RequestBuilderStatus.uninitialized:
      case RequestBuilderStatus.loading:
        return Center(
          child: SizedBox(
            height: 50,
            width: 50,
            child: CircularProgressIndicator()
          ),
        );
        break;

      case RequestBuilderStatus.error:
        return Container(child: Text("Error")); // TODO reload button
        break;
    }

    throw "Invalid status";
  }
}


class MultiRequestBuilder<T> extends StatefulWidget {
  final Iterable<RequestDescription> requests;
  final Widget Function(BuildContext context, List<T> result) builder;
  final T Function(dynamic) map;
  final dynamic Function(String) deserializer;
  final dynamic filter;

  const MultiRequestBuilder({
    @required this.requests,
    @required this.builder,
    this.map,
    this.deserializer = json.jsonDecode,
    this.filter
  });

  @override
  State<StatefulWidget> createState() => MultiRequestBuilderState<T>();
}

class MultiRequestBuilderState<T> extends State<MultiRequestBuilder<T>> {
  RequestBuilderStatus status = RequestBuilderStatus.uninitialized;
  List<T> result;

  @override
  void initState() { 
    super.initState();
    
    _makeRequests();
  }

  Future reload() {
    return _makeRequests();
  }

  Future _makeRequests() async {
    if (status == RequestBuilderStatus.loading) {
      return;
    }

    setState(() => status = RequestBuilderStatus.loading);
    final futureResponses = widget.requests.map(_makeSingleRequest);
    final responses = await Future.wait(futureResponses);

    if (responses.any((x) => x == null)) {
      setState(() => status = RequestBuilderStatus.error);
      return;
    }

    setState(() {
      status = RequestBuilderStatus.success;
      result = responses
        .where((x) => x != null)
        .map((response) => widget.map(widget.deserializer(response.body)))
        .toList();
    });
  }

  Future<http.Response> _makeSingleRequest(RequestDescription requestDescription) async {
    http.Response response;
    
    try {
      response = await requestDescription.makeRequest();
      if (response.statusCode != 200) {
        return null;
      }

      return response;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case RequestBuilderStatus.success:
        return widget.builder(context, result);
        break;

      case RequestBuilderStatus.uninitialized:
      case RequestBuilderStatus.loading:
        return Center(
          child: SizedBox(
            height: 50,
            width: 50,
            child: CircularProgressIndicator()
          ),
        );
        break;

      case RequestBuilderStatus.error:
        return Container(child: Text("Error")); // TODO reload button
        break;
    }

    throw "Invalid status";
  }
}