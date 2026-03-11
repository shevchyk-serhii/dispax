import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models/location.dart';
import 'models/person.dart';
import '../ride_management/models/ride.dart';

class NavigationUtils {
  static Future<void> openGoogleMapsNavigation(Location destination) async {
    final destinationAddress = Uri.encodeComponent(destination.address);

    final googleMapsUrl = 'https://www.google.com/maps/dir/?api=1&destination=$destinationAddress&travelmode=driving';

    try {
      final Uri uri = Uri.parse(googleMapsUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch Google Maps';
      }
    } catch (e) {

      await _tryGoogleMapsApp(destination);
    }
  }

  static Future<void> openGoogleMapsRoute(Location origin, Location destination) async {
    final originAddress = Uri.encodeComponent(origin.address);
    final destinationAddress = Uri.encodeComponent(destination.address);

    final googleMapsUrl = 'https://www.google.com/maps/dir/?api=1&origin=$originAddress&destination=$destinationAddress&travelmode=driving';

    try {
      final Uri uri = Uri.parse(googleMapsUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch Google Maps';
      }
    } catch (e) {

      await _tryGoogleMapsAppWithRoute(origin, destination);
    }
  }

  static Future<void> _tryGoogleMapsApp(Location destination) async {
    final destinationAddress = Uri.encodeComponent(destination.address);

    final appUrl = 'comgooglemaps://?daddr=$destinationAddress&directionsmode=driving';

    try {
      final Uri uri = Uri.parse(appUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Google Maps app not found';
      }
    } catch (e) {
      throw 'Could not open navigation: $e';
    }
  }

  static Future<void> _tryGoogleMapsAppWithRoute(Location origin, Location destination) async {
    final originAddress = Uri.encodeComponent(origin.address);
    final destinationAddress = Uri.encodeComponent(destination.address);

    final appUrl = 'comgooglemaps://?saddr=$originAddress&daddr=$destinationAddress&directionsmode=driving';

    try {
      final Uri uri = Uri.parse(appUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Google Maps app not found';
      }
    } catch (e) {
      throw 'Could not open navigation: $e';
    }
  }

  static Future<void> openWazeNavigation(Location destination) async {
    String wazeUrl;
    if (destination.latitude != null && destination.longitude != null) {
      wazeUrl = 'https://waze.com/ul?ll=${destination.latitude},${destination.longitude}&navigate=yes';
    } else {
      final address = Uri.encodeComponent(destination.address);
      wazeUrl = 'https://waze.com/ul?q=$address&navigate=yes';
    }

    try {
      final Uri uri = Uri.parse(wazeUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch Waze';
      }
    } catch (e) {
      throw 'Could not open Waze: $e';
    }
  }

  static Future<void> openGoogleMapsLocation(Location location) async {
    final address = Uri.encodeComponent(location.address);

    String googleMapsUrl;
    if (location.latitude != null && location.longitude != null) {

      googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}';
    } else {

      googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$address';
    }

    try {
      final Uri uri = Uri.parse(googleMapsUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch Google Maps';
      }
    } catch (e) {
      throw 'Could not open location: $e';
    }
  }

  static Future<Ride?> navigateToEditRide(BuildContext context, Ride ride) async {

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit ride functionality not yet implemented')),
    );
    return null;
  }

  static Future<Person?> navigateToDriverSelection(BuildContext context) async {
    // Driver selection is now handled by the dispatcher dashboard's
    // tap-to-assign flow (pending_rides_panel.dart _showDriverSelectionSheet)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Use the Dispatcher Dashboard to assign drivers')),
    );
    return null;
  }

  static void navigateToMap(BuildContext context, Ride ride) {

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Map functionality not yet implemented')),
    );
  }
}