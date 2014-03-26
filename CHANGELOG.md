## 0.2.8 (2014/03/26)

Enhancement:

* Add support for uuid (uuid:random), uuid:hostname, uuid:timestamp

## 0.2.7 (2014/03/26)

Fixes:

* Fix `log` method was not available in the inner class #5. 

## 0.2.6 (2014/02/24)

Enhancement:

* Add debug log

## 0.2.5 (2014/02/04)

Enhancement:

* Support `log_level` option of Fleuntd v0.10.43

## 0.2.4 (2014/01/30)

Fixes:

* Fix `unitialized constant OpenStruct` error (thanks to emcgee)

## 0.2.3 (2014/01/25)

Changes:

* Change ${time} placeholder from integer to string when `enable_ruby false`

## 0.2.2 (2014/01/20)

Enhancement:

* Add `tag_prefix` and `tag_suffix` placeholders. Thanks to [xthexder](https://github.com/xthexder). 

## 0.2.1 (2014/01/15)

Enhancement:

* Speed up

## 0.2.0 (2014/01/15)

Enhancement:

* Support a `record` directive
* Add `remove_keys` option
* Add `renew_record` option
* Add `enable_ruby` option

## 0.1.1 (2013/11/21)

Changes:

* change the name of `tags` placeholder to `tag_parts`. `tags` is still available for old version compatibility, though

## 0.1.0 (2013/09/09)

Enhancement:

* require 'pathname', 'uri', 'cgi' to use these utilities in a placeholder

## 0.0.3 (2013/08/07)

Enhancement:

* Enable to reform tag

## 0.0.2 (2013/08/07)

Enhancement:

* Increase possible placeholders more such as `method`. 

## 0.0.1  (2013/05/02)

First release
