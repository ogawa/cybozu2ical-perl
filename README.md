# cybozu2ical-perl

サイボウズオフィス6のカレンダーをiCalendar形式に変換するスクリプト。

## Name

cybozu2ical - サイボウズオフィスのカレンダーをiCalendar形式に変換するスクリプト

## Synopsis

    % cybozu2ical
    % cybozu2ical --conf /path/to/config.yaml

## Description

cybozu2icalは、サイボウズオフィス6以降のカレンダーアイテムを取得して、iCalendar形式に変換するコマンドラインプログラムです。このプログラムを利用することで、サイボウズのカレンダーを、iCalendar形式をサポートするアプリケーション(Microsoft Outlook, Apple iCal, Google Calendarなど)に簡単に統合できます。

このプログラムを、例えば一時間に一度、cronで実行することもできる。

## Requirement

このプログラムはPerl 5.8.0以降、および以下のモジュールを必要とします。

 * Text::CSV 1.0+
 * DateTime
 * LWP
 * Crypt-SSLeay (httpsで接続する場合)
 * Class::Accessor::Fast
 * Data::ICal
 * YAML または YAML::Tiny

## Options

コマンドラインオプションとして以下が指定できます。

 * --output /path/to/output.ics: 出力ファイルへのパスを指定します。デフォルトでは標準出力に出力します。
 * --conf /path/to/config.yaml: 設定ファイルへのパスを指定します。デフォルトではカレントディレクトリのconfig.yamlファイルを設定ファイルとして利用します。
 * --compat-google-calendar: Google Calendarと互換性のあるiCalendar形式で出力します。
 * --debug: Cybozu OfficeのCSVデータを各イベントのCOMMENTとして出力します(デバッグ用)。
 * --input-csv /path/to/input.csv: Cybozu Officeサーバにアクセスする代わりに、指定したCSVファイルを読み込んでiCalendar形式に変換します(デバッグ用)。
 * --output-csv /path/to/output.csv: Cybozu Officeサーバから取得したCSVデータを指定したファイルに出力します(デバッグ用)。
 * --uid, --no-uid: 各イベントのUIDフィールドの出力をするかどうかを指定します。デフォルトでは出力します。
 * --url, --no-url: 各イベントのURLフィールドの出力をするかどうかを指定します。デフォルトでは出力しません。
 * --help: コマンドラインオプションを表示します。

## Configuration

ディストリビューションには、サンプル設定ファイルconfig.yaml.sampleが含まれています。このファイルを適宜コピーして設定してください。config.yamlの設定オプションは以下の通りです。

 * cybozu_url: サイボウズオフィスのURLを指定します。
 * calname: カレンダー名を指定します。X-WR-CALNAMEヘッダを利用するiCalendarアプリでは、ここで指定した文字列がカレンダーの名前として利用されることが期待されます。
 * username, userid: サイボウズオフィスのユーザ名もしくはユーザIDを指定します。
 * password: サイボウズオフィスのパスワードを指定します。
 * time_zone: サイボウズオフィスのTimeZoneを指定します(例: Asia/Tokyo)。
 * tzname: サイボウズオフィスのTimeZoneを指定します(例: JST)。
 * input_encoding: サイボウズオフィスのcharsetを指定します。デフォルトは「shiftjis」。
 * output_encoding: 出力するiCalendarファイルのcharsetを指定します。デフォルトは「utf8」。マルチバイト文字を数値文字参照で出力する場合には「ncr」を指定します。
 * calendar_driver: 使用するカレンダードライバーを指定します。デフォルトでは「ApiCalendar」が使われます。現在のところ、カレンダードライバーとしてApiCalendarとSyncCalendarの2つが使用できます。サイボウズオフィス6を使用している場合にはSyncCalendarを指定することを強く勧めます。それ以外の場合はデフォルトで問題ありません。
 * date_range (experimental): カレンダーの日付レンジを指定します。date_rangeにNを指定すると、今日のN日前からN日後までの日付レンジのアイテムのみをサイボウズオフィスから取得して処理します。デフォルトのdate_rangeは「30」です。この機能はカレンダードライバーとしてApiCalendarを指定している場合のみ有効です。

## Changes

### 0.36 (2009-09-02 15:35:29 +0900)

 * カレンダーイベントが存在しない場合にエラー終了する問題を修正した。
 * SyncCalendarを使っている場合、メモに改行文字が含まれていると正しく処理されない問題を修正した。
 * その他のバグ修正。

### 0.35 (2009-07-21 22:31:08 +0900)

 * 繰り返しイベントおよび除外日の処理のバグを修正した。

### 0.34 (2009-03-24 15:36:28 +0900)

 * Text::CSV 1.0以降との組み合わせでうまく動かない問題を修正した。
 * サイボウズオフィスのユーザ認証エラーを一応検出できるようにした。

### 0.33 (2009-02-05 19:24:52 +0900)

 * updateモードを追加した。--update=file.icsと指定すると、file.icsに含まれるデータのうち更新・追加されたもののみ追記する。
 * カレンダーの日付範囲の指定方法を変更した。date_rangeを指定しない場合には、今年の元旦から大晦日までのデータを取得する。date_rangeを指定した場合には、指定された日数前の日にちから大晦日までのデータを取得する。ドキュメントをまだ訂正していませんが、そうなっています。
 * リファクタリングたくさん。

### 0.32 (2008-09-07 15:39:56 +0900)

 * UIDが一定になるように修正した。EIDとホスト名のみから決定するようにした。
 * 終日イベントの処理が不完全だったので修正した。
 * Calendar::Eventクラスのコンストラクタへのパラメータをサイボウズに準拠したものに変更した。
 * Calendar::Eventクラスのフィールドへのアクセスを厳格にアクセッサメソッドを使って行うように変更した。
 * Calendar::Eventクラスにis_shared, is_privateメソッドを追加した。

