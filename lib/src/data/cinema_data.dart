class CinemaLocation {
  final String name;
  final String region;
  final String brand;
  final double basePrice;
  final List<String> showtimes;

  CinemaLocation({
    required this.name,
    required this.region,
    required this.brand,
    required this.basePrice,
    required this.showtimes,
  });
}

class CinemaData {
  static final Map<String, Map<String, List<CinemaLocation>>> allCinemas = {
    'LFS': {
      'Penang': [
        CinemaLocation(name: 'LFS Butterworth', region: 'Penang', brand: 'LFS', basePrice: 12.0, showtimes: ['11:00 AM', '2:00 PM', '5:00 PM', '8:00 PM', '11:00 PM']),
        CinemaLocation(name: 'LFS Bukit Jambul', region: 'Penang', brand: 'LFS', basePrice: 12.0, showtimes: ['11:00 AM', '2:00 PM', '5:00 PM', '8:00 PM', '11:00 PM']),
      ],
      'Perak': [
        CinemaLocation(name: 'LFS Seri Kinta (Ipoh)', region: 'Perak', brand: 'LFS', basePrice: 12.0, showtimes: ['11:00 AM', '2:00 PM', '5:00 PM', '8:00 PM', '11:00 PM']),
        CinemaLocation(name: 'LFS Sitiawan', region: 'Perak', brand: 'LFS', basePrice: 12.0, showtimes: ['11:00 AM', '2:00 PM', '5:00 PM', '8:00 PM', '11:00 PM']),
        CinemaLocation(name: 'LFS Kampar', region: 'Perak', brand: 'LFS', basePrice: 12.0, showtimes: ['11:00 AM', '2:00 PM', '5:00 PM', '8:00 PM', '11:00 PM']),
      ],
      'Kuala Lumpur': [
        CinemaLocation(name: 'LFS Coliseum Theatre', region: 'Kuala Lumpur', brand: 'LFS', basePrice: 12.0, showtimes: ['11:00 AM', '2:00 PM', '5:00 PM', '8:00 PM', '11:00 PM']),
      ],
      'Selangor': [
        CinemaLocation(name: 'LFS PJ State (Petaling Jaya)', region: 'Selangor', brand: 'LFS', basePrice: 12.0, showtimes: ['11:00 AM', '2:00 PM', '5:00 PM', '8:00 PM', '11:00 PM']),
        CinemaLocation(name: 'LFS Sri Intan (Klang)', region: 'Selangor', brand: 'LFS', basePrice: 12.0, showtimes: ['11:00 AM', '2:00 PM', '5:00 PM', '8:00 PM', '11:00 PM']),
        CinemaLocation(name: 'LFS Metro Plaza (Kajang)', region: 'Selangor', brand: 'LFS', basePrice: 12.0, showtimes: ['11:00 AM', '2:00 PM', '5:00 PM', '8:00 PM', '11:00 PM']),
        CinemaLocation(name: 'LFS Capitol Selayang (Selayang)', region: 'Selangor', brand: 'LFS', basePrice: 12.0, showtimes: ['11:00 AM', '2:00 PM', '5:00 PM', '8:00 PM', '11:00 PM']),
        CinemaLocation(name: 'LFS Sun Rawang', region: 'Selangor', brand: 'LFS', basePrice: 12.0, showtimes: ['11:00 AM', '2:00 PM', '5:00 PM', '8:00 PM', '11:00 PM']),
      ],
      'Terengganu': [
        CinemaLocation(name: 'LFS Kuala Terengganu', region: 'Terengganu', brand: 'LFS', basePrice: 12.0, showtimes: ['11:00 AM', '2:00 PM', '5:00 PM', '8:00 PM', '11:00 PM']),
      ],
      'Sabah': [
        CinemaLocation(name: 'LFS Sandakan', region: 'Sabah', brand: 'LFS', basePrice: 12.0, showtimes: ['11:00 AM', '2:00 PM', '5:00 PM', '8:00 PM', '11:00 PM']),
      ],
    },
    'mmCineplexes': {
      'Kuala Lumpur': [
        CinemaLocation(name: 'mmCineplexes Berjaya Times Square', region: 'Kuala Lumpur', brand: 'mmCineplexes', basePrice: 13.0, showtimes: ['10:30 AM', '1:30 PM', '4:30 PM', '7:30 PM', '10:30 PM']),
      ],
      'Selangor': [
        CinemaLocation(name: 'mmCineplexes 1 Plaza (Kuala Selangor)', region: 'Selangor', brand: 'mmCineplexes', basePrice: 13.0, showtimes: ['10:30 AM', '1:30 PM', '4:30 PM', '7:30 PM', '10:30 PM']),
        CinemaLocation(name: 'mmCineplexes Shaw Centrepoint (Klang)', region: 'Selangor', brand: 'mmCineplexes', basePrice: 13.0, showtimes: ['10:30 AM', '1:30 PM', '4:30 PM', '7:30 PM', '10:30 PM']),
      ],
      'Negeri Sembilan': [
        CinemaLocation(name: 'mmCineplexes Kiara Square (Bahau)', region: 'Negeri Sembilan', brand: 'mmCineplexes', basePrice: 13.0, showtimes: ['10:30 AM', '1:30 PM', '4:30 PM', '7:30 PM', '10:30 PM']),
      ],
      'Penang': [
        CinemaLocation(name: 'mmCineplexes Prangin Mall (George Town)', region: 'Penang', brand: 'mmCineplexes', basePrice: 13.0, showtimes: ['10:30 AM', '1:30 PM', '4:30 PM', '7:30 PM', '10:30 PM']),
        CinemaLocation(name: 'mmCineplexes Sunshine Bertam (Kepala Batas)', region: 'Penang', brand: 'mmCineplexes', basePrice: 13.0, showtimes: ['10:30 AM', '1:30 PM', '4:30 PM', '7:30 PM', '10:30 PM']),
      ],
      'Perak': [
        CinemaLocation(name: 'mmCineplexes D\'Mall Seri Iskandar (Seri Iskandar)', region: 'Perak', brand: 'mmCineplexes', basePrice: 13.0, showtimes: ['10:30 AM', '1:30 PM', '4:30 PM', '7:30 PM', '10:30 PM']),
        CinemaLocation(name: 'mmCineplexes Kerian Sentral Mall (Parit Buntar)', region: 'Perak', brand: 'mmCineplexes', basePrice: 13.0, showtimes: ['10:30 AM', '1:30 PM', '4:30 PM', '7:30 PM', '10:30 PM']),
      ],
      'Kedah': [
        CinemaLocation(name: 'mmCineplexes Langkawi Parade (Langkawi)', region: 'Kedah', brand: 'mmCineplexes', basePrice: 13.0, showtimes: ['10:30 AM', '1:30 PM', '4:30 PM', '7:30 PM', '10:30 PM']),
      ],
      'Johor': [
        CinemaLocation(name: 'mmCineplexes Segamat Central (Segamat)', region: 'Johor', brand: 'mmCineplexes', basePrice: 13.0, showtimes: ['10:30 AM', '1:30 PM', '4:30 PM', '7:30 PM', '10:30 PM']),
      ],
      'Melaka': [
        CinemaLocation(name: 'mmCineplexes Mahkota Parade (Melaka City)', region: 'Melaka', brand: 'mmCineplexes', basePrice: 13.0, showtimes: ['10:30 AM', '1:30 PM', '4:30 PM', '7:30 PM', '10:30 PM']),
      ],
    },
    'GSC': {
      'Kuala Lumpur': [
        CinemaLocation(name: 'GSC Mid Valley Megamall', region: 'Kuala Lumpur', brand: 'GSC', basePrice: 15.0, showtimes: ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM']),
        CinemaLocation(name: 'GSC The Gardens Mall (Aurum)', region: 'Kuala Lumpur', brand: 'GSC', basePrice: 18.0, showtimes: ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM']),
        CinemaLocation(name: 'GSC LaLaport BBCC', region: 'Kuala Lumpur', brand: 'GSC', basePrice: 15.0, showtimes: ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM']),
        CinemaLocation(name: 'GSC MyTown', region: 'Kuala Lumpur', brand: 'GSC', basePrice: 15.0, showtimes: ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM']),
        CinemaLocation(name: 'GSC KL East Mall', region: 'Kuala Lumpur', brand: 'GSC', basePrice: 15.0, showtimes: ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM']),
        CinemaLocation(name: 'GSC Melawati Mall', region: 'Kuala Lumpur', brand: 'GSC', basePrice: 15.0, showtimes: ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM']),
        CinemaLocation(name: 'GSC Setapak Central', region: 'Kuala Lumpur', brand: 'GSC', basePrice: 15.0, showtimes: ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM']),
        CinemaLocation(name: 'GSC Nu Sentral', region: 'Kuala Lumpur', brand: 'GSC', basePrice: 15.0, showtimes: ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM']),
        CinemaLocation(name: 'GSC 1 Utama', region: 'Kuala Lumpur', brand: 'GSC', basePrice: 15.0, showtimes: ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM']),
        CinemaLocation(name: 'GSC The Starling Mall', region: 'Kuala Lumpur', brand: 'GSC', basePrice: 15.0, showtimes: ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM']),
        CinemaLocation(name: 'GSC Summit USJ', region: 'Kuala Lumpur', brand: 'GSC', basePrice: 15.0, showtimes: ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM']),
        CinemaLocation(name: 'GSC Subang Parade', region: 'Kuala Lumpur', brand: 'GSC', basePrice: 15.0, showtimes: ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM']),
        CinemaLocation(name: 'GSC IOI Mall Damansara', region: 'Kuala Lumpur', brand: 'GSC', basePrice: 15.0, showtimes: ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM']),
        CinemaLocation(name: 'GSC Setia City Mall', region: 'Kuala Lumpur', brand: 'GSC', basePrice: 15.0, showtimes: ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM']),
        CinemaLocation(name: 'GSC Quill City Mall', region: 'Kuala Lumpur', brand: 'GSC', basePrice: 15.0, showtimes: ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM']),
        CinemaLocation(name: 'GSC EkoCheras Mall', region: 'Kuala Lumpur', brand: 'GSC', basePrice: 15.0, showtimes: ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM']),
        CinemaLocation(name: 'GSC Lotus\'s Kepong', region: 'Kuala Lumpur', brand: 'GSC', basePrice: 15.0, showtimes: ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM']),
        CinemaLocation(name: 'GSC The Exchange TRX Aurum', region: 'Kuala Lumpur', brand: 'GSC', basePrice: 18.0, showtimes: ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM']),
        CinemaLocation(name: 'Velvet Cinemas', region: 'Kuala Lumpur', brand: 'GSC', basePrice: 20.0, showtimes: ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM']),
      ],
      'Selangor': [
        CinemaLocation(name: 'GSC IOI City Mall', region: 'Selangor', brand: 'GSC', basePrice: 15.0, showtimes: ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM']),
        CinemaLocation(name: 'GSC IOI City Mall 2', region: 'Selangor', brand: 'GSC', basePrice: 15.0, showtimes: ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM']),
      ],
      'Putrajaya': [
        CinemaLocation(name: 'GSC Putrajaya (IMAX – Premiere)', region: 'Putrajaya', brand: 'GSC', basePrice: 25.0, showtimes: ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM']),
      ],
      'Penang': [
        CinemaLocation(name: 'GSC Gurney Plaza', region: 'Penang', brand: 'GSC', basePrice: 15.0, showtimes: ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM']),
        CinemaLocation(name: 'GSC Queensbay Mall', region: 'Penang', brand: 'GSC', basePrice: 15.0, showtimes: ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM']),
        CinemaLocation(name: 'GSC Sunway Carnival', region: 'Penang', brand: 'GSC', basePrice: 15.0, showtimes: ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM']),
        CinemaLocation(name: 'GSC Kulim Central', region: 'Penang', brand: 'GSC', basePrice: 15.0, showtimes: ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM']),
        CinemaLocation(name: 'GSC Amanjaya Mall (Sungai Petani)', region: 'Penang', brand: 'GSC', basePrice: 15.0, showtimes: ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM']),
      ],
      'Perak': [
        CinemaLocation(name: 'GSC Ipoh Parade Mall', region: 'Perak', brand: 'GSC', basePrice: 15.0, showtimes: ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM']),
        CinemaLocation(name: 'GSC AEON Mall Ipoh Falim', region: 'Perak', brand: 'GSC', basePrice: 15.0, showtimes: ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM']),
      ],
      'Melaka': [
        CinemaLocation(name: 'GSC AEON Bandaraya Melaka', region: 'Melaka', brand: 'GSC', basePrice: 15.0, showtimes: ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM']),
        CinemaLocation(name: 'GSC Dataran Pahlawan', region: 'Melaka', brand: 'GSC', basePrice: 15.0, showtimes: ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM']),
      ],
      'Johor': [
        CinemaLocation(name: 'GSC Paradigm Mall JB', region: 'Johor', brand: 'GSC', basePrice: 15.0, showtimes: ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM']),
        CinemaLocation(name: 'GSC The Mall Mid Valley Southkey (JB)', region: 'Johor', brand: 'GSC', basePrice: 15.0, showtimes: ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM']),
        CinemaLocation(name: 'GSC AEON Mall Bandar Dato\' Onn (Kempas)', region: 'Johor', brand: 'GSC', basePrice: 15.0, showtimes: ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM']),
        CinemaLocation(name: 'GSC IOI Mall Kulai', region: 'Johor', brand: 'GSC', basePrice: 15.0, showtimes: ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM']),
        CinemaLocation(name: 'GSC Kluang Mall', region: 'Johor', brand: 'GSC', basePrice: 15.0, showtimes: ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM']),
        CinemaLocation(name: 'GSC Square One (Batu Pahat)', region: 'Johor', brand: 'GSC', basePrice: 15.0, showtimes: ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM']),
        CinemaLocation(name: 'GSC Sunway Iskandar', region: 'Johor', brand: 'GSC', basePrice: 15.0, showtimes: ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM']),
      ],
      'Pahang': [
        CinemaLocation(name: 'GSC East Coast Mall (Kuantan)', region: 'Pahang', brand: 'GSC', basePrice: 15.0, showtimes: ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM']),
      ],
      'Sabah': [
        CinemaLocation(name: 'GSC Suria Sabah', region: 'Sabah', brand: 'GSC', basePrice: 15.0, showtimes: ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM']),
        CinemaLocation(name: 'GSC 1Borneo', region: 'Sabah', brand: 'GSC', basePrice: 15.0, showtimes: ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM']),
        CinemaLocation(name: 'GSC Imago Mall (Kota Kinabalu)', region: 'Sabah', brand: 'GSC', basePrice: 15.0, showtimes: ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM']),
      ],
      'Sarawak': [
        CinemaLocation(name: 'GSC CityONE Megamall (Kuching)', region: 'Sarawak', brand: 'GSC', basePrice: 15.0, showtimes: ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM']),
        CinemaLocation(name: 'GSC The Spring Mall', region: 'Sarawak', brand: 'GSC', basePrice: 15.0, showtimes: ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM']),
        CinemaLocation(name: 'GSC The Spring Bintulu', region: 'Sarawak', brand: 'GSC', basePrice: 15.0, showtimes: ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM']),
        CinemaLocation(name: 'GSC Bintang Megamall (Miri)', region: 'Sarawak', brand: 'GSC', basePrice: 15.0, showtimes: ['10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM', '10:00 PM']),
      ],
    },
  };

  static List<String> getCinemaBrands() {
    return allCinemas.keys.toList();
  }

  static List<String> getRegionsForBrand(String brand) {
    return allCinemas[brand]?.keys.toList() ?? [];
  }

  static List<CinemaLocation> getCinemasInRegion(String brand, String region) {
    return allCinemas[brand]?[region] ?? [];
  }

  static CinemaLocation? getCinemaByName(String cinemaName) {
    for (var brand in allCinemas.keys) {
      for (var region in allCinemas[brand]!.keys) {
        for (var cinema in allCinemas[brand]![region]!) {
          if (cinema.name == cinemaName) {
            return cinema;
          }
        }
      }
    }
    return null;
  }

  static List<String> getAllCinemaNames() {
    List<String> allNames = [];
    for (var brand in allCinemas.keys) {
      for (var region in allCinemas[brand]!.keys) {
        for (var cinema in allCinemas[brand]![region]!) {
          allNames.add(cinema.name);
        }
      }
    }
    return allNames;
  }
}
