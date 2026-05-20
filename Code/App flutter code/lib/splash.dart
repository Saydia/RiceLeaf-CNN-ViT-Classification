import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'home.dart';
import 'package:camera/camera.dart';

class Splash extends StatefulWidget {
  final List<CameraDescription> cameras;
  const Splash({Key? key, required this.cameras}) : super(key: key);

  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  _navigateToHome() async {
    await Future.delayed(const Duration(milliseconds: 3000), () {});
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => Home(cameras: widget.cameras)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset('assets/animation.json'),
            const SizedBox(height: 20),
            Image.asset('assets/image.jpg', height: 200),
            const SizedBox(height: 20),
            const Text(
              'Rice Leaf Disease Detector',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
