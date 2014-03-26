# fluent-plugin-record-reformer

[![Build Status](https://secure.travis-ci.org/sonots/fluent-plugin-record-reformer.png?branch=master)](http://travis-ci.org/sonots/fluent-plugin-record-reformer)

Fluentd plugin to add or replace fields of a event record

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
      
      output_tag reformed.${tag}
      <record>
        hostname ${hostname}
        input_tag ${tag}
        message ${message}, ${tag_parts[-1]}
      </record>
    </match>

Assume following input is coming (indented):

```js
foo.bar {
  "remove_me":"bar",
  "foo":"bar",
  "message":"Hello world!"
}
```

then output becomes as below (indented):

```js
reformed.foo.bar {
  "foo":"bar",
  "hostname":"YOUR_HOSTNAME",
  "input_tag":"foo.bar",
  "message":"Hello world!, bar",
}
```

## Configuration (Classic Style)

Example:

    <match foo.**>
      type record_reformer
      remove_keys remove_me
      renew_record false
      enable_ruby false
      output_tag reformed.${tag}
      
      hostname ${hostname}
      input_tag ${tag}
      message ${message}, ${tag_parts[-1]}
    </match>

This results in same, but please note that following option parameters are reserved, so can not be used as a record key.

## Option Parameters

- output_tag

    The output tag name

- remove_keys

    Specify record keys to be removed by a string separated by , (comma) like

        remove_keys message,foo

- renew_record *bool*

    Set to `true` if you do not want to extend (or merge) the input record fields. Default is `false`.

- enable_ruby *bool*

    Enable to use ruby codes in placeholders. See `Placeholders` section.
    Default is `true` (just for lower version compatibility). 

## Placeholders

The keys of input json are available as placeholders. In the above example, 

* ${foo}
* ${message}
* ${remove_me}

shall be available. In addition, following placeholders are reserved: 

* ${hostname} Hostname of the running machine
* ${uuid} or ${uuid_random} A randomly generated UUID
* ${uuid_hostname} A uuid based on the hostname
* ${uuid_timestamp} A uuid based on the time
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

## ChangeLog

See [CHANGELOG.md](CHANGELOG.md) for details.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new [Pull Request](../../pull/new/master)

## Copyright

Copyright (c) 2013 Naotoshi SEO. See [LICENSE](LICENSE) for details.
