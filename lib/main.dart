import 'package:flutter/material.dart';
import 'package:meeting_spotlight/provider/meeting_provider.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => MeetingProvider())],
      child: const MaterialApp(debugShowCheckedModeBanner: false, title: 'Meeting Spotlight', home: HomeScreen()),
    ),
  );
}
