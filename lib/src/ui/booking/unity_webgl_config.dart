class UnityWebGLConfig {
  // Seat mapping that corresponds to Unity VR seat positions
  static const Map<String, Map<String, double>> seatPositions = {
    // Row A (Front row)
    'A1': {'x': -4.5, 'y': 0.8, 'z': -2.0},
    'A2': {'x': -3.5, 'y': 0.8, 'z': -2.0},
    'A3': {'x': -2.5, 'y': 0.8, 'z': -2.0},
    'A4': {'x': -1.5, 'y': 0.8, 'z': -2.0},
    'A5': {'x': -0.5, 'y': 0.8, 'z': -2.0},
    'A6': {'x': 0.5, 'y': 0.8, 'z': -2.0},
    'A7': {'x': 1.5, 'y': 0.8, 'z': -2.0},
    'A8': {'x': 2.5, 'y': 0.8, 'z': -2.0},
    'A9': {'x': 3.5, 'y': 0.8, 'z': -2.0},
    'A10': {'x': 4.5, 'y': 0.8, 'z': -2.0},
    
    // Row B
    'B1': {'x': -4.5, 'y': 0.8, 'z': -1.0},
    'B2': {'x': -3.5, 'y': 0.8, 'z': -1.0},
    'B3': {'x': -2.5, 'y': 0.8, 'z': -1.0},
    'B4': {'x': -1.5, 'y': 0.8, 'z': -1.0},
    'B5': {'x': -0.5, 'y': 0.8, 'z': -1.0},
    'B6': {'x': 0.5, 'y': 0.8, 'z': -1.0},
    'B7': {'x': 1.5, 'y': 0.8, 'z': -1.0},
    'B8': {'x': 2.5, 'y': 0.8, 'z': -1.0},
    'B9': {'x': 3.5, 'y': 0.8, 'z': -1.0},
    'B10': {'x': 4.5, 'y': 0.8, 'z': -1.0},
    
    // Row C
    'C1': {'x': -4.5, 'y': 0.8, 'z': 0.0},
    'C2': {'x': -3.5, 'y': 0.8, 'z': 0.0},
    'C3': {'x': -2.5, 'y': 0.8, 'z': 0.0},
    'C4': {'x': -1.5, 'y': 0.8, 'z': 0.0},
    'C5': {'x': -0.5, 'y': 0.8, 'z': 0.0},
    'C6': {'x': 0.5, 'y': 0.8, 'z': 0.0},
    'C7': {'x': 1.5, 'y': 0.8, 'z': 0.0},
    'C8': {'x': 2.5, 'y': 0.8, 'z': 0.0},
    'C9': {'x': 3.5, 'y': 0.8, 'z': 0.0},
    'C10': {'x': 4.5, 'y': 0.8, 'z': 0.0},
    
    // Row D
    'D1': {'x': -4.5, 'y': 0.8, 'z': 1.0},
    'D2': {'x': -3.5, 'y': 0.8, 'z': 1.0},
    'D3': {'x': -2.5, 'y': 0.8, 'z': 1.0},
    'D4': {'x': -1.5, 'y': 0.8, 'z': 1.0},
    'D5': {'x': -0.5, 'y': 0.8, 'z': 1.0},
    'D6': {'x': 0.5, 'y': 0.8, 'z': 1.0},
    'D7': {'x': 1.5, 'y': 0.8, 'z': 1.0},
    'D8': {'x': 2.5, 'y': 0.8, 'z': 1.0},
    'D9': {'x': 3.5, 'y': 0.8, 'z': 1.0},
    'D10': {'x': 4.5, 'y': 0.8, 'z': 1.0},
    
    // Row E (Middle)
    'E1': {'x': -4.5, 'y': 0.8, 'z': 2.0},
    'E2': {'x': -3.5, 'y': 0.8, 'z': 2.0},
    'E3': {'x': -2.5, 'y': 0.8, 'z': 2.0},
    'E4': {'x': -1.5, 'y': 0.8, 'z': 2.0},
    'E5': {'x': -0.5, 'y': 0.8, 'z': 2.0},
    'E6': {'x': 0.5, 'y': 0.8, 'z': 2.0},
    'E7': {'x': 1.5, 'y': 0.8, 'z': 2.0},
    'E8': {'x': 2.5, 'y': 0.8, 'z': 2.0},
    'E9': {'x': 3.5, 'y': 0.8, 'z': 2.0},
    'E10': {'x': 4.5, 'y': 0.8, 'z': 2.0},
    
    // Row F
    'F1': {'x': -4.5, 'y': 0.8, 'z': 3.0},
    'F2': {'x': -3.5, 'y': 0.8, 'z': 3.0},
    'F3': {'x': -2.5, 'y': 0.8, 'z': 3.0},
    'F4': {'x': -1.5, 'y': 0.8, 'z': 3.0},
    'F5': {'x': -0.5, 'y': 0.8, 'z': 3.0},
    'F6': {'x': 0.5, 'y': 0.8, 'z': 3.0},
    'F7': {'x': 1.5, 'y': 0.8, 'z': 3.0},
    'F8': {'x': 2.5, 'y': 0.8, 'z': 3.0},
    'F9': {'x': 3.5, 'y': 0.8, 'z': 3.0},
    'F10': {'x': 4.5, 'y': 0.8, 'z': 3.0},
    
    // Row G
    'G1': {'x': -4.5, 'y': 0.8, 'z': 4.0},
    'G2': {'x': -3.5, 'y': 0.8, 'z': 4.0},
    'G3': {'x': -2.5, 'y': 0.8, 'z': 4.0},
    'G4': {'x': -1.5, 'y': 0.8, 'z': 4.0},
    'G5': {'x': -0.5, 'y': 0.8, 'z': 4.0},
    'G6': {'x': 0.5, 'y': 0.8, 'z': 4.0},
    'G7': {'x': 1.5, 'y': 0.8, 'z': 4.0},
    'G8': {'x': 2.5, 'y': 0.8, 'z': 4.0},
    'G9': {'x': 3.5, 'y': 0.8, 'z': 4.0},
    'G10': {'x': 4.5, 'y': 0.8, 'z': 4.0},
    
    // Row H (Back row)
    'H1': {'x': -4.5, 'y': 0.8, 'z': 5.0},
    'H2': {'x': -3.5, 'y': 0.8, 'z': 5.0},
    'H3': {'x': -2.5, 'y': 0.8, 'z': 5.0},
    'H4': {'x': -1.5, 'y': 0.8, 'z': 5.0},
    'H5': {'x': -0.5, 'y': 0.8, 'z': 5.0},
    'H6': {'x': 0.5, 'y': 0.8, 'z': 5.0},
    'H7': {'x': 1.5, 'y': 0.8, 'z': 5.0},
    'H8': {'x': 2.5, 'y': 0.8, 'z': 5.0},
    'H9': {'x': 3.5, 'y': 0.8, 'z': 5.0},
    'H10': {'x': 4.5, 'y': 0.8, 'z': 5.0},
  };
  
  // Quality descriptions for different seat positions
  static const Map<String, String> seatQuality = {
    // Front rows - closer to screen but may require looking up
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
    
    // Middle rows - optimal viewing experience
    'E1': 'Middle Row - Balanced viewing experience',
    'E2': 'Middle Row - Balanced viewing experience',
    'E3': 'Middle Row - Balanced viewing experience',
    'E4': 'Middle Row Center - Premium viewing angle',
    'E5': 'Middle Row Center - Premium viewing angle',
    'E6': 'Middle Row Center - Premium viewing angle',
    'E7': 'Middle Row Center - Premium viewing angle',
    'E8': 'Middle Row - Balanced viewing experience',
    'E9': 'Middle Row - Balanced viewing experience',
    'E10': 'Middle Row - Balanced viewing experience',
    
    // Back rows - full screen view
    'H1': 'Back Row - Full screen view, great for panoramic scenes',
    'H2': 'Back Row - Full screen view, great for panoramic scenes',
    'H3': 'Back Row - Full screen view, great for panoramic scenes',
    'H4': 'Back Row - Full screen view, great for panoramic scenes',
    'H5': 'Back Row Center - Excellent overall view',
    'H6': 'Back Row Center - Excellent overall view',
    'H7': 'Back Row - Full screen view, great for panoramic scenes',
    'H8': 'Back Row - Full screen view, great for panoramic scenes',
    'H9': 'Back Row - Full screen view, great for panoramic scenes',
    'H10': 'Back Row - Full screen view, great for panoramic scenes',
  };
  
  // Default descriptions for other seats
  static String getSeatDescription(String seatId) {
    if (seatQuality.containsKey(seatId)) {
      return seatQuality[seatId]!;
    }
    
    // Generate description based on row
    String row = seatId[0];
    int number = int.parse(seatId.substring(1));
    
    String position;
    if (number <= 3) {
      position = 'Left Side - Good view with slight angle';
    } else if (number >= 8) {
      position = 'Right Side - Good view with slight angle';
    } else {
      position = 'Center - Great viewing angle';
    }
    
    String rowDescription;
    switch (row) {
      case 'A':
      case 'B':
        rowDescription = 'Front Section - Close to screen';
        break;
      case 'C':
      case 'D':
      case 'E':
        rowDescription = 'Middle Section - Balanced viewing';
        break;
      case 'F':
      case 'G':
      case 'H':
        rowDescription = 'Back Section - Full screen view';
        break;
      default:
        rowDescription = 'Good viewing position';
    }
    
    return '$rowDescription - $position';
  }
  
  // Get 3D position for Unity camera
  static Map<String, double>? getSeatPosition(String seatId) {
    return seatPositions[seatId];
  }
  
  // Check if seat provides premium viewing experience
  static bool isPremiumSeat(String seatId) {
    return seatId.startsWith('E') && 
           ['E4', 'E5', 'E6', 'E7'].contains(seatId);
  }
} 