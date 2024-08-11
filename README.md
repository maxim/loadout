# Loadout

Rails vanilla config is good enough, but tends to get messy. This gem provides a few helpers to

- Reduce repetition
- Raise a helpful error when required values are not set
- Parse reasonable ENV values representing bools, ints, floats, and lists
- Raise a helpful error when an ENV value appears to be unreasonable/unintentional

You get these composable helpers:

- `cred`
- `env`
- `prefix`
- `bool`
- `int`
- `float`
- `list`

## Synopsis

```ruby
Rails.application.configure do
  extend Loadout::Helpers

  config.some_secret = cred(:secret) { 'default' }
  config.value_from_env_or_cred = env.cred(:key_name)

  prefix(:service) do
    config.x.service.optional_string = env.cred(:api_key) { 'default' }
    config.x.service.required_string = env.cred(:api_secret)

    config.x.service.optional_bool = bool.env(:bool_flag) { false }
    config.x.service.optional_int  = int.env.cred(:number) { nil }
    config.x.service.float         = float.env.cred(:number)
    config.x.service.array         = list.env(:comma_list)
  end
end
```

## Installation

Note: this gem requires Ruby 3.

Install the gem and add to the application's Gemfile by executing:

    $ bundle add loadout

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install loadout

## Usage

1. Include helpers into your `config/application.rb` and `config/environments/*.rb`:

    ```ruby
    extend Loadout::Helpers
    ```

    This should be done in each file where you'd like to use loadout.

2. Grab a value from credentials:

    ```ruby
    config.key = cred(:key_name)
    ```

    If you don't set this credential, you will get an error:

    ```
    Loadout::MissingConfigError: required credential (key_name) is not set
    ```

3. Or from ENV:

    ```
    config.key = env(:key_name)
    ```

    If you don't set this env, you will get an error:

    ```
    Loadout::MissingConfigError: required environment variable (KEY_NAME) is not set
    ```

4. Look up ENV, then credentials, then fail:

    ```ruby
    config.key = env.cred(:key_name)
    ```

    If neither are set, you will get an error:

    ```
    Loadout::MissingConfigError: required environment variable (KEY_NAME) or credential (key_name) is not set
    ```

5. Or the other way around:

    ```ruby
    config.key = cred.env(:key_name)
    ```

6. If it's a nested credential value, you can supply multiple keys:

    ```ruby
    # Look up service.key_name in credentials
    config.key = cred(:service, :key_name)
    ```

7. It will do the right thing if you also add env:

    ```ruby
    # Look up service.key_name in credentials, or SERVICE_KEY_NAME in ENV
    config.key = cred.env(:service, :key_name)
    ```

8. Parse ENV value into a boolean:

    ```ruby
    # Valid true strings: 1/y/yes/t/true
    # Valid false strings: "" or 0/n/no/f/false
    # (case insensitive)
    #
    # Any other string will raise an error.
    config.some_flag = bool.cred.env(:key_name)
    ```

    If you set an invalid value, you will get an error:

    ```
    Loadout::InvalidConfigError: invalid value for bool (`value`) in KEY_NAME
    ```

    Note: because credentials come from YAML, they don't need to be parsed. Only ENV values are parsed.

9. Integers and floats are also supported:

    ```ruby
    config.some_int   = int.cred.env(:int_key_name)
    config.some_float = float.cred.env(:float_key_name)
    ```

10. Lists are supported too:

    ```ruby
    # Parses strings like "foo, bar, baz", "foo|bar|baz", "foo bar baz" into ['foo', 'bar', 'baz']
    config.some_list = list.cred.env(:key_name)
    ```

11. You can set your own list separator (string or regex):

    ```ruby
    # Parses 'foo0bar0baz' into ['foo', 'bar', 'baz']
    config.some_list = list('0').env(:key_name)
    ```

12. Use a block at the end to specify a default value:

    ```ruby
    config.some_list = list.cred.env(:key_name) { ['default'] }
    ```

13. Use prefix to avoid repeating the same nesting:

    ```ruby
    prefix(:service) do
      config.x.service.api_key    = env(:api_key)    # Looks up "SERVICE_API_KEY"
      config.x.service.api_secret = env(:api_secret) # Looks up "SERVICE_API_SECRET"
    end
    ```

    Note that left hand side is unaffected. Only loadout helpers get auto-prefixed.

14. If you'd like a way to shorten the left hand side too, you can assign the whole group as a hash or OrderedOptions (this is not a loadout feature, just something you can do with Rails):

    ```ruby
    prefix(:service) do
      config.x.service = ActiveSupport::OrderedOptions[
        api_key:    env(:api_key),
        api_secret: env(:api_secret)
      ]
    end
    ```

15. Since `prefix` returns the block's result, you can rewrite the above as follows: 

    ```ruby
    config.x.service = prefix(:service) {
      ActiveSupport::OrderedOptions[
        api_key:    env(:api_key),
        api_secret: env(:api_secret)
      ]
    }
    ```

16. `prefix` lets you supply a default to the whole block:

    ```ruby
    prefix(:service, default: -> { 'SECRET' }) do
      config.x.service.api_key    = env(:api_key)    # falls back to 'SECRET'
      config.x.service.api_secret = env(:api_secret) # falls back to 'SECRET'
    end
    ```

## Advanced configuration

### I don't like all these helpers polluting my config!

Instead of `extend Loadout::Helpers` you can `extend Loadout` to include one proxy method `loadout`. Now all helpers live in one place.

```ruby
Rails.application.configure do
  extend Loadout

  config.some_key = loadout.cred.env(:some_key)
end
```

Feel free to alias it to something shorter if you'd like:

```ruby
Rails.application.configure do
  extend Loadout
  alias l loadout

  config.some_key = l.cred.env(:some_key)
end
```

### Credentials and ENV

By default loadout will look into `credentials` and `ENV` in your config's context. If your credentials are called something else, or you want to supply an alternative source of ENV, you can configure it like so:

```ruby
Rails.application.configure do
  extend Loadout::Helpers
  loadout creds: alt_credentials, env: alt_env

  # Now loadout will use alt_credentials and alt_env to look up values.
end
```


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/maxim/loadout. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/maxim/loadout/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Loadout project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/maxim/loadout/blob/main/CODE_OF_CONDUCT.md).
