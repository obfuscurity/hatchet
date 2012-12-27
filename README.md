# Hatchet

## Overview

Hatchet is a log parsing/presentation program written for OpenBSD's PF logs. The main script, `hatchet`, should be run every 15 minutes, or as often as you wish. Depending on the size of your logfiles versus the speed of your machine, you may wish to tweak how often it runs.

Hatchet uses a series of Perl regexes to match entries from the pflog logs. The log entries are stored in a SQLite database file, allowing for highly dynamic queries and statistics. If it finds one it doesn't have a match for, it will kick off an email to the system administrator (`root@localhost`) with the details. This setting can be modified in the configuration file (`hatchet.conf`).

## Screenshots

![Events Listing](blob/master/images/screenshot.png)

## Installation

Hatchet uses the default OpenBSD httpd chroot. This is made possible thanks to mod_perl. No special effort is required outside of the instructions listed below.

Install the Hatchet directory:

```bash
$ cd /var/www/
$ sudo git clone https://github.com/obfuscurity/hatchet.git
```

Install the following Perl modules:

```
DBI (databases/p5-DBI)
DBD::Chart (databases/p5-DBD-Chart)
DBD::SQLite (databases/p5-DBD-SQLite)
GD (graphics/p5-GD)
GD::Text (graphics/p5-GD-TextUtil)
HTML::Template (www/p5-HTML-Template)
```

Install mod_perl (`www/mod_perl`) and enable the module:

```bash
$ sudo mod_perl-enable
```

Add an entry in `httpd.conf` and restart httpd. Example:

```
        <VirtualHost _default_:80>
            DocumentRoot /var/www/hatchet
            PerlModule Apache::PerlRun
            <Location /cgi/>
                SetHandler perl-script
                PerlHandler Apache::PerlRun
                PerlRequire /var/www/hatchet/cgi/startup.pl
                Options ExecCGI
                PerlSendHeader On
                allow from all
            </Location>
        </VirtualHost>
```

Create the database:

```bash
$ cd /var/www/hatchet/sbin/
$ sudo ./hatchet_mkdb
```

Add the cron entries:

```bash
14,29,44,59 * * * *     sudo /var/www/hatchet/sbin/hatchet
19,34,49,04 * * * *     sudo /var/www/hatchet/sbin/hatchart
```

## Logging

Hatchet parses PF logs and saves the events in a simple SQLite database. The average PF user should already be familiar with the logging features in PF, but it bears mention here as well.

Logging is enabled on a per-rule basis using the `log` keyword. The use of this option should be considered carefully, as it is very easy to overwhelm your firewall with useless event logging. I have seen users with a `pass log all` default match, then complain on the Hatchet mailing list about slow response time in their web interface. This is an easy way to subscribe yourself to my `/dev/null`.

Utilize the log feature to your benefit, not your detriment. Keep in mind that the purpose of good logs are to keep an audit trail of unwanted traffic, and more specifically, notify you of possible attacks (although an IDS is the correct tool for that task). The "noise ratio" should not become so problematic that useful events are overlooked or ignored.

Bad example:

```
    block in log
```

Good example:

```
    block in
    block in on $ext_if
    block in log on $ext_if inet proto tcp port 445
```

Although the filter results are the same, the 2nd example takes advantage of the `last match` philosophy. It will only log TCP packets destined for port 445 on the external interface. The previous example will log every silly packet that isn't explicitly passed, including those on the local LAN.

## License

Copyright (c) 2008-2012, Jason Dixon <jason@dixongroup.net>
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, 
are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice, this
list of conditions and the following disclaimer in the documentation and/or other
materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
