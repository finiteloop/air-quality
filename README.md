# Air Quality Reader for iOS and MacOS

## Overview

An iOS and MacOS application to display [PurpleAir](https://www.purpleair.com/)
air quality sensor data on a map, in a
[Widget](https://support.apple.com/en-us/HT207122) and a full application.

I created the application because I wanted a map of AQI on my iPhone home screen
via an [iOS 14 Widget](https://support.apple.com/en-us/HT207122). PurpleAir does
not have a native iOS app, and none of the other air quality apps support
widgets or had the same quality and breadth of data as PurpleAir, so I created
this application.

## Download

You can [download the iOS app](https://apps.apple.com/us/app/id1535362123) in
the App Store.

## Build / Contribute

You can build the iOS and MacOS clients in XCode.

  * [iOS](tree/master/client/ios)
  * [MacOS](tree/master/client/ios)

Our "server" is a two [AWS Lambda](https://aws.amazon.com/lambda/) functions:
one that downloads the PurpleAir JSON file on a schedule, converting its
verbose format to a terse
[Protocol Buffer](https://developers.google.com/protocol-buffers) format used
by our clients; and another that invalidates the CloudFront CDN that serves
that file to our clients.

See `[server/](tree/master/server)` for the two functions and the
[Serverless Application Model](serverless application model) configuration
file from which we deploy the service.

## Author

This is a personal project from [Bret Taylor](mailto:btaylor@gmail.com).

Data is exclusively from [PurpleAir](https://www.purpleair.com/). I am a
happy owner of multiple sensors! Buy one an contribute to the network!

The icon is from [Feather Icons](https://feathericons.com), modified slightly
to conform to iOS aesthetics.
