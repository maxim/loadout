# frozen_string_literal: true

require 'test_helper'

class TestLoadout < Minitest::Test
  ENV_KEY = 'LOADOUT_TEST_ENV'
  ENV_SYM = ENV_KEY.downcase.to_sym
  ENV_SYMS = ENV_KEY.split('_').map { _1.downcase.to_sym }

  def setup
    config_class = Class.new { attr_accessor :credentials }

    @config1 = config_class.new.tap { _1.extend(Loadout) }
    @config1.credentials = {}

    @config2 = config_class.new.tap { _1.extend(Loadout::Helpers) }
    @config2.credentials = {}
  end

  def teardown = ENV.delete(ENV_KEY)

  ##############################################################################
  # MODULE INCLUDE TESTS                                                       #
  ##############################################################################
  def test_config_without_helpers_has_only_loadout
    assert_respond_to @config1, :loadout

    refute_respond_to @config1, :cred
    refute_respond_to @config1, :env
    refute_respond_to @config1, :prefix
    refute_respond_to @config1, :bool
    refute_respond_to @config1, :int
    refute_respond_to @config1, :float
    refute_respond_to @config1, :list
  end

  def test_config_with_helpers_has_all_helpers
    assert_respond_to @config2, :loadout
    assert_respond_to @config2, :cred
    assert_respond_to @config2, :env
    assert_respond_to @config2, :prefix
    assert_respond_to @config2, :bool
    assert_respond_to @config2, :int
    assert_respond_to @config2, :float
    assert_respond_to @config2, :list
  end

  def test_env_and_creds_are_configurable
    alt_env = { 'FOO' => 'bar' }
    alt_creds = { baz: 'qux' }
    c1 = Class.new.new.tap { _1.extend(Loadout) }
    c2 = Class.new.new.tap { _1.extend(Loadout::Helpers) }

    c1.loadout(creds: alt_creds, env: alt_env)
    assert_equal 'bar', c1.loadout.env(:foo)
    assert_equal 'qux', c1.loadout.cred(:baz)
    assert_equal ['bar'], c1.loadout.list.env(:foo)
    assert_equal 'qux', c1.loadout.list.env.cred(:baz)

    c2.loadout(creds: alt_creds, env: alt_env)
    assert_equal 'bar', c2.env(:foo)
    assert_equal 'qux', c2.cred(:baz)
    assert_equal ['bar'], c2.list.env(:foo)
    assert_equal 'qux', c2.list.list.env.cred(:baz)
  end

  def test_loadout_can_be_aliased
    @config1.instance_eval { alias l loadout }
    set_env 'foo'
    assert_equal 'foo', @config1.l.env(ENV_SYM)
  end

  ##############################################################################
  # CRED, ENV, PREFIX ISOLATION TESTS                                          #
  ##############################################################################
  def test_cred_looks_up_cred_over_default
    @config1.credentials = { foo: 'cred', bar: { baz: 'cred2' } }
    @config2.credentials = { foo: 'cred', bar: { baz: 'cred2' } }

    assert_equal 'cred', @config1.loadout.cred(:foo) { 'default' }
    assert_equal 'cred', @config2.loadout.cred(:foo) { 'default' }
    assert_equal 'cred', @config2.cred(:foo) { 'default' }

    assert_equal 'cred2', @config1.loadout.cred(:bar, :baz) { 'default' }
    assert_equal 'cred2', @config2.loadout.cred(:bar, :baz) { 'default' }
    assert_equal 'cred2', @config2.cred(:bar, :baz) { 'default' }
  end

  def test_cred_looks_up_default_when_cred_is_missing
    assert_equal 'default', @config1.loadout.cred(:foo) { 'default' }
    assert_equal 'default', @config1.loadout.cred(:bar, :baz) { 'default' }
    assert_equal 'default', @config2.cred(:foo) { 'default' }
    assert_equal 'default', @config2.cred(:bar, :baz) { 'default' }
  end

  def test_cred_raises_when_cred_and_default_are_missing
    ex = assert_raises(Loadout::MissingConfigError) {
      @config1.loadout.cred(:a, :b)
    }
    assert_equal 'required credential (a.b) is not set', ex.message

    ex = assert_raises(Loadout::MissingConfigError) { @config2.cred(:a, :b) }
    assert_equal 'required credential (a.b) is not set', ex.message
  end

  def test_env_looks_up_env_over_default
    set_env 'env'
    assert_equal 'env', @config1.loadout.env(:loadout_test_env) { 'default' }
    assert_equal 'env', @config2.loadout.env(:loadout_test_env) { 'default' }
    assert_equal 'env', @config2.env(:loadout_test_env) { 'default' }
  end

  def test_env_looks_up_default_when_env_is_missing
    assert_equal 'default', @config1.loadout.env(:foo) { 'default' }
    assert_equal 'default', @config2.env(:foo) { 'default'}
  end

  def test_env_raises_when_env_and_default_are_missing
    ex = assert_raises(Loadout::MissingConfigError) {
      @config1.loadout.env(*ENV_SYMS)
    }
    assert_equal "required environment variable (#{ENV_KEY}) is not set",
      ex.message

    ex = assert_raises(Loadout::MissingConfigError) {
      @config2.env(*ENV_SYMS)
    }
    assert_equal "required environment variable (#{ENV_KEY}) is not set",
      ex.message
  end

  def test_prefix_looks_up_nested_cred
    @config1.credentials = { foo: { bar: { baz: 'cred' } } }
    @config2.credentials = { foo: { bar: { baz: 'cred' } } }

    value1 = @config1.instance_eval {
      loadout.prefix(:foo) { loadout.prefix(:bar) { loadout.cred(:baz) } }
    }

    value2 = @config2.instance_eval {
      prefix(:foo) { prefix(:bar) { cred(:baz) } }
    }

    assert_equal 'cred', value1
    assert_equal 'cred', value2
  end

  def test_prefix_applies_default_to_nested_cred
    value1 = @config1.instance_eval {
      loadout.prefix(:foo, default: -> { 'default' }) {
        loadout.prefix(:bar) {
          loadout.cred(:baz)
        }
      }
    }

    value2 = @config2.instance_eval {
      prefix(:foo) {
        prefix(:bar, default: -> { 'default' }) {
          cred(:baz)
        }
      }
    }

    assert_equal 'default', value1
    assert_equal 'default', value2
  end

  def test_prefix_shows_key_in_cred_error
    ex = assert_raises(Loadout::MissingConfigError) {
      @config1.instance_eval { loadout.prefix(:foo) { loadout.cred(:bar) } }
    }
    assert_equal 'required credential (foo.bar) is not set', ex.message

    ex = assert_raises(Loadout::MissingConfigError) {
      @config2.instance_eval { prefix(:foo) { cred(:bar) } }
    }
    assert_equal 'required credential (foo.bar) is not set', ex.message
  end

  def test_prefix_looks_up_nested_env
    set_env 'env'

    value1 = @config1.instance_eval {
      loadout.prefix(:loadout) { loadout.prefix(:test) { loadout.env(:env) } }
    }

    value2 = @config2.instance_eval {
      prefix(:loadout) { prefix(:test) { env(:env) } }
    }

    assert_equal 'env', value1
    assert_equal 'env', value2
  end

  def test_prefix_applies_default_to_nested_env
    value1 = @config1.instance_eval {
      loadout.prefix(:foo, default: -> { 'default' }) {
        loadout.prefix(:bar) {
          loadout.env(:baz)
        }
      }
    }

    value2 = @config2.instance_eval {
      prefix(:foo) {
        prefix(:bar, default: -> { 'default' }) {
          env(:baz)
        }
      }
    }

    assert_equal 'default', value1
    assert_equal 'default', value2
  end

  def test_prefix_shows_key_in_env_error
    ex = assert_raises(Loadout::MissingConfigError) {
      @config1.instance_eval { loadout.prefix(:loadout) { loadout.env(:test) } }
    }
    assert_equal 'required environment variable (LOADOUT_TEST) is not set',
      ex.message

    ex = assert_raises(Loadout::MissingConfigError) {
      @config2.instance_eval { prefix(:loadout) { env(:test) } }
    }
    assert_equal 'required environment variable (LOADOUT_TEST) is not set',
      ex.message
  end

  ##############################################################################
  # BOOL TESTS                                                                 #
  ##############################################################################
  def test_bool_accepts_falsy_strings
    ['', 'false', 'F', 'nO', 'n', '0'].each do |value|
      set_env value
      assert_equal false, @config1.loadout.bool.env(ENV_SYM)
      assert_equal false, @config2.loadout.bool.env(ENV_SYM)
      assert_equal false, @config2.bool.env(ENV_SYM)
    end
  end

  def test_bool_accepts_truthy_strings
    ['1', 'true', 't', 'yes', 'Y'].each do |value|
      set_env value
      assert_equal true, @config1.loadout.bool.env(ENV_SYM)
      assert_equal true, @config2.loadout.bool.env(ENV_SYM)
      assert_equal true, @config2.bool.env(ENV_SYM)
    end
  end

  def test_bool_raises_on_missing_key
    ex = assert_raises(Loadout::MissingConfigError) {
      @config1.loadout.bool.env(ENV_SYM)
    }
    assert_equal "required environment variable (#{ENV_KEY}) is not set",
      ex.message

    ex = assert_raises(Loadout::MissingConfigError) { @config2.bool.env(ENV_SYM) }
    assert_equal "required environment variable (#{ENV_KEY}) is not set",
      ex.message
  end

  def test_bool_raises_on_invalid_string
    ['bad', 'tr', '#'].each do |value|
      set_env value

      ex = assert_raises(Loadout::InvalidConfigError) {
        @config1.loadout.bool.env(ENV_SYM)
      }
      assert_equal "invalid value for bool (`#{value}`) in #{ENV_KEY}",
        ex.message

      ex = assert_raises(Loadout::InvalidConfigError) {
        @config2.bool.env(ENV_SYM)
      }
      assert_equal "invalid value for bool (`#{value}`) in #{ENV_KEY}",
        ex.message
    end
  end

  def test_bool_does_not_raise_with_default
    assert_equal true, @config1.loadout.bool.env(ENV_SYM) { true }
    assert_equal true, @config2.bool.env(ENV_SYM) { true }
  end

  def test_bool_raises_with_invalid_string_and_default
    set_env 'bad'

    ex = assert_raises(Loadout::InvalidConfigError) {
      @config1.loadout.bool.env(ENV_SYM) { true }
    }
    assert_equal "invalid value for bool (`bad`) in #{ENV_KEY}", ex.message

    ex = assert_raises(Loadout::InvalidConfigError) {
      @config2.bool.env(ENV_SYM) { true }
    }
    assert_equal "invalid value for bool (`bad`) in #{ENV_KEY}", ex.message
  end

  ##############################################################################
  # INT TESTS                                                                  #
  ##############################################################################
  def test_int_coerces_string_to_integer
    set_env '42'
    assert_equal 42, @config1.loadout.int.env(ENV_SYM)
    assert_equal 42, @config2.loadout.int.env(ENV_SYM)
    assert_equal 42, @config2.int.env(ENV_SYM)
  end

  def test_int_raises_on_missing_key
    ex = assert_raises(Loadout::MissingConfigError) {
      @config1.loadout.int.env(ENV_SYM)
    }
    assert_equal "required environment variable (#{ENV_KEY}) is not set",
      ex.message

    ex = assert_raises(Loadout::MissingConfigError) {
      @config2.int.env(ENV_SYM)
    }
    assert_equal "required environment variable (#{ENV_KEY}) is not set",
      ex.message
  end

  def test_int_raises_on_invalid_string
    set_env 'bad'

    ex = assert_raises(Loadout::InvalidConfigError) {
      @config1.loadout.int.env(ENV_SYM)
    }
    assert_equal "invalid value for int (`bad`) in #{ENV_KEY}", ex.message

    ex = assert_raises(Loadout::InvalidConfigError) {
      @config2.int.env(ENV_SYM)
    }
    assert_equal "invalid value for int (`bad`) in #{ENV_KEY}", ex.message
  end

  def test_int_does_not_raise_with_default
    assert_equal 42, @config1.loadout.int.env(ENV_SYM) { 42 }
    assert_equal 42, @config2.int.env(ENV_SYM) { 42 }
  end

  def test_int_raises_with_invalid_string_and_default
    set_env 'bad'

    ex = assert_raises(Loadout::InvalidConfigError) {
      @config1.loadout.int.env(ENV_SYM) { 42 }
    }
    assert_equal "invalid value for int (`bad`) in #{ENV_KEY}", ex.message

    ex = assert_raises(Loadout::InvalidConfigError) {
      @config2.int.env(ENV_SYM) { 42 }
    }
    assert_equal "invalid value for int (`bad`) in #{ENV_KEY}", ex.message
  end

  ##############################################################################
  # FLOAT TESTS                                                                #
  ##############################################################################
  def test_float_coerces_string_to_float
    set_env '3.14'
    assert_equal 3.14, @config1.loadout.float.env(ENV_SYM)
    assert_equal 3.14, @config2.loadout.float.env(ENV_SYM)
    assert_equal 3.14, @config2.float.env(ENV_SYM)
  end

  def test_float_raises_on_missing_key
    ex = assert_raises(Loadout::MissingConfigError) {
      @config1.loadout.float.env(ENV_SYM)
    }
    assert_equal "required environment variable (#{ENV_KEY}) is not set",
      ex.message

    ex = assert_raises(Loadout::MissingConfigError) {
      @config2.float.env(ENV_SYM)
    }
    assert_equal "required environment variable (#{ENV_KEY}) is not set",
      ex.message
  end

  def test_float_raises_on_invalid_string
    set_env 'bad'

    ex = assert_raises(Loadout::InvalidConfigError) {
      @config1.loadout.float.env(ENV_SYM)
    }
    assert_equal "invalid value for float (`bad`) in #{ENV_KEY}", ex.message

    ex = assert_raises(Loadout::InvalidConfigError) {
      @config2.float.env(ENV_SYM)
    }
    assert_equal "invalid value for float (`bad`) in #{ENV_KEY}", ex.message
  end

  def test_float_does_not_raise_with_default
    assert_equal 3.14, @config1.loadout.float.env(ENV_SYM) { 3.14 }
    assert_equal 3.14, @config2.float.env(ENV_SYM) { 3.14 }
  end

  def test_float_raises_with_invalid_string_and_default
    set_env 'bad'

    ex = assert_raises(Loadout::InvalidConfigError) {
      @config1.loadout.float.env(ENV_SYM) { 3.14 }
    }
    assert_equal "invalid value for float (`bad`) in #{ENV_KEY}", ex.message

    ex = assert_raises(Loadout::InvalidConfigError) {
      @config2.float.env(ENV_SYM) { 3.14 }
    }
    assert_equal "invalid value for float (`bad`) in #{ENV_KEY}", ex.message
  end

  ##############################################################################
  # LIST TESTS                                                                 #
  ##############################################################################
  def test_list_splits_string_by_various_separators
    set_env 'a,b, c'
    assert_equal %w[a b c], @config1.loadout.list.env(ENV_SYM)
    assert_equal %w[a b c], @config2.loadout.list.env(ENV_SYM)
    assert_equal %w[a b c], @config2.list.env(ENV_SYM)

    set_env 'a b   c'
    assert_equal %w[a b c], @config1.loadout.list.env(ENV_SYM)
    assert_equal %w[a b c], @config2.loadout.list.env(ENV_SYM)
    assert_equal %w[a b c], @config2.list.env(ENV_SYM)

    set_env 'a |  b:c'
    assert_equal %w[a b c], @config1.loadout.list.env(ENV_SYM)
    assert_equal %w[a b c], @config2.loadout.list.env(ENV_SYM)
    assert_equal %w[a b c], @config2.list.env(ENV_SYM)

    set_env '1 - 2; 3'
    assert_equal %w[1 2 3], @config1.loadout.list.env(ENV_SYM)
    assert_equal %w[1 2 3], @config2.loadout.list.env(ENV_SYM)
    assert_equal %w[1 2 3], @config2.list.env(ENV_SYM)
  end

  def test_list_separator_is_configurable
    set_env 'a |b| c'
    assert_equal ['a ', 'b', ' c'], @config1.loadout.list('|').env(ENV_SYM)
    assert_equal ['a ', 'b', ' c'], @config2.loadout.list('|').env(ENV_SYM)
    assert_equal ['a ', 'b', ' c'], @config2.list('|').env(ENV_SYM)
  end

  def test_list_raises_on_missing_key
    ex = assert_raises(Loadout::MissingConfigError) {
      @config1.loadout.list.env(ENV_SYM)
    }
    assert_equal "required environment variable (#{ENV_KEY}) is not set",
      ex.message

    ex = assert_raises(Loadout::MissingConfigError) {
      @config2.list.env(ENV_SYM)
    }
    assert_equal "required environment variable (#{ENV_KEY}) is not set",
      ex.message
  end

  def test_list_does_not_raise_with_default
    assert_equal %w[a b c], @config1.loadout.list.env(ENV_SYM) { %w[a b c] }
    assert_equal %w[a b c], @config2.list.env(ENV_SYM) { %w[a b c] }
  end

  ##############################################################################
  # COMBO TESTS                                                                #
  ##############################################################################
  def test_cred_env_looks_up_cred
    @config1.credentials = { ENV_SYM => 'cred' }
    @config2.credentials = { ENV_SYM => 'cred' }
    set_env 'env'

    assert_equal 'cred', @config1.loadout.cred.env(ENV_SYM)
    assert_equal 'cred', @config2.loadout.cred.env(ENV_SYM)
    assert_equal 'cred', @config2.cred.env(ENV_SYM)
  end

  def test_cred_env_looks_up_nested_cred
    @config1.credentials = { loadout: { test: { env: 'cred' } } }
    @config2.credentials = { loadout: { test: { env: 'cred' } } }

    assert_equal 'cred', @config1.loadout.cred.env(*ENV_SYMS)
    assert_equal 'cred', @config2.loadout.cred.env(*ENV_SYMS)
    assert_equal 'cred', @config2.cred.env(*ENV_SYMS)
  end

  def test_cred_env_looks_up_env_after_cred
    set_env 'env'

    assert_equal 'env', @config1.loadout.cred.env(ENV_SYM) { 'default' }
    assert_equal 'env', @config2.loadout.cred.env(ENV_SYM) { 'default' }
    assert_equal 'env', @config2.cred.env(ENV_SYM) { 'default' }
  end

  def test_cred_env_looks_up_default_after_cred_and_env
    assert_equal 'default', @config1.loadout.cred.env(ENV_SYM) { 'default' }
    assert_equal 'default', @config2.loadout.cred.env(ENV_SYM) { 'default' }
    assert_equal 'default', @config2.cred.env(ENV_SYM) { 'default' }
  end

  def test_bool_cred_env_looks_up_bool_cred
    @config1.credentials = { ENV_SYM => true }
    @config2.credentials = { ENV_SYM => true }
    set_env 'false'

    assert_equal true, @config1.loadout.bool.cred.env(ENV_SYM)
    assert_equal true, @config2.loadout.bool.cred.env(ENV_SYM)
    assert_equal true, @config2.bool.cred.env(ENV_SYM)
  end

  def test_bool_cred_env_looks_up_bool_env
    set_env 'true'

    assert_equal true, @config1.loadout.bool.cred.env(ENV_SYM) { 'default' }
    assert_equal true, @config2.loadout.bool.cred.env(ENV_SYM) { 'default' }
    assert_equal true, @config2.bool.cred.env(ENV_SYM) { 'default' }
  end

  def test_bool_cred_env_looks_up_bool_default
    assert_equal false, @config1.loadout.bool.cred.env(ENV_SYM) { false }
    assert_equal false, @config2.loadout.bool.cred.env(ENV_SYM) { false }
    assert_equal false, @config2.bool.cred.env(ENV_SYM) { false }
  end

  def test_env_cred_looks_up_env
    @config1.credentials = { ENV_SYM => 'cred' }
    @config2.credentials = { ENV_SYM => 'cred' }
    set_env 'env'

    assert_equal 'env', @config1.loadout.env.cred(ENV_SYM)
    assert_equal 'env', @config2.loadout.env.cred(ENV_SYM)
    assert_equal 'env', @config2.env.cred(ENV_SYM)
  end

  def test_env_cred_looks_up_cred_after_env
    set_env 'env'

    assert_equal 'env', @config1.loadout.env.cred(ENV_SYM) { 'default' }
    assert_equal 'env', @config2.loadout.env.cred(ENV_SYM) { 'default' }
    assert_equal 'env', @config2.env.cred(ENV_SYM) { 'default' }
  end

  def test_env_cred_looks_up_default_after_env_and_cred
    assert_equal 'default', @config1.loadout.env.cred(ENV_SYM) { 'default' }
    assert_equal 'default', @config2.loadout.env.cred(ENV_SYM) { 'default' }
    assert_equal 'default', @config2.env.cred(ENV_SYM) { 'default' }
  end

  def test_bool_env_cred_looks_up_bool_env
    set_env 'true'

    assert_equal true, @config1.loadout.bool.env.cred(ENV_SYM)
    assert_equal true, @config2.loadout.bool.env.cred(ENV_SYM)
    assert_equal true, @config2.bool.env.cred(ENV_SYM)
  end

  def test_bool_env_cred_looks_up_bool_cred
    @config1.credentials = { ENV_SYM => true }
    @config2.credentials = { ENV_SYM => true }

    assert_equal true, @config1.loadout.bool.env.cred(ENV_SYM) { 'default' }
    assert_equal true, @config2.loadout.bool.env.cred(ENV_SYM) { 'default' }
    assert_equal true, @config2.bool.env.cred(ENV_SYM) { 'default' }
  end

  def test_bool_env_cred_looks_up_bool_default
    assert_equal true, @config1.loadout.bool.env.cred(ENV_SYM) { true }
    assert_equal true, @config2.loadout.bool.env.cred(ENV_SYM) { true }
    assert_equal true, @config2.bool.env.cred(ENV_SYM) { true }
  end

  def test_prefix_cred_env_looks_up_nested_cred
    @config1.credentials = { loadout: { test: { env: 'cred' } } }
    @config2.credentials = { loadout: { test: { env: 'cred' } } }
    set_env 'env'

    value1 = @config1.instance_eval {
      loadout.prefix(:loadout) {
        loadout.prefix(:test) {
          loadout.cred.env(:env)
        }
      }
    }

    value2 = @config2.instance_eval {
      prefix(:loadout) { prefix(:test) { cred.env(:env) } }
    }

    assert_equal 'cred', value1
    assert_equal 'cred', value2
  end

  def test_prefix_cred_env_looks_up_nested_env
    set_env 'env'

    value1 = @config1.instance_eval {
      loadout.prefix(:loadout) {
        loadout.prefix(:test) {
          loadout.cred.env(:env)
        }
      }
    }

    value2 = @config2.instance_eval {
      prefix(:loadout) { prefix(:test) { cred.env(:env) } }
    }

    assert_equal 'env', value1
    assert_equal 'env', value2
  end

  private

  def set_env(value) = ENV[ENV_KEY] = value
end
