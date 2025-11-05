Global Prayer Time Finder (API Test)

This Flutter test app experiments with API fetching by combining two public APIs which are IslamicAPI
 and OpenCage Geocoding API
.
It allows users to type any city or country name and view the local prayer times for that location.

 How It Works

- The user enters a city or country name in the search bar.

- The app sends the name to OpenCage, which returns the latitude and longitude for that place.

- These coordinates are then used to call IslamicAPI, which provides the daily prayer times.

- The results are displayed in a simple, clean interface.

 APIs Used

- OpenCage Geocoding API : converts city or country names into latitude/longitude.

- IslamicAPI : provides prayer times based on coordinates.
