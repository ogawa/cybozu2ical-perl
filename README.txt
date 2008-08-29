NAME
    cybozu2ical - Convert Cybozu Office calendar into iCalendar format

SYNOPSIS
      % cybozu2ical
      % cybozu2ical --conf /path/to/config.yaml

DESCRIPTION
    "cybozu2ical" is a command line application that fetches calendar items
    from Cybozu Office 6 or later, and converts them into an iCalendar file.
    It allows you to easily integrate the Cybozu Calendar into
    iCalendar-enabled Calendar applications, such as Microsoft Outlook,
    Apple iCal, and of course, Google Calendar.

    You can run this via crontab, for example, every 1 hour.

REQUIREMENT
    This application requires perl 5.8.0 with following Perl modules
    installed on your box.

    WWW::CybozuOffice6::Calendar
    Text::CSV_XS or Text::CSV
    DateTime
    LWP::UserAgent
    Class::Accessor::Fast
    Data::ICal
    YAML or YAML::Tiny

OPTIONS
    --output /path/to/output.ics
        Specify the output file. By default, this application outputs to
        STDOUT.

    --conf /path/to/config.yaml
        Specify the configuration file. By default, "config.yaml" in the
        current directory will be used.

    --compat-google-calendar
        Output an iCalendar file compatible with Google Calendar.

    --debug
        Output CSV data in a COMMENT field of each events. It's just for
        debugging.

    --input-csv /path/to/input.csv
        Instead of requesting Cybozu Office 6 server, read from a local CSV
        file.

    --output-csv /path/to/output.csv
        Specify the output CSV file for debugging.

    --uid, --no-uid
        Enable/Disable UID fields of the iCalendar file. (Default: Enable)

    --url, --no-url
        Enable/Disable URL fields of the iCalendar file. (Default: Disable)

    --help
        Print out this message.

CONFIGURATION
    The distributions includes a sample configuration file
    "config.yaml.sample". You can rename it to "config.yaml" and configure
    "cybozu2ical".

    cybozu_url
        Set the URL of your Cybozu Office 6 or later.

    calname
        Set the calendar name string. iCalendar applications which properly
        handle X-WR-CALNAME header, is expected to use this string as a
        calendar name.

    username, userid
        Set your username or userid for Cybozu Office.

    password
        Set your password for Cybozu Office.

    time_zone
        Set the timezone of your Cybozu Office (e.g., Asia/Tokyo).

    tzname
        Set the short timezone name of your Cybozu Office (e.g., JST).

    input_encoding
        Set the charset of Cybozu Office. By default, "input_encoding" is
        "shiftjis".

    output_encoding
        Set the charset of the iCalendar file. By default, "output_encoding"
        is "utf8". If you need to output multibyte strings as Numeric
        Character References for some reason, set "output_encoding" to
        "ncr".

    calendar_driver
        Set the calendar driver that "cybozu2ical" employs. By default,
        "ApiCalendar" is used as "calendar_driver".

        Currently, "ApiCalendar" and "SyncCalendar" drivers are shipped with
        "cybozu2ical". If you are using Cybozu Office 6, "SyncCalendar" is
        strongly recommended. Otherwise, you have to use "ApiCalendar".

    date_range (experimental)
        Set the date range of calendar, which means "cybozu2ical" handles
        calendar items between N days before and after. Default "date_range"
        is 30.

DEVELOPMENT
    The development version is always available from the following
    subversion repository:

      http://code.as-is.net/svn/public/cybozu2ical/trunk/

    You can browse the files via Trac from the following:

      http://code.as-is.net/public/browser/cybozu2ical/trunk/

    Any comments, suggestions, or patches are welcome.

LICENSE
    Copyright (c) 2008 Hirotaka Ogawa <hirotaka.ogawa at gmail.com>. All
    rights reserved.

    This library is free software; you can redistribute it and/or modify it
    under the terms of either:

       a) the GNU General Public License as published by the Free Software
          Foundation; either version 1, or (at your option) any later
          version, or
                         
       b) the "Artistic License" which comes with Perl.

