# fluent-plugin-record-reformer

[![Build Status](https://secure.travis-ci.org/sonots/fluent-plugin-record-reformer.png?branch=master)](http://travis-ci.org/sonots/fluent-plugin-record-reformer)

Fluentd plugin to add or replace fields of a event record

## Requirements

See [.travis.yml](.travis.yml)

Note that `fluent-plugin-record-reformer` supports both v0.14 API and v0.12 API in one gem.

## Installation

Use RubyGems:

    gem install fluent-plugin-record-reformer

## Configuration

Example:

    <match foo.**>
      type record_reformer
      remove_keys remove_me
      renew_record false
      enable_ruby false
      
      tag reformed.${tag_prefix[-2]}
      <record>
        hostname ${hostname}
        input_tag ${tag}
        last_tag ${tag_parts[-1]}
        message ${record['message']}, yay!
      </record>
    </match>

Assume following input is coming (indented):

```js
foo.bar {
  "remove_me":"bar",
  "not_remove_me":"bar",
  "message":"Hello world!"
}
```

then output becomes as below (indented):

```js
reformed.foo {
  "not_remove_me":"bar",
  "hostname":"YOUR_HOSTNAME",
  "input_tag":"foo.bar",
  "last_tag":"bar",
  "message":"Hello world!, yay!",
}
```

## Configuration (Classic Style)

Example:

    <match foo.**>
      type record_reformer
      remove_keys remove_me
      renew_record false
      enable_ruby false
      tag reformed.${tag_prefix[-2]}
      
      hostname ${hostname}
      input_tag ${tag}
      last_tag ${tag_parts[-1]}
      message ${record['message']}, yay!
    </match>

This results in same, but please note that following option parameters are reserved, so can not be used as a record key.

## Option Parameters

- output_tag (obsolete)

    The output tag name. This option is deprecated. Use `tag` option instead

- tag

    The output tag name. 

- remove_keys

    Specify record keys to be removed by a string separated by , (comma) like

        remove_keys message,foo

- renew_record *bool*

    `renew_record true` creates an output record newly without extending (merging) the input record fields. Default is `false`.

- renew\_time\_key *string*

    `renew_time_key foo` overwrites the time of events with a value of the record field `foo` if exists. The value of `foo` must be a unix time.

- keep_keys

    You may want to remain some record fields although you specify `renew_record true`. Then, specify record keys to be kept by a string separated by , (comma) like

        keep_keys message,foo

- enable_ruby *bool*

    Enable to use ruby codes in placeholders. See `Placeholders` section.
    Default is `true` (just for lower version compatibility). 

- auto_typecast *bool*

    Automatically cast the field types. Default is false.
    NOTE: This option is effective only for field values comprised of a single placeholder. 

    Effective Examples:
    
        foo ${foo}
    
    Non-Effective Examples:
    
        foo ${foo}${bar}
        foo ${foo}bar
        foo 1
    
    Internally, this **keeps** the type of value if the value text is comprised of a single placeholder, otherwise, values are treated as strings. 
    
    When you need to cast field types manually, [out_typecast](https://github.com/tarom/fluent-plugin-typecast) and [filter_typecast](https://github.com/sonots/fluent-plugin-filter_typecast) are available. 

## Placeholders

Following placeholders are available:

* ${record["key"]} Record value of `key` such as `${record["message"]}` in the above example (available from v0.8.0).
  * Originally, record placeholders were available as `${key}` such as `${message}`. This is still kept for the backward compatibility, but would be removed in the future.
* ${hostname} Hostname of the running machine
* ${tag} Input tag
* ${time} Time of the event
* ${tags[N]} (Obsolete. Use tag\_parts) Input tag splitted by '.'
* ${tag\_parts[N]} Input tag splitted by '.' indexed with N such as `${tag_parts[0]}`, `${tag_parts[-1]}`. 
* ${tag\_prefix[N]} Tag parts before and on the index N. For example,

        Input tag: prefix.test.tag.suffix
        
        ${tag_prefix[0]}  => prefix
        ${tag_prefix[1]}  => prefix.test
        ${tag_prefix[-2]} => prefix.test.tag
        ${tag_prefix[-1]} => prefix.test.tag.suffix

* ${tag\_suffix[N]} Tag parts after and on the index N. For example,

        Input tag: prefix.test.tag.suffix
    
        ${tag_suffix[0]}  => prefix.test.tag.suffix
        ${tag_suffix[1]}  => test.tag.suffix
        ${tag_suffix[-2]} => tag.suffix
        ${tag_suffix[-1]} => suffix

It is also possible to write a ruby code in placeholders if you set `enable_ruby true` option, so you may write some codes as

* ${time.strftime('%Y-%m-%dT%H:%M:%S%z')}
* ${tag\_parts.last}

but, please note that enabling ruby codes is not encouraged by security reasons and also in terms of the performance.

## Relatives

Following plugins look similar:

* [fluent-plugin-record-modifier](https://github.com/repeatedly/fluent-plugin-record-modifier)
* [fluent-plugin-format](https://github.com/mach/fluent-plugin-format)
* [fluent-plugin-add](https://github.com/yu-yamada/fluent-plugin-add)
* [filter_record_transformer](http://docs.fluentd.org/v0.12/articles/filter_record_transformer) is a Fluentd v0.12 built-in plugin which is based on record-reformer.

## ChangeLog

See [CHANGELOG.md](CHANGELOG.md) for details.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new [Pull Request](../../pull/new/master)

## Copyright

Copyright (c) 2013 - 2015 Naotoshi Seo. See [LICENSE](LICENSE) for details.
