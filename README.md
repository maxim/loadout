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
    config.x.service.optional_value = env.cred(:api_key) { 'default' }
    config.x.service.required_value = env.cred(:api_secret)
    config.x.service.optional_bool  = bool.env(:bool_flag) { false }
    config.x.service.optional_int   = int.env.cred(:some_int) { nil }
    config.x.service.required_float = float.env.cred(:some_float)
    config.x.service.required_array = list.env(:comma_list)
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

1. Include helpers into your `config/environments/*.rb`:

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

14. `prefix` lets you supply a default to the whole block:

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

## Tips and Tricks

### What should I put in `application.rb`?

All your environments load `application.rb` as their dependency. That's why you should not put any hard requirements (`env` or `cred`) into application.rb. It would make all dependent environments crash unless every single env and cred is provided. And you will not be able to override these requirements, because ruby parses application.rb first.

```ruby
# application.rb
config.some_secret = env(:some_secret)
```

```ruby
# test.rb (BAD, DOESN'T WORK)
config.some_secret = cred(:some_secret) { 'secret' } # <= ruby will not get here
```

Ruby will never get to test.rb, because application.rb will crash when it can't find `ENV['SOME_SECRET']`.

My recommended approach is to put only defaults and nils in your application.rb. Assign only literal values so that you have a comprehensive list of every supported configuration in one place. Then you can add stricter requirements (via helpers like `env` and `cred`) to your actual environment files.

```ruby
# application.rb
config.some_secret = 'default'
```

```ruby
# development.rb
config.some_secret = cred(:some_secret)
```

```ruby
# test.rb (cred for VCR recording, default otherwise)
config.some_secret = cred(:some_secret) { 'secret' }
```

```ruby
# production.rb
config.some_secret = env(:some_secret)
```

This will work.


### What if one environment depends on another?

If you have [dependencies between environment files](https://signalvnoise.com/posts/3535-beyond-the-default-rails-environments), for example your staging.rb depends on your production.rb, and has relaxed requirements compared to production, here's a trick you can use.

```ruby
# production.rb
config.some_secret = env(:some_secret) if Rails.env.production?
```

```ruby
# staging.rb
config.some_secret = env(:some_secret) { 'default' }
```

Note the condition in production.rb. Now you are requriing `ENV['SOME_SECRET']` in production, while allowing a default in staging.


### Cleaning up nested settings

Here are some examples on how you can make nested config settings look neat.

**Use `tap` for literals**

```ruby
config.x.service.tap do |service|
  service.api_key    = 'key'
  service.api_secret = 'secret'
  service.api_url    = 'https://api.example.com'
end
```

**Use local variable with `prefix`**

```ruby
prefix(:service) do
  service            = config.x.service
  service.api_key    = env(:api_key)
  service.api_secret = env(:api_secret)
  service.api_url    = env(:api_url)
end
```

**Use `OrderedOptions` with `prefix`**

Be careful, this overwrites the whole service config.

```ruby
config.x.service = prefix(:service) do
  ActiveSupport::OrderedOptions[
    api_key:    env(:api_key),
    api_secret: env(:api_secret),
    api_url:    env(:api_url)
  ]
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
