# fluent-plugin-record-reformer

[![Build Status](https://secure.travis-ci.org/sonots/fluent-plugin-record-reformer.png?branch=master)](http://travis-ci.org/sonots/fluent-plugin-record-reformer)

Fluentd pluging to add or replace fields of a event record

## Installation

Use RubyGems:

    gem install fluent-plugin-record-reformer

## Configuration

Example:

    <match foo.**>
      type record_reformer
      output_tag reformed.${tag}
      remove_keys remove_me
      renew_record false
      enable_ruby false
      
      <record>
        hostname ${hostname}
        input_tag ${tag}
        message ${hostname} ${tag_parts[-1]} ${message}
      </record>
    </match>

Assume following input is coming:

```js
foo.bar {"message":"hello world!", "foo":"bar", "remove_me":"bar"}
```

then output becomes as below (indented):

```js
reformed.foo.bar {
  "foo":"bar",
  "hostname":"your_hostname", 
  "input_tag":"foo.bar",
  "message":"your_hostname bar hello world!",
}
```

## Configuration (Classic Style)

Example:

    <match foo.**>
      type record_reformer
      output_tag reformed.${tag}
      remove_keys remove_me
      renew_record false
      enable_ruby false
      
      hostname ${hostname}
      input_tag ${tag}
      message ${hostname} ${tag_parts[-1]} ${message}
    </match>

This results in same, but please note that following option parameters are reserved, and can not be used as a record key.

## Parameters

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

shall be available. In addition, following placeholders are reserved: 

* ${hostname} hostname
* ${tag} input tag
* ${time} time of the event
* ${tags[N]} input tag splitted by '.' (obsolete. use tag\_parts)
* ${tag\_parts[N]} input tag splitted by '.' indexed with N such as `${tag_parts[0]}`, `${tag_parts[-1]}`. 

It is also possible to write a ruby code in placeholders if you set `enable_ruby true` option, so you may write some codes as

* ${time.strftime('%Y-%m-%dT%H:%M:%S%z')}
* ${tag\_parts.last}

but, please note that enabling ruby codes is not encouraged by security reasons and also in terms of the performance.

## Relatives

I created this plugin inspired by [fluent-plugin-record-modifier](https://github.com/repeatedly/fluent-plugin-record-modifier). 
I chose not to send pull requests because the implementation of this plugin became completely different with it.

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