### 0.31 (2008-08-30 01:01:57 +0900)

 * カレンダーAPIのリファクタリングを真っ当にした。
 * --uid, --no-uid, --url, --no-urlオプションを追加した。
 * 予定のメモに改行が含まれる場合、二行目以降を無視してしまうバグを修正した。
 * 繰り返し予定に除外日がある場合、正常に処理できないバグを修正した。

### 0.30 (2008-08-29 02:27:57 +0900)

 * サイボウズオフィス7に対応するためにApiCalendar APIでカレンダーアイテムを取得できるようにした。
 * カレンダーAPIの変更に対応しやすいように、API操作部分をリファクタリングしてFactoryパターンっぽく(笑)した。
 * ドキュメントの更新をした。

### 0.20 (2007-10-17 17:16:49 +0900)

 * --output、--input-csv、--output-csvオプションの追加。
 * 対応する反復イベントの拡張。月の第何週かだけ繰り返すように指定したスケジュールに対応した。
 * MacOS X iCalendarのバグに対応するため、RRULE内でUNTILプロパティを最後に指定するようにした。
 * --compat-google-calendarオプションの追加。Google Calendarのバグに対応するためにRRULE内でWKST=SUプロパティを指定する必要があるが、この指定はMacOS X iCalendarと互換性がない。デフォルトではWKST=SUプロパティは出力せず、--compat-google-calendarオプションを指定した場合のみ出力するようにした。
 * その他、細かいリファクタリングなど。

### 0.13 (2007-06-18 10:38:39 +0900)

 * --debugオプションの追加。--debugオプション指定時に、VEVENTのCOMMENTとしてサイボウズオフィス6から取得できるCSVデータを出力するようにした。
 * VEVENTのUIDを生成するようにした。
 * 反復イベントにおいて、反復期間の先頭のイベントを削除(または削除せずに時刻のみ変更)すると、誤ったイベントデータが生成される問題に対処した。
 * 反復イベントのうち一部を削除(または時刻のみ変更)した場合にEXDATEを生成して正しく反復イベントを生成するようにした。
 * Data-ICalにおいて、EXDATEに「,」が含まれる場合に不必要なエスケープがなされてしまう問題に対処した。
 * OO-styleで書き直した。

### 0.12 (2007-03-22 13:39:06 +0900)

 * 反復イベント処理のデバッグ。時刻指定のある反復イベントのRRULEのUNTILはUTC時刻で指定し、時刻指定のない反復イベントのUNTILは日付で指定するようにした。
 * Google Calendarには時刻指定のない反復イベントの終了日時が一日ずれるバグがある模様。RRULEにWKST="SU"オプションを追加することでこの問題が回避できるようなので、そのように対処してある。

### 0.11 (2006-11-19 20:17:08 +0900)

 * 終了時刻が指定されない場合の処理で、開始時刻が10分遅れになる問題を修正。
 * 終了時刻が「24:00」と指定された場合に「23:59:59」に丸める処理を追加。
 * 開始・終了時刻が不正な範囲にある場合のエラー処理を追加。

### 0.10 (2006-11-10 00:18:31 +0900)

 * Cybozu Office 6からカレンダーデータを取得する処理をrefactoringして、WWW::CybozuOffice6::Calendarモジュールに分離した。
 * 時刻を含まない日付情報(終日イベント、バナーイベントなどのDTSTART, DTENDなど)は、Date-Typeとして「DATE」を指定するようにした。
 * 反復イベントに対応した。

### 0.07 (2006-11-06 10:21:00 +0900)

 * 終了時刻のないイベントの日付フォーマットが壊れていたので修正。
 * イベントの「予定」のプルダウン項目をサポート。

### 0.06 (2006-09-04 14:11:59 +0900)

 * useridでのログインをサポート。

### 0.05 (2006-08-11 12:21:30 +0900)

 * Data::ICal::Property::_fold()でマルチバイト文字の途中でfoldしてしまう問題を回避。この対策は、fold前にdecode_utf8、fold後にencode_utf8しているため、fold文字列は「標準」の規定より長くなるが…しかたがない。
 * 終了時刻のないイベントに対応。
 * Numerical Character Referenceで出力する機能を追加。
 * X-WR-TIMEZONEヘッダを追加。
 * DTSTART/DTENDにTZIDプロパティーを追加。
 * config.yamlで入出力エンコーディングを指定できるようにした。

### 0.04 (2006-04-21 16:09:05 +0900)

 * 設定ファイルにcalnameオプションを追加。
 * 繰り返し予定で生じるエラーを回避。
 * VERSIONヘッダが不正だったのを修正。

### 0.03 (2006-04-17 16:59:25 +0900)

 * config.yamlファイルの指定方法を変更。

### 0.02 (2006-04-16 19:44:39 +0900)

 * サイボウズオフィス6のTimeZoneが指定可能になった。
 * Date::ICalをDateTimeに置き換え。
 * インストレーションスクリプトを追加。

### 0.01 (2006-04-16 01:29:24 +0900)

 * 公開。

## See Also

## License

Copyright (c) 2008 Hirotaka Ogawa <hirotaka.ogawa at gmail.com>.
All rights reserved.

This library is free software; you can redistribute it and/or modify it under the terms of either:

 a) the GNU General Public License as published by the Free Software Foundation; either version 1, or (at your option) any later version, or
 b) the "Artistic License" which comes with Perl.
