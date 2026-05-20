import 'package:flutter/material.dart';
import 'package:avatar_maker/avatar_maker.dart';

class AvatarPage extends StatelessWidget {
  const AvatarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Avatar Oluştur"),
      ),
      body: const SafeArea(
        child: AvatarMaker(),
      ),
    );
  }
}