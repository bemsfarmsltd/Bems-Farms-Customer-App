import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AddressSearchDelegate extends SearchDelegate<Map<String, dynamic>?> {
  final String sessionToken;

  AddressSearchDelegate(this.sessionToken);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
          },
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return Container();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.length < 3) {
      return const Center(
        child: Text('Type at least 3 characters to search...'),
      );
    }

    return FutureBuilder<List<dynamic>>(
      future: _fetchSuggestions(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return const Center(child: Text('Error fetching suggestions.'));
        }

        final results = snapshot.data ?? [];
        if (results.isEmpty) {
          return const Center(child: Text('No results found.'));
        }

        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final place = results[index];
            return ListTile(
              leading: const Icon(Icons.location_on),
              title: Text(place['description'] ?? ''),
              onTap: () async {
                final details = await _getPlaceDetails(place['place_id']);
                if (context.mounted) close(context, details);
              },
            );
          },
        );
      },
    );
  }

  static const String _apiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  Future<List<dynamic>> _fetchSuggestions(String input) async {
    if (_apiKey.isEmpty) return [];
    final request = 'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&components=country:ng&sessiontoken=$sessionToken&key=$_apiKey';
    
    final response = await http.get(Uri.parse(request));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        return data['predictions'];
      }
    }
    return [];
  }

  Future<Map<String, dynamic>?> _getPlaceDetails(String placeId) async {
    if (_apiKey.isEmpty) return null;
    final request = 'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=name,formatted_address,geometry,address_components&key=$_apiKey';
    
    final response = await http.get(Uri.parse(request));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        final result = data['result'];
        
        String city = '';
        String state = '';
        String postalCode = '';
        if (result['address_components'] != null) {
          for (var comp in result['address_components']) {
            final types = comp['types'] as List;
            if (types.contains('locality') || types.contains('administrative_area_level_2')) {
              city = comp['long_name'];
            }
            if (types.contains('administrative_area_level_1')) {
              state = comp['long_name'];
            }
            if (types.contains('postal_code')) {
              postalCode = comp['long_name'];
            }
          }
        }
        
        return {
          'street': result['name'] ?? result['formatted_address'] ?? '',
          'city': city,
          'state': state,
          'postalCode': postalCode,
          'postal_code': postalCode,
          'lat': result['geometry']['location']['lat'],
          'lng': result['geometry']['location']['lng'],
        };
      }
    }
    return null;
  }
}
