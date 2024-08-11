# frozen_string_literal: true

require_relative 'loadout/version'
require 'set'

module Loadout
  NONE = BasicObject.new
  DEFAULT_LIST_SEP = /\s*[\s[[:punct:]]]+\s*/

  ConfigError = Class.new(ArgumentError)
  MissingConfigError = Class.new(ConfigError)
  InvalidConfigError = Class.new(ConfigError)

  def loadout(env: nil, creds: nil)
    @loadout ||= Loadout::Config.new(env || ENV, creds || credentials)
  end

  module Helpers
    def loadout(env: nil, creds: nil)
      @loadout ||= Loadout::Config.new(env || ENV, creds || credentials)
    end

    def cred(*a, **k, &b)   = loadout.cred(*a, **k, &b)
    def env(*a, **k, &b)    = loadout.env(*a, **k, &b)
    def prefix(*a, **k, &b) = loadout.prefix(*a, **k, &b)

    def bool(*a, **k, &b)  = loadout.bool(*a, **k, &b)
    def int(*a, **k, &b)   = loadout.int(*a, **k, &b)
    def float(*a, **k, &b) = loadout.float(*a, **k, &b)
    def list(*a, **k, &b)  = loadout.list(*a, **k, &b)
  end

  class Config
    protected attr_writer :type
    protected attr_reader :lookup_list

    def initialize(env, creds)
      @env = env
      @creds = creds
      @type = nil
      @prefix_stack = []
      @lookup_list = Set[]
      @prefix_default = NONE
    end

    def env(*keys, &default)
      return dup.tap { _1.lookup_list << :env } if keys.empty?
      @lookup_list << :env
      lookup(keys, &default)
    end

    def cred(*keys, &default)
      return dup.tap { _1.lookup_list << :cred } if keys.empty?
      @lookup_list << :cred
      lookup(keys, &default)
    end

    def prefix(*keys, default: NONE)
      @prefix_default = default unless default.equal?(NONE)
      @prefix_stack.push(keys)
      yield.tap { @prefix_stack.pop }
    end

    def bool                         = dup.tap { _1.type = :bool }
    def int                          = dup.tap { _1.type = :int }
    def float                        = dup.tap { _1.type = :float }
    def list(sep = DEFAULT_LIST_SEP) = dup.tap { _1.type = [:list, sep] }

    def initialize_dup(other)
      @type         = other.instance_variable_get(:@type).dup
      @prefix_stack = other.instance_variable_get(:@prefix_stack).dup
      @lookup_list  = other.instance_variable_get(:@lookup_list).dup

      unless other.instance_variable_get(:@prefix_default).equal?(NONE)
        @prefix_default = other.instance_variable_get(:@prefix_default).dup
      end

      super
    end

    private

    def lookup(keys)
      value = NONE
      keys = @prefix_stack.flatten + keys

      @lookup_list.each do |source|
        value =
          case source
          when :cred; lookup_cred(keys)
          when :env;  lookup_env(keys)
          end

        return value unless value.equal?(NONE)
      end

      return yield if block_given?
      return @prefix_default.call unless @prefix_default.equal?(NONE)
      raise_missing(keys)
    ensure
      @lookup_list.clear
    end

    def lookup_cred(keys)
      return @creds[keys[0]] if keys.one? && @creds.has_key?(keys[0])
      return NONE if keys.one?
      hash = @creds.dig(*keys[..-2])
      hash&.has_key?(keys.last) ? hash[keys.last] : NONE
    end

    def lookup_env(keys)
      env_key = keys.join('_').upcase
      @env.has_key?(env_key) ? coerce(env_key, @env[env_key]) : NONE
    end

    def coerce(key, value)
      case @type
      in :bool;      parse_bool(key, value)
      in :int;       parse_int(key, value)
      in :float;     parse_float(key, value)
      in :list, sep; parse_list(key, value, sep)
      else; value
      end
    end

    def parse_bool(key, value)
      value = value.to_s
      return false if value == ''
      return false if %w[0 n no f false].include?(value.downcase)
      return true  if %w[1 y yes t true].include?(value.downcase)
      raise_invalid :bool, key, value
    end

    def parse_int(key, val)
      Integer(val.to_s)
    rescue ArgumentError
      raise_invalid :int, key, val
    end

    def parse_float(key, val)
      Float(val.to_s)
    rescue ArgumentError
      raise_invalid :float, key, val
    end

    def parse_list(key, val, sep)
      val = val.to_s
      raise_invalid(:list, key, val) if val == ''
      val.split(sep)
    end

    def raise_missing(keys)
      pairs = []

      @lookup_list.each do |source|
        case source
        when :cred; pairs << ["credential", keys.join('.')]
        when :env;  pairs << ["environment variable", keys.join('_').upcase]
        end
      end

      msg = pairs.map { |s, v| "#{s} (#{v})" }.join(' or ')
      raise MissingConfigError, "required #{msg} is not set"
    end

    def raise_invalid(type, key, val)
      raise InvalidConfigError, "invalid value for #{type} (`#{val}`) in #{key}"
    end
  end
end
