# cybozu2ical-perl

Converts Cybozu Office Scheduler to ''ical'' format on the wire.

## Name

cybozu2ical - Convert Cybozu Office calendar into iCalendar format

## Synopsis

    % cybozu2ical
    % cybozu2ical --conf /path/to/config.yaml

## Description

"cybozu2ical" is a command line application that fetches calendar items from Cybozu Office 6 or later, and converts them into an iCalendar file.  It allows you to easily integrate the Cybozu Calendar into iCalendar-enabled Calendar applications, such as Microsoft Outlook, Apple iCal, and of course, Google Calendar.

You can run this via crontab, for example, every 1 hour.

## Requirement

This application requires perl 5.8.0 with following Perl modules installed on your box.

 * Text::CSV_XS or Text::CSV
 * DateTime
 * LWP::UserAgent
 * Class::Accessor::Fast
 * Data::ICal
 * YAML or YAML::Tiny

## Options

This application has a command-line option as follows:

 * --output /path/to/output.ics: Specify the output file. By default, this application outputs to STDOUT.
 * --conf /path/to/config.yaml: Specify the configuration file. By default, "config.yaml" in the current directory will be used.
 * --compat-google-calendar: Output an iCalendar file compatible with Google Calendar.
 * --debug: Output CSV data in a COMMENT field of each events. It's just for debugging.
 * --input-csv /path/to/input.csv: Instead of requesting Cybozu Office 6 server, read from a local CSV file.
 * --output-csv /path/to/output.csv: Specify the output CSV file for debugging.
 * --uid, --no-uid: Enable/Disable UID fields of the iCalendar file (Default: Enable)
 * --url, --no-url: Enable/Disable URL fields of the iCalendar file (Default: Disable)
 * --help: Print out this message.

## Configuration

The distributions includes a sample configuration file "config.yaml.sample". You can rename it to "config.yaml" and configure "cybozu2ical".

 * cybozu_url: Set the URL of your Cybozu Office 6 or later.
 * calname: Set the calendar name string. iCalendar applications which properly handle X-WR-CALNAME header, is expected to use this string as a calendar name.
 * username, userid: Set your username or userid for Cybozu Office.
 * password: Set your password for Cybozu Office.
 * time_zone: Set the timezone of your Cybozu Office (e.g., Asia/Tokyo).
 * tzname: Set the short timezone name of your Cybozu Office (e.g., JST).
 * input_encoding: Set the charset of Cybozu Office. By default, "input_encoding" is "shiftjis".
 * output_encoding: Set the charset of the iCalendar file. By default, "output_encoding" is "utf8". If you need to output multibyte strings as Numeric Character References for some reason, set "output_encoding" to "ncr".
 * calendar_driver: Set the calendar driver that "cybozu2ical" employs. By default, "ApiCalendar" is used as "calendar_driver". Currently, "ApiCalendar" and "SyncCalendar" drivers are shipped with "cybozu2ical". If you are using Cybozu Office 6, "SyncCalendar" is strongly recommended. Otherwise, you have to use "ApiCalendar".
 * date_range (experimental): Set the date range of calendar, which means "cybozu2ical" handles calendar items between N days before and after. Default "date_range" is 30.

## Changes

### 0.32 (2008-09-07 15:39:56 +0900)

 * TBD

### 0.31 (2008-08-30 01:01:57 +0900)
### 0.30 (2008-08-29 02:27:57 +0900)
### 0.20 (2007-10-17 17:16:49 +0900)
### 0.13 (2007-06-18 10:38:39 +0900)
### 0.12 (2007-03-22 13:39:06 +0900)
### 0.11 (2006-11-19 20:17:08 +0900)
### 0.10 (2006-11-10 00:18:31 +0900)
### 0.07 (2006-11-06 10:21:00 +0900)
### 0.06 (2006-09-04 14:11:59 +0900)
### 0.05 (2006-08-11 12:21:30 +0900)
### 0.04 (2006-04-21 16:09:05 +0900)

### 0.03 (2006/04/17 07:59:25)

 * Now employ Getopt::Long and Pod::Usage and support sophisticated command-line options.

### 0.02 (2006-04-16 10:44:39)

 * Add TimeZone support.
 * Date::ICal was replaced by DateTime module.
 * Add an installation script .

### 0.01 (2006/04/15 16:29:24)

 * Initial Release.

## See Also

## License

Copyright (c) 2008 Hirotaka Ogawa <hirotaka.ogawa at gmail.com>.
All rights reserved.

This library is free software; you can redistribute it and/or modify it under the terms of either:

 a) the GNU General Public License as published by the Free Software Foundation; either version 1, or (at your option) any later version, or
 b) the "Artistic License" which comes with Perl.
