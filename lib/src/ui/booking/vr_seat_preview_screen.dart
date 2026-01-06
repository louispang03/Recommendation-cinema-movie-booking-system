import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:fyp_cinema_app/res/color_app.dart';
import 'package:fyp_cinema_app/src/ui/booking/unity_webgl_config.dart';

class VRSeatPreviewScreen extends StatefulWidget {
  final Map<String, dynamic> movie;
  final String selectedDate;
  final String selectedTime;
  final String selectedCinema;
  final String? preselectedSeat;

  const VRSeatPreviewScreen({
    super.key,
    required this.movie,
    required this.selectedDate,
    required this.selectedTime,
    required this.selectedCinema,
    this.preselectedSeat,
  });

  @override
  State<VRSeatPreviewScreen> createState() => _VRSeatPreviewScreenState();
}

class _VRSeatPreviewScreenState extends State<VRSeatPreviewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String _currentSeat = 'A1';
  
  @override
  void initState() {
    super.initState();
    _currentSeat = widget.preselectedSeat ?? 'A1';
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..enableZoom(false)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            print('WebView error: ${error.description}');
            // If Unity WebGL fails, fallback to simulation
            if (error.description.contains('net::') || error.description.contains('WebGL')) {
              print('Unity WebGL failed, falling back to simulation');
              _controller.loadHtmlString(_getVRCinemaHTML());
            }
          },
        ),
      )
      ..setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36')
      // Option 1: Load Unity WebGL from hosted URL
      // Replace with your actual Netlify URL
      ..loadRequest(Uri.parse('https://effervescent-conkies-27d7e7.netlify.app/'));
      
      // Option 2: Load Unity WebGL from local server (for testing)
      // ..loadRequest(Uri.parse('http://localhost:8000'));
      
      // Option 3: Load HTML simulation (backup)
      // ..loadHtmlString(_getVRCinemaHTML());
      
      // 💡 If Unity WebGL doesn't work on mobile, uncomment line above and comment Unity URL
  }

  String _getVRCinemaHTML() {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>VR Cinema Preview</title>
    <style>
        body { margin: 0; padding: 0; background: #000; color: white; font-family: Arial; }
        .container { width: 100vw; height: 100vh; display: flex; flex-direction: column; }
        .screen { width: 80%; height: 15%; background: #f0f0f0; margin: 20px auto; border-radius: 10px; 
                 display: flex; align-items: center; justify-content: center; color: #333; font-size: 20px; }
        .vr-view { flex: 1; background: radial-gradient(circle, #2c3e50, #1a252f); 
                  display: flex; align-items: center; justify-content: center; position: relative; }
        .seat-info { background: rgba(0,0,0,0.8); padding: 20px; border-radius: 10px; text-align: center; }
        .controls { padding: 20px; background: #111; display: flex; justify-content: space-between; align-items: center; }
        .btn { padding: 10px 20px; background: #ff6b35; color: white; border: none; border-radius: 5px; cursor: pointer; }
        .current-seat { background: #333; padding: 10px; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="screen">${widget.movie['title']} - SCREEN</div>
        <div class="vr-view">
            <div class="seat-info">
                <h2>VR Seat View</h2>
                <p><strong>Current Seat:</strong> <span id="current-seat">${_currentSeat}</span></p>
                <p id="seat-description" style="color: #ffa500; font-size: 14px; margin: 10px 0;">${UnityWebGLConfig.getSeatDescription(_currentSeat)}</p>
                <p><strong>Cinema:</strong> ${widget.selectedCinema}</p>
                <p><strong>Time:</strong> ${widget.selectedTime}</p>
            </div>
        </div>
        <div class="controls">
            <button class="btn" onclick="previousSeat()">◀ Previous</button>
            <div class="current-seat">Seat <span id="seat-display">${_currentSeat}</span></div>
            <button class="btn" onclick="nextSeat()">Next ▶</button>
        </div>
    </div>

    <script>
        let currentSeat = "${_currentSeat}";
        const seats = [];
        for(let row = 0; row < 8; row++) {
            for(let col = 1; col <= 10; col++) {
                seats.push(String.fromCharCode(65 + row) + col);
            }
        }
        
        function updateSeat(seat) {
            currentSeat = seat;
            document.getElementById('current-seat').textContent = seat;
            document.getElementById('seat-display').textContent = seat;
            
            // Update seat description based on position
            const descriptions = {
                'A1': 'Front Row - Great for action movies, close to screen',
                'A2': 'Front Row - Great for action movies, close to screen',
                'A3': 'Front Row - Great for action movies, close to screen',
                'A4': 'Front Row - Great for action movies, close to screen',
                'A5': 'Front Row Center - Excellent for immersive experience',
                'A6': 'Front Row Center - Excellent for immersive experience',
                'A7': 'Front Row - Great for action movies, close to screen',
                'A8': 'Front Row - Great for action movies, close to screen',
                'A9': 'Front Row - Great for action movies, close to screen',
                'A10': 'Front Row - Great for action movies, close to screen',
                'E4': 'Middle Row Center - Premium viewing angle',
                'E5': 'Middle Row Center - Premium viewing angle',
                'E6': 'Middle Row Center - Premium viewing angle',
                'E7': 'Middle Row Center - Premium viewing angle',
                'H5': 'Back Row Center - Excellent overall view',
                'H6': 'Back Row Center - Excellent overall view'
            };
            
            let description = descriptions[seat];
            if (!description) {
                const row = seat[0];
                const number = parseInt(seat.substring(1));
                
                let position;
                if (number <= 3) {
                    position = 'Left Side - Good view with slight angle';
                } else if (number >= 8) {
                    position = 'Right Side - Good view with slight angle';
                } else {
                    position = 'Center - Great viewing angle';
                }
                
                let rowDesc;
                if (['A', 'B'].includes(row)) {
                    rowDesc = 'Front Section - Close to screen';
                } else if (['C', 'D', 'E'].includes(row)) {
                    rowDesc = 'Middle Section - Balanced viewing';
                } else {
                    rowDesc = 'Back Section - Full screen view';
                }
                
                description = rowDesc + ' - ' + position;
            }
            
            document.getElementById('seat-description').textContent = description;
        }
        
        function nextSeat() {
            const currentIndex = seats.indexOf(currentSeat);
            const nextIndex = (currentIndex + 1) % seats.length;
            updateSeat(seats[nextIndex]);
        }
        
        function previousSeat() {
            const currentIndex = seats.indexOf(currentSeat);
            const prevIndex = (currentIndex - 1 + seats.length) % seats.length;
            updateSeat(seats[prevIndex]);
        }
    </script>
</body>
</html>
    ''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('VR Seat Preview'),
        backgroundColor: ColorApp.primaryDarkColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('VR Preview'),
                  content: const Text(
                    'Experience your seat view in Virtual Reality!\n\n'
                    'Use the navigation buttons to switch between seats and see the view from each position.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Container(
              color: Colors.black,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(ColorApp.primaryDarkColor),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading VR Cinema Experience...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
} 