# Navino-iOS

Navino is a mobile navigation app that allows user to mute directions when they are in areas they know. 
This is done by outlining known areas on the map before starting their directions.
This repository is the ios appication, android can be found at https://github.com/emmafw/Navino

To install this application xcode must be installed.
Download the repository and in terminal run pod install to install all dependencies outlined in the podfile.

To download the app to an iPhone, an Apple Developers License is required.
Follow these directions to allow the application to be installed.
https://ioscodesigning.com/generating-code-signing-files/

If running Navino on a simulator comment out lines 124 and 125 before running. 
These lines deal with the user's current location using CoreLocation and do not work on a simuator due to how current location
is simulated.
Directions features will also not work in the simulator as directions update based on user's current location which does not
update on the simulator. 

Once the app is installed the user will be required to sign in using a Google account.
