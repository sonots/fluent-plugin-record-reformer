## 0.9.1 (2017/07/26)

Enhancements:

* Support multi process workers of v0.14.12.

## 0.9.0 (2017/02/21)

Enhancements:

* Use v0.14 API for fluentd v0.14

## 0.8.3 (2017/01/26)

Fixes

* Apply `remove_keys` last, otherwise, `renew_time_key` could be removed before generating new time

## 0.8.2 (2016/08/21)

Fixes

* Prevent overwriting reserved placeholder keys such as tag, time, etc with `enable_ruby false` (thanks to @kimamula)

## 0.8.1 (2016/03/09)

Fixes

* Fix to be thread-safe

Changes

* Relax conditions which auto_typecast is applied for enable_ruby yes

## 0.8.0 (2016/01/28)

Enhancements

* Support `${record["key"]}` placeholder
* Speed up `enable_ruby true`

## 0.7.2 (2015/12/29)

Enhancements

* Add desc to options (thanks to cosmo0920)

## 0.7.1 (2015/12/16)

Enhancements

* Add @id, @type, @label to BUILTIN_CONFIGURATIONS not to map into records (thanks to TrickyMonkey)

## 0.7.0 (2015/06/19)

Enhancements

* Add `auto_typecast` option (thanks to @piroor)

## 0.6.3 (2015/05/27)

Fixes:

* Fix not to include `renew_time_key` in records

## 0.6.2 (2015/05/27)

Enhancements:

* Add `renew_time_key` option (thanks to @tagomoris)

## 0.6.1 (2015/05/10)

Enhancements:

* Support label routing of Fluentd v0.12

## 0.6.0 (2015/04/11)

Changes:

* Accept field names starting with `@` (and any field names) in `enable_ruby false`

## 0.5.0 (2015/03/06)

Enhancements:

* Support JSON Array/Hash
* Support placeholders for keys

## 0.4.0 (2014/10/31)

Changes:

* accept numbers as a record key
* rescue if ruby code expansion failed, and log.warn
* use newly test-unit gem instead of rspec

## 0.3.0 (2014/10/01)

Fixes:

* Fix to support camelCase record key name with `enable_ruby false`

## 0.2.10 (2014/09/22)

Changes:

* Remove fluentd version constraint

## 0.2.9 (2014/05/14)

Enhancements:

* Add `keep_keys` option

## 0.2.8 (2014/04/12)

Changes:

* Deprecate `output_tag` option. Use `tag` option instead.

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
